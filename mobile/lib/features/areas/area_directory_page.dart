import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../core/theme.dart';
import '../../layout/app_layout.dart';
import '../../widgets/common.dart';
import '../voters/voter_management_page.dart';

class AreaDirectoryPage extends StatefulWidget {
  const AreaDirectoryPage({super.key});

  @override
  State<AreaDirectoryPage> createState() => _AreaDirectoryPageState();
}

class _AreaDirectoryPageState extends State<AreaDirectoryPage> {
  Future<void> _deleteAllAreas() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('सभी क्षेत्र हटाएँ?'),
        content: const Text(
            'सभी विधानसभा, तहसील, पंचायत, नगरपालिका, गाँव और वार्ड हट जाएँगे। मतदाता रिकॉर्ड नहीं हटेंगे।'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('रद्द करें')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('सभी हटाएँ'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await api.delete('/api/areas/all');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('सभी क्षेत्र हटा दिए गए')),
      );
      setState(() {});
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('$error')));
    }
  }

  Future<void> _deleteArea(Map<String, dynamic> area) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('क्षेत्र हटाएँ?'),
        content: Text(
            '${area['name']} को हटाना चाहते हैं? इसके अंदर कोई क्षेत्र होने पर पहले उसे हटाना होगा।'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('रद्द करें')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('हटाएँ'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await api.delete('/api/areas/${area['_id']}');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${area['name']} हटा दिया गया')));
      setState(() {});
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('$error')));
    }
  }

  Future<void> _addArea({Map<String, dynamic>? parent}) async {
    final name = TextEditingController();
    final code = TextEditingController();
    final district = TextEditingController();
    String type = parent == null ? 'assembly' : _childType('${parent['type']}');
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(parent == null
              ? 'विधानसभा जोड़ें'
              : '${parent['name']} में क्षेत्र जोड़ें'),
          content: SizedBox(
            width: 430,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextField(
                  controller: name,
                  decoration: const InputDecoration(labelText: 'नाम *')),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: type,
                decoration:
                    const InputDecoration(labelText: 'क्षेत्र का प्रकार'),
                items: const {
                  'assembly': 'विधानसभा',
                  'tehsil': 'तहसील',
                  'gram_panchayat': 'ग्राम पंचायत',
                  'municipality': 'नगर पालिका',
                  'village': 'गाँव',
                  'ward': 'वार्ड',
                }
                    .entries
                    .map((e) =>
                        DropdownMenuItem(value: e.key, child: Text(e.value)))
                    .toList(),
                onChanged: (value) => setDialogState(() => type = value!),
              ),
              const SizedBox(height: 12),
              TextField(
                  controller: code,
                  decoration: const InputDecoration(labelText: 'संख्या / कोड')),
              const SizedBox(height: 12),
              TextField(
                  controller: district,
                  decoration: const InputDecoration(labelText: 'जिला')),
            ]),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('रद्द करें')),
            FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('सहेजें')),
          ],
        ),
      ),
    );
    if (saved != true || name.text.trim().isEmpty) return;
    await api.post('/api/areas', {
      'name': name.text.trim(),
      'code': code.text.trim(),
      'district': district.text.trim(),
      'type': type,
      if (parent != null) 'parent': parent['_id'],
      if (type == 'assembly') 'assemblyNumber': code.text.trim(),
    });
    if (mounted) setState(() {});
  }

  String _childType(String type) => switch (type) {
        'assembly' => 'tehsil',
        'tehsil' => 'gram_panchayat',
        'gram_panchayat' => 'village',
        'municipality' => 'ward',
        _ => 'village',
      };

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Text('क्षेत्र एवं मतदाता डायरेक्टरी'),
          actions: [
            if (api.user?['role'] == 'admin') ...[
              IconButton(
                tooltip: 'सभी क्षेत्र हटाएँ',
                onPressed: _deleteAllAreas,
                icon:
                    const Icon(Icons.delete_sweep_outlined, color: Colors.red),
              ),
              IconButton(
                tooltip: 'विधानसभा जोड़ें',
                onPressed: () => _addArea(),
                icon: const Icon(Icons.add_location_alt_outlined),
              ),
            ],
          ],
        ),
        body: AppPage(children: [
          const PageHeading(
            title: 'विधानसभा',
            subtitle:
                'विधानसभा से तहसील, पंचायत, नगरपालिका, गाँव और वार्ड तक जाएँ',
          ),
          FutureBlock<List<dynamic>>(
            load: () => api.list('/api/areas/tree'),
            builder: (items) {
              if (items.isEmpty) {
                return _EmptyAreas(onAdd: () => _addArea());
              }
              return Column(
                children: items
                    .map((item) => _AreaNode(
                          area: Map<String, dynamic>.from(item),
                          onAdd: _addArea,
                          onDelete: _deleteArea,
                        ))
                    .toList(),
              );
            },
          ),
        ]),
      );
}

class _AreaNode extends StatelessWidget {
  const _AreaNode(
      {required this.area, required this.onAdd, required this.onDelete});
  final Map<String, dynamic> area;
  final Future<void> Function({Map<String, dynamic>? parent}) onAdd;
  final Future<void> Function(Map<String, dynamic> area) onDelete;

  @override
  Widget build(BuildContext context) {
    final children = List.from(area['children'] ?? []);
    final type = '${area['type']}';
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: blue.withValues(alpha: .1),
          child: Icon(_icon(type), color: blue),
        ),
        title: Text('${area['name']}',
            style: const TextStyle(fontWeight: FontWeight.w900, color: navy)),
        subtitle: Text('${_label(type)} • ${area['voterCount'] ?? 0} मतदाता'),
        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
          IconButton(
            tooltip: 'मतदाता खोलें',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => VoterManagementPage(
                  initialAreaId: '${area['_id']}',
                  initialAreaName: '${area['name']}',
                ),
              ),
            ),
            icon: const Icon(Icons.groups_outlined, color: green),
          ),
          if (api.user?['role'] == 'admin' &&
              !['village', 'ward'].contains(type))
            IconButton(
              tooltip: 'इसके अंदर क्षेत्र जोड़ें',
              onPressed: () => onAdd(parent: area),
              icon: const Icon(Icons.add_circle_outline, color: blue),
            ),
          if (api.user?['role'] == 'admin')
            IconButton(
              tooltip: 'क्षेत्र हटाएँ',
              onPressed: () => onDelete(area),
              icon: const Icon(Icons.delete_outline, color: Colors.red),
            ),
          const Icon(Icons.expand_more),
        ]),
        childrenPadding: const EdgeInsets.fromLTRB(18, 0, 8, 10),
        children: children
            .map((child) => _AreaNode(
                  area: Map<String, dynamic>.from(child),
                  onAdd: onAdd,
                  onDelete: onDelete,
                ))
            .toList(),
      ),
    );
  }

  IconData _icon(String type) => switch (type) {
        'assembly' => Icons.account_balance_outlined,
        'tehsil' => Icons.location_city_outlined,
        'gram_panchayat' => Icons.holiday_village_outlined,
        'municipality' => Icons.apartment_outlined,
        'ward' => Icons.grid_view_outlined,
        _ => Icons.home_work_outlined,
      };

  String _label(String type) =>
      const {
        'assembly': 'विधानसभा',
        'tehsil': 'तहसील',
        'gram_panchayat': 'ग्राम पंचायत',
        'municipality': 'नगर पालिका',
        'village': 'गाँव',
        'ward': 'वार्ड',
      }[type] ??
      type;
}

class _EmptyAreas extends StatelessWidget {
  const _EmptyAreas({required this.onAdd});
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(36),
          child: Column(children: [
            const Icon(Icons.account_balance_outlined, size: 70, color: muted),
            const SizedBox(height: 12),
            const Text('अभी कोई विधानसभा नहीं जोड़ी गई है',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: 10),
            if (api.user?['role'] == 'admin')
              FilledButton.icon(
                  onPressed: onAdd,
                  icon: const Icon(Icons.add),
                  label: const Text('पहली विधानसभा जोड़ें')),
          ]),
        ),
      );
}
