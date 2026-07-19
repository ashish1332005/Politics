import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../core/theme.dart';
import '../../layout/app_layout.dart';
import '../../widgets/common.dart';
import '../../widgets/mobile_components.dart';

class ImportReviewPage extends StatefulWidget {
  const ImportReviewPage({super.key});

  @override
  State<ImportReviewPage> createState() => _ImportReviewPageState();
}

class _ImportReviewPageState extends State<ImportReviewPage> {
  @override
  Widget build(BuildContext context) => AppPage(children: [
        const PremiumFeatureHero(
            title: 'EPIC समीक्षा सूची',
            subtitle:
                'OCR में अधूरे या अस्पष्ट EPIC records को आसानी से जांचकर ठीक करें।',
            icon: Icons.fact_check_rounded,
            accent: purple,
            badges: ['Review', 'Correct', 'Verified']),
        FutureBlock<List<dynamic>>(
          load: () => api.list('/api/import-reviews'),
          builder: (items) => items.isEmpty
              ? const PremiumEmptyState(
                  icon: Icons.verified_rounded,
                  title: 'सभी EPIC records ठीक हैं',
                  subtitle: 'अभी review के लिए कोई अधूरा record नहीं है।',
                )
              : Column(
                  children: items.map((raw) {
                    final item = Map<String, dynamic>.from(raw);
                    final voter =
                        Map<String, dynamic>.from(item['suggestedData'] ?? {});
                    return Card(
                      margin: const EdgeInsets.only(bottom: 10),
                      child: ListTile(
                        leading: const CircleAvatar(
                            backgroundColor: Color(0xfff1eaff),
                            foregroundColor: purple,
                            child: Icon(Icons.badge_outlined)),
                        title: Text('${voter['name'] ?? 'नाम उपलब्ध नहीं'}'),
                        subtitle: Text(
                            '${voter['guardianName'] ?? ''} • ${voter['houseNumber'] ?? ''}\n${item['reason'] ?? ''}'),
                        isThreeLine: true,
                        trailing: FilledButton.icon(
                            onPressed: () => _resolve(item),
                            icon: const Icon(Icons.edit_rounded, size: 17),
                            label: const Text('EPIC')),
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
        title: const Text('सही EPIC नंबर'),
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
              child: const Text('अपडेट करें')),
        ],
      ),
    );
    if (save != true) return;
    await api.post('/api/import-reviews/${item['_id']}/resolve',
        {'voterId': epic.text.trim()});
    if (mounted) setState(() {});
  }
}
