import 'dart:async';

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
  int serverUploadBytes = 0;
  int serverUploadTotalBytes = 0;
  String processingStage = '';
  Timer? progressTimer;

  @override
  void dispose() {
    progressTimer?.cancel();
    super.dispose();
  }

  void startProgressPolling(String uploadId) {
    progressTimer?.cancel();
    progressTimer = Timer.periodic(const Duration(seconds: 1), (_) async {
      try {
        final progress = await api.get('/api/import/status/$uploadId');
        if (!mounted) return;
        setState(() {
          processingStage = (progress['stage'] ?? '').toString();
          processedRecords = ((progress['processed'] ?? 0) as num).toInt();
          totalRecords = ((progress['total'] ?? 0) as num).toInt();
          importedRecords = ((progress['imported'] ?? 0) as num).toInt();
          skippedRecords = ((progress['skipped'] ?? 0) as num).toInt();
          serverUploadBytes = ((progress['uploadBytes'] ?? 0) as num).toInt();
          serverUploadTotalBytes =
              ((progress['uploadTotalBytes'] ?? 0) as num).toInt();
          if (progress['status'] == 'processing' || totalRecords > 0) {
            serverProcessing = true;
          }
        });
      } catch (_) {}
    });
  }

  Future<void> upload(bool pdf) async {
    if (uploading) return;
    final ok = await api.validateSession();
    if (!ok) {
      setState(() => status = 'Session expired. Logout/login again.');
      return;
    }
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: pdf ? ['pdf'] : ['xlsx', 'xls', 'csv'],
      withData: kIsWeb,
    );
    if (picked == null) return;
    final file = picked.files.single;
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
      serverUploadBytes = 0;
      serverUploadTotalBytes = 0;
      processingStage = '';
      status =
          'File upload ho rahi hai. Badi PDF me kuch samay lag sakta hai...';
    });
    final uploadId = 'upload-${DateTime.now().millisecondsSinceEpoch}';
    startProgressPolling(uploadId);
    try {
      final res = await api.uploadFile(
        pdf ? '/api/import/members/pdf' : '/api/import/members',
        filename: file.name,
        filePath: pickedFilePath(file),
        bytes: pickedFileBytes(file),
        fields: {'uploadId': uploadId},
        onProgress: (sent, total) {
          if (!mounted) return;
          setState(() {
            uploadedBytes = sent;
            uploadTotalBytes = total > 0 ? total : file.size;
            if (sent >= uploadTotalBytes && uploadTotalBytes > 0) {
              serverProcessing = true;
              status =
                  'Upload complete. Server processing/import kar raha hai...';
            }
          });
        },
      );
      await OfflineVoterCache.clear();
      api.notifyDataChanged();
      if (!mounted) return;
      setState(() {
        status =
            'Mode: ${res['extractionMode'] ?? 'standard'} | Imported ${res['imported'] ?? 0}, skipped ${(res['skipped'] as List? ?? []).length}. Data auto-refresh ho gaya. ${res['imageExtractionStatus'] ?? ''}';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => status = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      progressTimer?.cancel();
      if (mounted) setState(() => uploading = false);
    }
  }

  @override
  Widget build(BuildContext context) => AppPage(children: [
        const PageHeading(
          title: 'PDF / Excel अपलोड',
          subtitle: 'Badi voter-list files upload aur process karein',
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
                  title: 'Voter List PDF',
                  description: 'Text/scanned PDF aur OCR support',
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
                  description: 'Bulk voter aur family records import karein',
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
            title:
                uploading ? 'Upload aur processing jaari hai' : 'Upload result',
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
                  value: serverProcessing && totalRecords > 0
                      ? (processedRecords / totalRecords).clamp(0, 1).toDouble()
                      : serverUploadTotalBytes > 0
                          ? (serverUploadBytes / serverUploadTotalBytes)
                              .clamp(0, 1)
                              .toDouble()
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
                          ? 'Processing $processedRecords / $totalRecords records | Imported $importedRecords, skipped $skippedRecords'
                          : '${processingStage.isEmpty ? 'Server processing kar raha hai' : processingStage}...'
                      : 'Uploaded ${_formatBytes(uploadedBytes)} / ${_formatBytes(uploadTotalBytes > 0 ? uploadTotalBytes : currentBytes)}',
                  style:
                      const TextStyle(color: navy, fontWeight: FontWeight.w800),
                ),
                if (serverProcessing && processingStage.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(processingStage, style: const TextStyle(color: muted)),
                ],
                const SizedBox(height: 8),
                const Text(
                  'App band na karein. Upload ke baad PDF/OCR processing me kuch minute lag sakte hain.',
                  style: TextStyle(color: muted),
                ),
              ] else
                Text(
                  status,
                  style: TextStyle(
                    color: status.contains('Imported') ? green : Colors.red,
                    fontWeight: FontWeight.w700,
                  ),
                ),
            ]),
          ),
        const SectionCard(
          title: 'Large file support',
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('• Maximum upload size: 250 MB'),
            Text(
                '• Upload progress aur server import progress alag-alag dikhega'),
            Text(
                '• OCR/PDF processing upload complete hone ke baad bhi chal sakti hai'),
            Text(
                '• Ward/booth PDF se detect hone par automatic create hote hain'),
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
  return '$bytes bytes';
}
