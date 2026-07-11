import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../core/offline_voter_cache.dart';
import '../../core/picked_file_source.dart';
import '../../core/theme.dart';
import '../../layout/app_layout.dart';
import '../../widgets/mobile_components.dart';

class UploadPage extends StatefulWidget {
  const UploadPage({super.key});

  @override
  State<UploadPage> createState() => _UploadPageState();
}

class _UploadPageState extends State<UploadPage> {
  String status = '';
  bool uploading = false;
  String? currentFile;
  int currentBytes = 0;
  int uploadedBytes = 0;
  int uploadTotalBytes = 0;
  bool serverProcessing = false;
  int processedRecords = 0;
  int totalRecords = 0;
  int importedRecords = 0;
  int skippedRecords = 0;
  int ocrPagesProcessed = 0;
  int ocrPagesTotal = 0;
  int ocrCardsProcessed = 0;
  int ocrCardsTotal = 0;
  String processingStage = '';

  Future<Map<String, dynamic>> waitForImportCompletion(String uploadId) async {
    final deadline = DateTime.now().add(const Duration(minutes: 90));
    while (DateTime.now().isBefore(deadline)) {
      final progress = await api.get('/api/import/status/$uploadId');
      if (!mounted) return progress;
      setState(() {
        processingStage = (progress['stage'] ?? '').toString();
        processedRecords = ((progress['processed'] ?? 0) as num).toInt();
        totalRecords = ((progress['total'] ?? 0) as num).toInt();
        importedRecords = ((progress['imported'] ?? 0) as num).toInt();
        skippedRecords = ((progress['skipped'] ?? 0) as num).toInt();
        ocrPagesProcessed =
            ((progress['ocrPagesProcessed'] ?? 0) as num).toInt();
        ocrPagesTotal = ((progress['ocrPagesTotal'] ?? 0) as num).toInt();
        ocrCardsProcessed =
            ((progress['ocrCardsProcessed'] ?? 0) as num).toInt();
        ocrCardsTotal = ((progress['ocrCardsTotal'] ?? 0) as num).toInt();
        serverProcessing = true;
      });
      if (progress['status'] == 'completed') {
        final result = progress['result'];
        if (result is Map) return Map<String, dynamic>.from(result);
        return progress;
      }
      if (progress['status'] == 'failed') {
        throw Exception(_localizedStage(
            (progress['stage'] ?? 'PDF import failed').toString()));
      }
      await Future.delayed(const Duration(seconds: 2));
    }
    throw Exception(
        'PDF का आयात अभी चल रहा है। कुछ देर बाद मतदाता सूची दोबारा खोलकर देखें।');
  }

  Future<void> upload(bool pdf) async {
    if (uploading) return;
    final ok = await api.validateSession();
    if (!ok) {
      setState(() => status =
          'आपका लॉगिन सत्र समाप्त हो गया है। कृपया दोबारा लॉगिन करें।');
      return;
    }
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: pdf ? ['pdf'] : ['xlsx', 'xls', 'csv'],
      withData: kIsWeb,
      withReadStream: !kIsWeb,
    );
    if (picked == null) return;
    final file = picked.files.single;
    if (file.size <= 0) {
      setState(() => status = 'चुनी गई फाइल खाली है या पढ़ी नहीं जा सकती।');
      return;
    }
    const maxUploadBytes = 250 * 1024 * 1024;
    if (file.size > maxUploadBytes) {
      setState(() => status =
          'फाइल बहुत बड़ी है। अधिकतम 250 MB की फाइल अपलोड की जा सकती है।');
      return;
    }
    setState(() {
      uploading = true;
      currentFile = file.name;
      currentBytes = file.size;
      uploadedBytes = 0;
      uploadTotalBytes = file.size;
      serverProcessing = false;
      processedRecords = 0;
      totalRecords = 0;
      importedRecords = 0;
      skippedRecords = 0;
      ocrPagesProcessed = 0;
      ocrPagesTotal = 0;
      ocrCardsProcessed = 0;
      ocrCardsTotal = 0;
      processingStage = '';
      status = 'फाइल अपलोड हो रही है। बड़ी PDF में कुछ समय लग सकता है…';
    });
    final uploadId = 'upload-${DateTime.now().millisecondsSinceEpoch}';
    try {
      var res = await api.uploadFile(
        pdf ? '/api/import/members/pdf' : '/api/import/members',
        filename: file.name,
        filePath: pickedFilePath(file),
        bytes: pickedFileBytes(file),
        fileStream: file.readStream,
        fileLength: file.size,
        fields: {
          'uploadId': uploadId,
          if (pdf) 'asyncImport': 'true',
        },
        onProgress: (sent, total) {
          if (!mounted) return;
          setState(() {
            uploadedBytes = sent;
            uploadTotalBytes = total > 0 ? total : file.size;
            if (sent >= uploadTotalBytes && uploadTotalBytes > 0) {
              serverProcessing = true;
              status = 'फाइल अपलोड हो गई। अब मतदाता रिकॉर्ड तैयार हो रहे हैं…';
            }
          });
        },
      );
      if (res['processing'] == true) {
        if (!mounted) return;
        setState(() {
          serverProcessing = true;
          status =
              'फाइल अपलोड हो गई। PDF पढ़कर मतदाता रिकॉर्ड बनाए जा रहे हैं…';
        });
        res = await waitForImportCompletion(uploadId);
      }
      await OfflineVoterCache.clear();
      api.notifyDataChanged();
      if (!mounted) return;
      setState(() {
        status =
            'आयात सफल रहा। ${res['imported'] ?? 0} मतदाता जोड़े गए और ${(res['skipped'] as List? ?? []).length} रिकॉर्ड समीक्षा के लिए छोड़े गए। मतदाता सूची अपने आप अपडेट हो गई है।';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => status = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => uploading = false);
    }
  }

  @override
  Widget build(BuildContext context) => AppPage(children: [
        const PageHeading(
          title: 'PDF / Excel अपलोड',
          subtitle: 'मतदाता सूची की PDF, Excel या CSV फाइल अपलोड करें',
        ),
        LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth > 650
                ? (constraints.maxWidth - 12) / 2
                : constraints.maxWidth;
            return Wrap(spacing: 12, runSpacing: 12, children: [
              SizedBox(
                width: width,
                child: _UploadCard(
                  title: 'मतदाता सूची PDF',
                  description: 'टेक्स्ट और स्कैन की हुई दोनों PDF समर्थित हैं',
                  icon: Icons.picture_as_pdf,
                  color: Colors.red,
                  enabled: !uploading,
                  onTap: () => upload(true),
                ),
              ),
              SizedBox(
                width: width,
                child: _UploadCard(
                  title: 'Excel / CSV',
                  description: 'एक साथ कई मतदाता रिकॉर्ड जोड़ें',
                  icon: Icons.table_view,
                  color: green,
                  enabled: !uploading,
                  onTap: () => upload(false),
                ),
              ),
            ]);
          },
        ),
        if (uploading || status.isNotEmpty)
          SectionCard(
            title: uploading ? 'अपलोड और आयात जारी है' : 'अपलोड का परिणाम',
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (currentFile != null)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const CircleAvatar(
                    backgroundColor: Color(0xffeef3ff),
                    child: Icon(Icons.insert_drive_file, color: blue),
                  ),
                  title: Text(currentFile!,
                      style: const TextStyle(fontWeight: FontWeight.w800)),
                  subtitle: Text(_formatBytes(currentBytes)),
                ),
              if (uploading) ...[
                LinearProgressIndicator(
                  minHeight: 7,
                  value: serverProcessing
                      ? totalRecords > 0
                          ? (processedRecords / totalRecords)
                              .clamp(0, 1)
                              .toDouble()
                          : ocrCardsTotal > 0
                              ? (ocrCardsProcessed / ocrCardsTotal)
                                  .clamp(0, 1)
                                  .toDouble()
                              : ocrPagesTotal > 0
                                  ? (ocrPagesProcessed / ocrPagesTotal)
                                      .clamp(0, 1)
                                      .toDouble()
                                  : null
                      : uploadTotalBytes > 0
                          ? (uploadedBytes / uploadTotalBytes)
                              .clamp(0, 1)
                              .toDouble()
                          : null,
                ),
                const SizedBox(height: 10),
                Text(
                  serverProcessing
                      ? totalRecords > 0
                          ? '$totalRecords में से $processedRecords रिकॉर्ड तैयार हुए • $importedRecords जोड़े गए • $skippedRecords छोड़े गए'
                          : ocrCardsTotal > 0
                              ? '$ocrCardsTotal में से $ocrCardsProcessed संभावित मतदाता रिकॉर्ड पढ़े गए'
                              : ocrPagesTotal > 0
                                  ? 'PDF के $ocrPagesTotal में से $ocrPagesProcessed पेज पढ़े गए'
                                  : '${processingStage.isEmpty ? 'PDF पढ़ी जा रही है' : _localizedStage(processingStage)}…'
                      : '${_formatBytes(uploadTotalBytes > 0 ? uploadTotalBytes : currentBytes)} में से ${_formatBytes(uploadedBytes)} अपलोड हुआ',
                  style:
                      const TextStyle(color: navy, fontWeight: FontWeight.w800),
                ),
                if (serverProcessing && processingStage.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(_localizedStage(processingStage),
                      style: const TextStyle(color: muted)),
                ],
                const SizedBox(height: 8),
                const Text(
                  'कृपया ऐप बंद न करें। फाइल अपलोड होने के बाद PDF पढ़ने और मतदाता जोड़ने में कुछ मिनट लग सकते हैं।',
                  style: TextStyle(color: muted),
                ),
              ] else
                Text(
                  status,
                  style: TextStyle(
                    color: status.startsWith('आयात सफल') ? green : Colors.red,
                    fontWeight: FontWeight.w700,
                  ),
                ),
            ]),
          ),
        const SectionCard(
          title: 'जरूरी जानकारी',
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('• अधिकतम 250 MB की फाइल अपलोड की जा सकती है।'),
            Text('• अपलोड और रिकॉर्ड आयात की प्रगति अलग-अलग दिखाई जाएगी।'),
            Text('• स्कैन की हुई PDF पढ़ने में कुछ मिनट लग सकते हैं।'),
            Text('• PDF में मिले वार्ड और बूथ अपने आप बनाए जाएंगे।'),
          ]),
        ),
      ]);
}

class _UploadCard extends StatelessWidget {
  const _UploadCard({
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
    required this.enabled,
    required this.onTap,
  });
  final String title;
  final String description;
  final IconData icon;
  final Color color;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: border),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(children: [
            CircleAvatar(
              radius: 28,
              backgroundColor: color.withValues(alpha: .1),
              child: Icon(icon, color: color, size: 30),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: const TextStyle(
                            color: navy,
                            fontSize: 17,
                            fontWeight: FontWeight.w900)),
                    const SizedBox(height: 5),
                    Text(description,
                        style: const TextStyle(color: muted, fontSize: 12)),
                  ]),
            ),
            const Icon(Icons.upload_rounded, color: blue),
          ]),
        ),
      );
}

String _formatBytes(int bytes) {
  if (bytes >= 1024 * 1024) {
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
  if (bytes >= 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
  return '$bytes बाइट';
}

String _localizedStage(String stage) {
  const stages = {
    'Waiting for upload': 'फाइल अपलोड होने की प्रतीक्षा है',
    'Receiving file on server': 'फाइल सर्वर पर भेजी जा रही है',
    'Upload received. Preparing import':
        'फाइल मिल गई, आयात की तैयारी हो रही है',
    'Upload received. PDF/OCR import running in background':
        'PDF पढ़कर मतदाता रिकॉर्ड बनाए जा रहे हैं',
    'Reading PDF/OCR text': 'PDF का टेक्स्ट पढ़ा जा रहा है',
    'Reading Excel/CSV file': 'Excel / CSV फाइल पढ़ी जा रही है',
    'Importing voter rows': 'मतदाता रिकॉर्ड जोड़े जा रहे हैं',
    'PDF records detected': 'PDF में मिले मतदाता रिकॉर्ड तैयार किए जा रहे हैं',
    'Building family records': 'परिवार रिकॉर्ड बनाए जा रहे हैं',
    'Import complete': 'आयात पूरा हो गया',
    'PDF import failed': 'PDF का आयात असफल रहा',
    'Excel/CSV import failed': 'Excel / CSV का आयात असफल रहा',
    'Preparing PDF pages for OCR': 'PDF के पेज OCR के लिए तैयार हो रहे हैं',
  };
  final pageProgress =
      RegExp(r'^Reading PDF pages (\d+) / (\d+)$').firstMatch(stage);
  if (pageProgress != null) {
    return 'PDF के ${pageProgress.group(2)} में से ${pageProgress.group(1)} पेज पढ़े गए';
  }
  final cardProgress =
      RegExp(r'^Reading voter cards (\d+) / (\d+)$').firstMatch(stage);
  if (cardProgress != null) {
    return '${cardProgress.group(2)} में से ${cardProgress.group(1)} संभावित मतदाता रिकॉर्ड पढ़े गए';
  }
  return stages[stage] ?? stage;
}
