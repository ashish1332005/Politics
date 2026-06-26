import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'api_client.dart';

class VoterPageResult {
  const VoterPageResult({
    required this.items,
    required this.total,
    required this.page,
    required this.limit,
    required this.pages,
    this.offline = false,
  });

  final List<dynamic> items;
  final int total;
  final int page;
  final int limit;
  final int pages;
  final bool offline;
}

class OfflineVoterCache {
  static const _key = 'offline_voters_v1';
  static const _updatedKey = 'offline_voters_updated_at';

  static Future<List<dynamic>> load({
    Map<String, String?> query = const {},
  }) async {
    try {
      final online = await api.list('/api/members', query);
      await save(online);
      return online;
    } catch (_) {
      final cached = await read();
      return _filter(cached, query);
    }
  }

  static Future<VoterPageResult> loadPage({
    Map<String, String?> query = const {},
    int page = 1,
    int limit = 100,
  }) async {
    final pagedQuery = {
      ...query,
      'paged': 'true',
      'page': '$page',
      'limit': '$limit',
    };
    try {
      final online = await api.getQuery('/api/members', pagedQuery);
      final items = List<dynamic>.from(online['items'] as List? ?? []);
      if (page == 1) await save(items);
      return VoterPageResult(
        items: items,
        total: ((online['total'] ?? items.length) as num).toInt(),
        page: ((online['page'] ?? page) as num).toInt(),
        limit: ((online['limit'] ?? limit) as num).toInt(),
        pages: ((online['pages'] ?? 1) as num).toInt(),
      );
    } catch (_) {
      final filtered = _filter(await read(), query);
      final start = (page - 1) * limit;
      final end = start + limit;
      final items = start >= filtered.length
          ? <dynamic>[]
          : filtered.sublist(
              start, end > filtered.length ? filtered.length : end);
      return VoterPageResult(
        items: items,
        total: filtered.length,
        page: page,
        limit: limit,
        pages: filtered.isEmpty ? 1 : ((filtered.length - 1) ~/ limit) + 1,
        offline: true,
      );
    }
  }

  static Future<void> save(List<dynamic> voters) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(voters));
    await prefs.setString(_updatedKey, DateTime.now().toIso8601String());
  }

  static Future<List<dynamic>> read() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return [];
    return List<dynamic>.from(jsonDecode(raw));
  }

  static Future<String?> lastUpdated() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_updatedKey);
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
    await prefs.remove(_updatedKey);
  }

  static List<dynamic> _filter(
      List<dynamic> items, Map<String, String?> query) {
    final q = (query['q'] ?? '').toLowerCase();
    return items.where((raw) {
      final item = Map<String, dynamic>.from(raw);
      if (q.isNotEmpty) {
        final text = [
          item['name'],
          item['surname'],
          item['mobile'],
          item['voterId'],
          item['village'],
          item['location'],
          item['organizationPost'],
        ].join(' ').toLowerCase();
        if (!text.contains(q)) return false;
      }
      for (final key in [
        'supportLevel',
        'gender',
        'verificationStatus',
        'assemblyNumber',
        'partNumber',
        'sectionNumber',
        'sectionName',
        'location',
        'village',
        'gramPanchayat',
        'tehsil',
        'municipality',
        'caste',
        'organizationPost',
        'area'
      ]) {
        final expected = query[key];
        if (expected != null && expected.isNotEmpty) {
          final actual = '${item[key] ?? ''}'.toLowerCase();
          if (!actual.contains(expected.toLowerCase())) return false;
        }
      }
      return true;
    }).toList();
  }
}
