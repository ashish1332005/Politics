import 'dart:convert';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class DownloadedFile {
  const DownloadedFile({
    required this.bytes,
    required this.filename,
    required this.contentType,
  });

  final Uint8List bytes;
  final String filename;
  final String contentType;
}

class Api {
  Api({required this.baseUrl});

  final String baseUrl;
  String? token;
  Map<String, dynamic>? user;
  final ValueNotifier<int> dataVersion = ValueNotifier<int>(0);

  static const _tokenKey = 'auth_token_v1';
  static const _userKey = 'auth_user_v1';

  void notifyDataChanged() {
    dataVersion.value++;
  }

  Future<void> restoreSession() async {
    final prefs = await SharedPreferences.getInstance();
    final savedToken = prefs.getString(_tokenKey);
    final savedUser = prefs.getString(_userKey);
    if (savedToken == null || savedToken.isEmpty) return;
    token = savedToken;
    if (savedUser != null && savedUser.isNotEmpty) {
      try {
        user = Map<String, dynamic>.from(json.decode(savedUser));
      } catch (_) {
        user = null;
      }
    }
  }

  Future<void> _persistSession() async {
    final prefs = await SharedPreferences.getInstance();
    if (token == null || token!.isEmpty) {
      await prefs.remove(_tokenKey);
      await prefs.remove(_userKey);
      return;
    }
    await prefs.setString(_tokenKey, token!);
    if (user != null) await prefs.setString(_userKey, json.encode(user));
  }

  Future<void> _clearSession() async {
    token = null;
    user = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_userKey);
  }

  Map<String, String> get headers => {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      };

  Future<dynamic> _send(Future<http.Response> future) async {
    final res = await future;
    dynamic body;
    final contentType = res.headers['content-type'] ?? '';
    if (res.body.isEmpty) {
      body = null;
    } else if (contentType.contains('application/json') ||
        res.body.trimLeft().startsWith('{') ||
        res.body.trimLeft().startsWith('[')) {
      body = json.decode(res.body);
    } else {
      throw Exception(
          'API returned non-JSON response. Check backend is running at $baseUrl. Preview: ${res.body.substring(0, res.body.length > 80 ? 80 : res.body.length)}');
    }
    if (res.statusCode >= 400) {
      throw Exception(body is Map
          ? (body['message'] ?? body['msg'] ?? body.toString())
          : 'Request failed');
    }
    return body;
  }

  Future<Map<String, dynamic>> login(String email, String password) async {
    final data = await _send(http.post(Uri.parse('$baseUrl/api/auth/login'),
        headers: headers,
        body: json.encode({'email': email, 'password': password})));
    token = data['token'];
    user = Map<String, dynamic>.from(data['user']);
    await _persistSession();
    return user!;
  }

  Future<bool> validateSession() async {
    if (token == null) await restoreSession();
    if (token == null) return false;
    try {
      user = await get('/api/auth/me');
      await _persistSession();
      return true;
    } catch (_) {
      await _clearSession();
      return false;
    }
  }

  void logout() {
    _clearSession();
  }

  Future<List<dynamic>> list(String path,
      [Map<String, String?> query = const {}]) async {
    final clean = <String, String>{};
    for (final entry in query.entries) {
      final value = entry.value;
      if (value != null && value.isNotEmpty) clean[entry.key] = value;
    }
    return await _send(http.get(
        Uri.parse('$baseUrl$path').replace(queryParameters: clean),
        headers: headers));
  }

  Future<Map<String, dynamic>> get(String path) async =>
      Map<String, dynamic>.from(
          await _send(http.get(Uri.parse('$baseUrl$path'), headers: headers)));
  Future<Map<String, dynamic>> getQuery(String path,
      [Map<String, String?> query = const {}]) async {
    final clean = <String, String>{};
    for (final entry in query.entries) {
      final value = entry.value;
      if (value != null && value.isNotEmpty) clean[entry.key] = value;
    }
    return Map<String, dynamic>.from(await _send(http.get(
        Uri.parse('$baseUrl$path').replace(queryParameters: clean),
        headers: headers)));
  }

  Future<Map<String, dynamic>> post(String path, Map data) async =>
      Map<String, dynamic>.from(await _send(http.post(
          Uri.parse('$baseUrl$path'),
          headers: headers,
          body: json.encode(data))));
  Future<Map<String, dynamic>> put(String path, Map data) async =>
      Map<String, dynamic>.from(await _send(http.put(Uri.parse('$baseUrl$path'),
          headers: headers, body: json.encode(data))));
  Future<void> delete(String path) async =>
      await _send(http.delete(Uri.parse('$baseUrl$path'), headers: headers));
  Future<Map<String, dynamic>> deleteWithBody(String path, Map data) async =>
      Map<String, dynamic>.from(
        await _send(http.delete(Uri.parse('$baseUrl$path'),
            headers: headers, body: json.encode(data))),
      );

  Future<DownloadedFile> download(String path,
      {Map<String, String?> query = const {},
      String fallbackName = 'download'}) async {
    final clean = <String, String>{};
    for (final entry in query.entries) {
      final value = entry.value;
      if (value != null && value.isNotEmpty) clean[entry.key] = value;
    }
    final uri = Uri.parse('$baseUrl$path').replace(queryParameters: clean);
    final res = await http.get(uri, headers: headers);
    if (res.statusCode >= 400) {
      final contentType = res.headers['content-type'] ?? '';
      if (contentType.contains('application/json') ||
          res.body.trimLeft().startsWith('{')) {
        final body = json.decode(res.body);
        throw Exception(body is Map
            ? (body['message'] ?? body['msg'] ?? body.toString())
            : 'Download failed');
      }
      throw Exception('Download failed with status ${res.statusCode}');
    }
    return DownloadedFile(
      bytes: res.bodyBytes,
      filename: _filenameFromDisposition(res.headers['content-disposition']) ??
          fallbackName,
      contentType: res.headers['content-type'] ?? 'application/octet-stream',
    );
  }

  Future<Map<String, dynamic>> uploadBytes(String path, Uint8List bytes,
      String filename, Map<String, String> fields) async {
    final request = http.MultipartRequest('POST', Uri.parse('$baseUrl$path'));
    if (token != null) request.headers['Authorization'] = 'Bearer $token';
    request.fields.addAll(fields);
    request.files
        .add(http.MultipartFile.fromBytes('file', bytes, filename: filename));
    final streamed = await request.send();
    final response = await http.Response.fromStream(streamed);
    return Map<String, dynamic>.from(await _send(Future.value(response)));
  }

  Future<Map<String, dynamic>> uploadFile(
    String path, {
    String method = 'POST',
    required String filename,
    String fileField = 'file',
    String? filePath,
    Uint8List? bytes,
    Map<String, String> fields = const {},
    void Function(int sent, int total)? onProgress,
  }) async {
    final uploadId = fields['uploadId'];
    final uri = uploadId == null || uploadId.isEmpty
        ? Uri.parse('$baseUrl$path')
        : Uri.parse('$baseUrl$path')
            .replace(queryParameters: {'uploadId': uploadId});
    final request = http.MultipartRequest(method, uri);
    if (token != null) request.headers['Authorization'] = 'Bearer $token';
    request.fields.addAll(fields);
    if (filePath != null && filePath.isNotEmpty) {
      final file = await http.MultipartFile.fromPath(fileField, filePath,
          filename: filename);
      request.files.add(_trackMultipartProgress(file, onProgress));
    } else if (bytes != null) {
      final file =
          http.MultipartFile.fromBytes(fileField, bytes, filename: filename);
      request.files.add(_trackMultipartProgress(file, onProgress));
    } else {
      throw Exception('Selected file could not be read.');
    }
    try {
      final streamed = await request.send();
      final response = await http.Response.fromStream(streamed);
      return Map<String, dynamic>.from(await _send(Future.value(response)));
    } catch (error) {
      final message = error.toString();
      if (message.contains('XMLHttpRequest error') ||
          message.contains('Failed to fetch') ||
          message.contains('ClientException')) {
        throw Exception(
          'Backend से संपर्क नहीं हो सका। API $baseUrl पर चल रही है या नहीं, '
          'CORS और HTTPS सेटिंग जांचें।',
        );
      }
      rethrow;
    }
  }

  http.MultipartFile _trackMultipartProgress(
    http.MultipartFile file,
    void Function(int sent, int total)? onProgress,
  ) {
    if (onProgress == null) return file;
    var sent = 0;
    final stream = file.finalize().transform(
      StreamTransformer<List<int>, List<int>>.fromHandlers(
        handleData: (data, sink) {
          sent += data.length;
          onProgress(sent, file.length);
          sink.add(data);
        },
      ),
    );
    return http.MultipartFile(file.field, stream, file.length,
        filename: file.filename, contentType: file.contentType);
  }

  String? _filenameFromDisposition(String? header) {
    if (header == null || header.isEmpty) return null;
    final utf = RegExp("filename\\*=UTF-8''([^;]+)").firstMatch(header);
    if (utf != null) return Uri.decodeComponent(utf.group(1)!);
    final plain = RegExp('filename="?([^";]+)"?').firstMatch(header);
    return plain?.group(1);
  }
}
