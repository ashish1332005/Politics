import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../layout/app_layout.dart';
import '../../widgets/common.dart';

class ImportReviewPage extends StatefulWidget {
  const ImportReviewPage({super.key});

  @override
  State<ImportReviewPage> createState() => _ImportReviewPageState();
}

class _ImportReviewPageState extends State<ImportReviewPage> {
  @override
  Widget build(BuildContext context) => AppPage(children: [
        const PageHeading(
            title: 'EPIC Review Queue',
            subtitle: 'जिन voters का EPIC upload में नहीं पढ़ा गया'),
        FutureBlock<List<dynamic>>(
          load: () => api.list('/api/import-reviews'),
          builder: (items) => Column(
            children: items.map((raw) {
              final item = Map<String, dynamic>.from(raw);
              final voter =
                  Map<String, dynamic>.from(item['suggestedData'] ?? {});
              return Card(
                child: ListTile(
                  leading:
                      const CircleAvatar(child: Icon(Icons.badge_outlined)),
                  title: Text('${voter['name'] ?? 'नाम उपलब्ध नहीं'}'),
                  subtitle: Text(
                      '${voter['guardianName'] ?? ''} • ${voter['houseNumber'] ?? ''}\n${item['reason'] ?? ''}'),
                  isThreeLine: true,
                  trailing: FilledButton(
                      onPressed: () => _resolve(item),
                      child: const Text('EPIC भरें')),
                ),
              );
            }).toList(),
          ),
        ),
      ]);

  Future<void> _resolve(Map<String, dynamic> item) async {
    final epic = TextEditingController();
    final save = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('सही EPIC number'),
        content: TextField(
            controller: epic,
            textCapitalization: TextCapitalization.characters,
            decoration: const InputDecoration(hintText: 'ABC1234567')),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('रद्द करें')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Update / Merge')),
        ],
      ),
    );
    if (save != true) return;
    await api.post('/api/import-reviews/${item['_id']}/resolve',
        {'voterId': epic.text.trim()});
    if (mounted) setState(() {});
  }
}
