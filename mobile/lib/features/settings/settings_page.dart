import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../core/download_helper.dart';

import '../../core/api_client.dart';
import '../../core/offline_voter_cache.dart';
import '../auth/login_page.dart';
import '../../layout/app_layout.dart';
import '../../widgets/common.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  @override
  Widget build(BuildContext context) => AppPage(children: [
        const Panel(
            title: 'सेटिंग्स',
            child: Text('प्रोफाइल सेटिंग्स, सुरक्षा, बैकअप और restore।')),
        if (api.user?['role'] == 'admin')
          Panel(
            title: 'Data Security',
            child: Wrap(spacing: 10, runSpacing: 10, children: [
              OutlinedButton.icon(
                onPressed: () => saveApiFile(context,
                    path: '/api/export/backup',
                    fallbackName: 'political-crm-backup.json'),
                icon: const Icon(Icons.backup_outlined),
                label: const Text('Backup Download'),
              ),
              FilledButton.icon(
                onPressed: _restore,
                icon: const Icon(Icons.restore),
                label: const Text('Restore Backup'),
              ),
            ]),
          ),
        FilledButton.icon(
          onPressed: () {
            api.logout();
            Navigator.pushReplacement(
                context, MaterialPageRoute(builder: (_) => const LoginPage()));
          },
          icon: const Icon(Icons.logout),
          label: const Text('लॉगआउट'),
        ),
      ]);
  Future<void> _restore() async {
    final picked = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['json'],
        withData: true);
    if (picked == null || picked.files.single.bytes == null || !mounted) return;
    final data = Map<String, dynamic>.from(
        jsonDecode(utf8.decode(picked.files.single.bytes!)));
    final yes = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Backup restore करें?'),
        content: Text(
            '${(data['members'] as List? ?? []).length} voter records update/restore होंगे।'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Restore')),
        ],
      ),
    );
    if (yes != true) return;
    final result = await api.post(
        '/api/security/restore', {...data, 'confirmation': 'RESTORE BACKUP'});
    await OfflineVoterCache.clear();
    api.notifyDataChanged();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Restored ${result['restoredMembers']} voters')));
    }
  }
}
