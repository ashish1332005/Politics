import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../core/offline_voter_cache.dart';
import '../../core/picked_file_source.dart';
import '../../layout/app_layout.dart';
import '../../widgets/common.dart';

class SmartExcelImportPage extends StatefulWidget {
  const SmartExcelImportPage({super.key});
  @override
  State<SmartExcelImportPage> createState() => _SmartExcelImportPageState();
}

class _SmartExcelImportPageState extends State<SmartExcelImportPage> {
  Map<String, dynamic>? preview;
  Map<String, String> mapping = {};
  Map<String, dynamic>? validation;
  final corrections = <String, Map<String, String>>{};
  String? ward;
  String? booth;
  bool busy = false;

  Future<void> pick() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['xlsx', 'xls', 'csv'],
      withData: kIsWeb,
    );
    if (result == null) return;
    final file = result.files.single;
    setState(() => busy = true);
    final data = await api.uploadFile(
      '/api/import-previews',
      filename: file.name,
      filePath: pickedFilePath(file),
      bytes: pickedFileBytes(file),
    );
    setState(() {
      preview = data;
      mapping = Map<String, String>.from(data['suggestedMapping'] ?? {});
      validation = Map<String, dynamic>.from(data['summary'] ?? {});
      busy = false;
    });
  }

  Future<void> validate() async {
    final result = await api.post(
        '/api/import-previews/${preview!['previewId']}/validate',
        {'mapping': mapping, 'corrections': corrections});
    setState(() => validation = result);
  }

  Future<void> commit() async {
    if (ward == null || booth == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Ward और booth चुनें।')));
      return;
    }
    final result =
        await api.post('/api/import-previews/${preview!['previewId']}/commit', {
      'mapping': mapping,
      'ward': ward,
      'booth': booth,
    });
    await OfflineVoterCache.clear();
    api.notifyDataChanged();
    if (!mounted) return;
    setState(() => preview = null);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(
          'Created ${result['created']}, updated ${result['updated']}, review ${result['reviewRequired']} — data auto-refresh ho gaya'),
    ));
  }

  @override
  Widget build(BuildContext context) => AppPage(children: [
        PageHeading(
          title: 'Smart Excel Import',
          subtitle: 'पहले preview और mapping, फिर database import',
          action: FilledButton.icon(
              onPressed: busy ? null : pick,
              icon: const Icon(Icons.upload_file),
              label: const Text('Excel चुनें')),
        ),
        if (busy) const LinearProgressIndicator(),
        if (preview != null) ...[
          _summary(),
          _invalidCorrectionPanel(),
          Panel(
            title: 'Column Mapping',
            child: Column(children: [
              ...List<String>.from(preview!['headers'] ?? [])
                  .map((header) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(children: [
                          Expanded(
                              child: Text(header,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w700))),
                          const Icon(Icons.arrow_forward),
                          const SizedBox(width: 10),
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              initialValue: mapping[header] ?? '',
                              items: [
                                const DropdownMenuItem(
                                    value: '', child: Text('Ignore')),
                                ...List<String>.from(preview!['targets'] ?? [])
                                    .map((target) => DropdownMenuItem(
                                        value: target, child: Text(target))),
                              ],
                              onChanged: (value) =>
                                  mapping[header] = value ?? '',
                            ),
                          ),
                        ]),
                      )),
              const SizedBox(height: 8),
              Wrap(spacing: 10, runSpacing: 10, children: [
                FutureBlock<List<dynamic>>(
                  load: () => api.list('/api/wards'),
                  builder: (items) => SizedBox(
                    width: 220,
                    child: DropdownButtonFormField<String>(
                      initialValue: ward,
                      decoration: const InputDecoration(labelText: 'Ward'),
                      items: items
                          .map((item) => DropdownMenuItem(
                              value: '${item['_id']}',
                              child:
                                  Text('${item['number']} - ${item['name']}')))
                          .toList(),
                      onChanged: (value) => setState(() => ward = value),
                    ),
                  ),
                ),
                FutureBlock<List<dynamic>>(
                  load: () => api.list('/api/booths'),
                  builder: (items) => SizedBox(
                    width: 220,
                    child: DropdownButtonFormField<String>(
                      initialValue: booth,
                      decoration: const InputDecoration(labelText: 'Booth'),
                      items: items
                          .map((item) => DropdownMenuItem(
                              value: '${item['_id']}',
                              child:
                                  Text('${item['number']} - ${item['name']}')))
                          .toList(),
                      onChanged: (value) => setState(() => booth = value),
                    ),
                  ),
                ),
              ]),
              const SizedBox(height: 12),
              Wrap(spacing: 10, children: [
                OutlinedButton.icon(
                    onPressed: validate,
                    icon: const Icon(Icons.fact_check),
                    label: const Text('Validate again')),
                FilledButton.icon(
                    onPressed: commit,
                    icon: const Icon(Icons.save),
                    label: const Text('Confirm Import')),
              ]),
            ]),
          ),
          Panel(
            title: 'Sample Preview',
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columns: List<String>.from(preview!['headers'] ?? [])
                    .take(8)
                    .map((header) => DataColumn(label: Text(header)))
                    .toList(),
                rows:
                    List.from(preview!['sampleRows'] ?? []).take(10).map((row) {
                  final data = Map<String, dynamic>.from(row);
                  return DataRow(
                      cells: List<String>.from(preview!['headers'] ?? [])
                          .take(8)
                          .map((header) =>
                              DataCell(Text('${data[header] ?? ''}')))
                          .toList());
                }).toList(),
              ),
            ),
          ),
        ],
      ]);

  Widget _summary() {
    final data = validation ?? {};
    return Wrap(spacing: 10, runSpacing: 10, children: [
      _metric('Total', data['total']),
      _metric('Create', data['creates']),
      _metric('Update', data['updates']),
      _metric('Invalid EPIC', data['invalidEpic']),
      _metric('File duplicates', data['fileDuplicates']),
      _metric('Mobile duplicates', data['mobileDuplicates']),
    ]);
  }

  Widget _invalidCorrectionPanel() {
    final rows = List.from(validation?['invalidRows'] ?? []);
    if (rows.isEmpty) return const SizedBox.shrink();
    return Panel(
      title: 'Invalid records correction',
      child: Column(
        children: rows.map((raw) {
          final row = Map<String, dynamic>.from(raw);
          return ListTile(
            title: Text('Row ${row['row']} • ${row['name'] ?? '-'}'),
            subtitle: Text(
                'EPIC: ${row['voterId'] ?? '-'} • Area: ${row['areaName'] ?? '-'} • Post: ${row['organizationPost'] ?? '-'}'),
            trailing: OutlinedButton(
                onPressed: () => _correctRow(row),
                child: const Text('Correct')),
          );
        }).toList(),
      ),
    );
  }

  Future<void> _correctRow(Map<String, dynamic> row) async {
    final epic = TextEditingController(text: '${row['voterId'] ?? ''}');
    final area = TextEditingController(text: '${row['areaName'] ?? ''}');
    final post =
        TextEditingController(text: '${row['organizationPost'] ?? ''}');
    final mobile = TextEditingController(text: '${row['mobile'] ?? ''}');
    final save = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Row ${row['row']} correction'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(
              controller: epic,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(labelText: 'EPIC')),
          TextField(
              controller: mobile,
              decoration: const InputDecoration(labelText: 'Mobile')),
          TextField(
              controller: area,
              decoration: const InputDecoration(
                  labelText: 'Area / Panchayat / Municipality')),
          TextField(
              controller: post,
              decoration: const InputDecoration(labelText: 'Political post')),
        ]),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Save')),
        ],
      ),
    );
    if (save != true) return;
    corrections['${row['row']}'] = {
      'voterId': epic.text.trim(),
      'mobile': mobile.text.trim(),
      'areaName': area.text.trim(),
      'organizationPost': post.text.trim(),
    };
    await validate();
  }

  Widget _metric(String label, dynamic value) =>
      Chip(label: Text('$label: ${value ?? 0}'));
}
