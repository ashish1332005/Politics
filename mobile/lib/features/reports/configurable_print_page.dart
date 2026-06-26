import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../core/print_helper.dart';
import '../../core/theme.dart';
import '../../layout/app_layout.dart';
import '../../widgets/mobile_components.dart';

class ConfigurablePrintPage extends StatefulWidget {
  const ConfigurablePrintPage({super.key});

  @override
  State<ConfigurablePrintPage> createState() => _ConfigurablePrintPageState();
}

class _ConfigurablePrintPageState extends State<ConfigurablePrintPage> {
  final search = TextEditingController();
  final selectedIds = <String>{};
  final selectedOptionFilters = <String, Map<String, String>>{};
  final selectedOptionLabels = <String, String>{};
  final excludedIds = <String>{};
  final selectedFields = <String>{
    'name',
    'voterId',
    'guardianName',
    'mobile',
    'houseNumber',
    'village',
    'gramPanchayat',
    'section',
  };

  String support = '';
  String verification = '';
  String paper = 'A4';
  String orientation = 'portrait';
  int columns = 2;
  int page = 1;
  bool photo = true;
  bool selectAllFiltered = false;
  bool missingMobile = false;
  bool missingHouse = false;
  int refreshKey = 0;
  static const pageSize = 50;

  static const availableFields = <String, String>{
    'name': 'नाम',
    'voterId': 'EPIC',
    'mobile': 'मोबाइल',
    'altMobile': 'वैकल्पिक मोबाइल',
    'guardianName': 'पिता / पति',
    'relationType': 'संबंध',
    'age': 'उम्र',
    'gender': 'लिंग',
    'houseNumber': 'घर संख्या',
    'address': 'पूरा पता',
    'village': 'गाँव',
    'gramPanchayat': 'ग्राम पंचायत',
    'tehsil': 'तहसील',
    'municipality': 'नगर पालिका',
    'caste': 'जाति',
    'subCaste': 'उपजाति',
    'occupation': 'व्यवसाय',
    'education': 'शिक्षा',
    'organizationPost': 'संगठन पद',
    'supportLevel': 'समर्थन स्तर',
    'assembly': 'विधानसभा',
    'partNumber': 'भाग संख्या',
    'section': 'अनुभाग',
    'booth': 'बूथ',
    'ward': 'वार्ड',
  };

  Map<String, String?> get filters {
    final result = <String, String?>{
      'q': search.text.trim(),
      'supportLevel': support,
      'verificationStatus': verification,
      if (missingMobile) 'missingMobile': 'true',
      if (missingHouse) 'missingHouse': 'true',
    };
    for (final values in selectedOptionFilters.values) {
      result.addAll(values);
    }
    return result;
  }

  Map<String, String?> get listQuery => {
        ...filters,
        'paged': 'true',
        'page': '$page',
        'limit': '$pageSize',
        '_refresh': '$refreshKey',
      };

  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  void filtersChanged() => setState(() {
        page = 1;
        refreshKey++;
        selectAllFiltered = false;
        selectedIds.clear();
        excludedIds.clear();
      });

  bool isSelected(String id) =>
      selectAllFiltered ? !excludedIds.contains(id) : selectedIds.contains(id);

  void toggleVoter(String id, bool selected) => setState(() {
        if (selectAllFiltered) {
          selected ? excludedIds.remove(id) : excludedIds.add(id);
        } else {
          selected ? selectedIds.add(id) : selectedIds.remove(id);
        }
      });

  void chooseAllFiltered() => setState(() {
        selectAllFiltered = true;
        selectedIds.clear();
        excludedIds.clear();
      });

  void clearSelection() => setState(() {
        selectAllFiltered = false;
        selectedIds.clear();
        excludedIds.clear();
      });

  void smartSelect(String type) => setState(() {
        if (type == 'missingMobile') missingMobile = true;
        if (type == 'missingHouse') missingHouse = true;
        if (type == 'review') verification = 'needs_review';
        if (type == 'supporter') support = 'supporter';
        page = 1;
        refreshKey++;
        selectAllFiltered = true;
        selectedIds.clear();
        excludedIds.clear();
      });

  void clearSmartFilter(String type) => setState(() {
        if (type == 'missingMobile') missingMobile = false;
        if (type == 'missingHouse') missingHouse = false;
        if (type == 'review') verification = '';
        if (type == 'supporter') support = '';
        page = 1;
        refreshKey++;
        selectAllFiltered = false;
        selectedIds.clear();
        excludedIds.clear();
      });
  Future<void> openOptionSelector(String field, String label) async {
    final current = Map<String, String?>.from(filters);
    for (final key in selectedOptionFilters[field]?.keys ?? const <String>[]) {
      current.remove(key);
    }
    final option = await showDialog<_FilterOption>(
      context: context,
      builder: (_) => _FilterOptionDialog(
        field: field,
        title: label,
        currentFilters: current,
      ),
    );
    if (option == null || !mounted) return;
    setState(() {
      selectedOptionFilters[field] = option.filters;
      selectedOptionLabels[field] = option.label;
      page = 1;
      refreshKey++;
      selectAllFiltered = false;
      selectedIds.clear();
      excludedIds.clear();
    });
  }

  void clearOption(String field) => setState(() {
        selectedOptionFilters.remove(field);
        selectedOptionLabels.remove(field);
        page = 1;
        refreshKey++;
        selectAllFiltered = false;
        selectedIds.clear();
        excludedIds.clear();
      });
  void applyFieldPreset(String preset) => setState(() {
        selectedFields
          ..clear()
          ..addAll(switch (preset) {
            'basic' => {'name', 'voterId', 'guardianName', 'age', 'gender'},
            'contact' => {
                'name',
                'voterId',
                'mobile',
                'altMobile',
                'village',
                'address'
              },
            'location' => {
                'name',
                'voterId',
                'houseNumber',
                'address',
                'village',
                'gramPanchayat',
                'tehsil',
                'assembly',
                'partNumber',
                'section'
              },
            'political' => {
                'name',
                'voterId',
                'mobile',
                'village',
                'caste',
                'organizationPost',
                'supportLevel'
              },
            _ => availableFields.keys,
          });
      });

  Future<void> printSelected(int filteredTotal) async {
    if (!selectAllFiltered && selectedIds.isEmpty) return;
    final count = selectAllFiltered
        ? (filteredTotal - excludedIds.length).clamp(0, filteredTotal)
        : selectedIds.length;
    await printApiPdf(
      context,
      path: '/api/print/members.pdf',
      jobName: 'चयनित मतदाता सूची',
      query: {
        ...filters,
        if (selectAllFiltered) 'selectAll': 'true',
        if (!selectAllFiltered) 'ids': selectedIds.join(','),
        if (selectAllFiltered && excludedIds.isNotEmpty)
          'excludedIds': excludedIds.join(','),
        'fields': selectedFields.join(','),
        'paperSize': paper,
        'orientation': orientation,
        'columns': '$columns',
        'photo': '$photo',
        'title': 'चयनित मतदाता सूची ($count)',
      },
    );
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<Map<String, dynamic>>(
        future: api.getQuery('/api/members', listQuery),
        builder: (context, snapshot) {
          final loading = snapshot.connectionState != ConnectionState.done;
          final data = snapshot.data ?? const <String, dynamic>{};
          final items = List<Map<String, dynamic>>.from(
            (data['items'] as List? ?? [])
                .map((item) => Map<String, dynamic>.from(item)),
          );
          final total = _number(data['total']);
          final pages = _number(data['pages']).clamp(1, 999999);
          final selectedCount = selectAllFiltered
              ? (total - excludedIds.length).clamp(0, total)
              : selectedIds.length;
          final pageIds = items.map((item) => '${item['_id']}').toList();
          final allPageSelected =
              pageIds.isNotEmpty && pageIds.every(isSelected);

          return AppPage(children: [
            PageHeading(
              title: 'स्मार्ट Bulk Print',
              subtitle:
                  'मतदाता चुनें, जानकारी चुनें और साफ PDF preview के बाद print करें',
              action: _SelectionBadge(
                  count: selectedCount, allFiltered: selectAllFiltered),
            ),
            SectionCard(
              title: '1. मतदाता चुनें',
              action: selectedCount > 0
                  ? TextButton.icon(
                      onPressed: clearSelection,
                      icon: const Icon(Icons.close_rounded),
                      label: const Text('चयन साफ करें'))
                  : null,
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Smart select',
                        style: TextStyle(
                            color: navy, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 8),
                    Wrap(spacing: 8, runSpacing: 8, children: [
                      _SmartChip(Icons.phone_disabled_rounded, 'मोबाइल गायब',
                          rose, () => smartSelect('missingMobile')),
                      _SmartChip(Icons.other_houses_rounded, 'घर संख्या गायब',
                          orange, () => smartSelect('missingHouse')),
                      _SmartChip(Icons.fact_check_rounded, 'Review जरूरी',
                          purple, () => smartSelect('review')),
                      _SmartChip(Icons.groups_rounded, 'सभी समर्थक', green,
                          () => smartSelect('supporter')),
                      _SmartChip(Icons.select_all_rounded,
                          'इन filters के सभी चुनें', blue, chooseAllFiltered),
                    ]),
                    if (missingMobile ||
                        missingHouse ||
                        verification == 'needs_review' ||
                        support == 'supporter') ...[
                      const SizedBox(height: 10),
                      Wrap(spacing: 7, runSpacing: 7, children: [
                        if (missingMobile)
                          InputChip(
                              label: const Text('मोबाइल गायब'),
                              onDeleted: () =>
                                  clearSmartFilter('missingMobile')),
                        if (missingHouse)
                          InputChip(
                              label: const Text('घर संख्या गायब'),
                              onDeleted: () =>
                                  clearSmartFilter('missingHouse')),
                        if (verification == 'needs_review')
                          InputChip(
                              label: const Text('Review जरूरी'),
                              onDeleted: () => clearSmartFilter('review')),
                        if (support == 'supporter')
                          InputChip(
                              label: const Text('समर्थक'),
                              onDeleted: () => clearSmartFilter('supporter')),
                      ]),
                    ],
                    const Divider(height: 28),
                    Wrap(spacing: 10, runSpacing: 10, children: [
                      _SearchBox(
                          controller: search,
                          label: 'नाम, EPIC या मोबाइल',
                          icon: Icons.search_rounded,
                          onChanged: (_) => filtersChanged(),
                          width: 260),
                      _DatabaseFilterPicker(
                        label: 'विधानसभा',
                        icon: Icons.account_balance_rounded,
                        value: selectedOptionLabels['assembly'],
                        onTap: () => openOptionSelector('assembly', 'विधानसभा'),
                        onClear: () => clearOption('assembly'),
                      ),
                      _DatabaseFilterPicker(
                        label: 'गाँव',
                        icon: Icons.location_city_rounded,
                        value: selectedOptionLabels['village'],
                        onTap: () => openOptionSelector('village', 'गाँव'),
                        onClear: () => clearOption('village'),
                      ),
                      _DatabaseFilterPicker(
                        label: 'ग्राम पंचायत',
                        icon: Icons.holiday_village_rounded,
                        value: selectedOptionLabels['gramPanchayat'],
                        onTap: () =>
                            openOptionSelector('gramPanchayat', 'ग्राम पंचायत'),
                        onClear: () => clearOption('gramPanchayat'),
                      ),
                      _DatabaseFilterPicker(
                        label: 'तहसील',
                        icon: Icons.apartment_rounded,
                        value: selectedOptionLabels['tehsil'],
                        onTap: () => openOptionSelector('tehsil', 'तहसील'),
                        onClear: () => clearOption('tehsil'),
                      ),
                      _DatabaseFilterPicker(
                        label: 'नगर पालिका',
                        icon: Icons.location_city_outlined,
                        value: selectedOptionLabels['municipality'],
                        onTap: () =>
                            openOptionSelector('municipality', 'नगर पालिका'),
                        onClear: () => clearOption('municipality'),
                      ),
                      _DatabaseFilterPicker(
                        label: 'भाग / बूथ',
                        icon: Icons.how_to_vote_rounded,
                        value: selectedOptionLabels['partNumber'],
                        onTap: () =>
                            openOptionSelector('partNumber', 'भाग / बूथ'),
                        onClear: () => clearOption('partNumber'),
                      ),
                      _DatabaseFilterPicker(
                        label: 'अनुभाग',
                        icon: Icons.format_list_numbered_rounded,
                        value: selectedOptionLabels['section'],
                        onTap: () => openOptionSelector('section', 'अनुभाग'),
                        onClear: () => clearOption('section'),
                      ),
                      _DatabaseFilterPicker(
                        label: 'जाति',
                        icon: Icons.groups_2_rounded,
                        value: selectedOptionLabels['caste'],
                        onTap: () => openOptionSelector('caste', 'जाति'),
                        onClear: () => clearOption('caste'),
                      ),
                      _DatabaseFilterPicker(
                        label: 'संगठन पद',
                        icon: Icons.badge_rounded,
                        value: selectedOptionLabels['organizationPost'],
                        onTap: () =>
                            openOptionSelector('organizationPost', 'संगठन पद'),
                        onClear: () => clearOption('organizationPost'),
                      ),
                      _DropFilter(
                        label: 'समर्थन',
                        value: support,
                        items: const {
                          '': 'सभी',
                          'supporter': 'समर्थक',
                          'opposite': 'विरोधी',
                          'neutral': 'तटस्थ',
                          'undecided': 'अनिर्णीत',
                        },
                        onChanged: (value) {
                          support = value;
                          filtersChanged();
                        },
                      ),
                    ]),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                          color: const Color(0xfff5f8fe),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: border)),
                      child: Column(children: [
                        Row(children: [
                          Checkbox(
                            value: allPageSelected,
                            onChanged: pageIds.isEmpty
                                ? null
                                : (value) => setState(() {
                                      for (final id in pageIds) {
                                        if (selectAllFiltered) {
                                          value == true
                                              ? excludedIds.remove(id)
                                              : excludedIds.add(id);
                                        } else {
                                          value == true
                                              ? selectedIds.add(id)
                                              : selectedIds.remove(id);
                                        }
                                      }
                                    }),
                          ),
                          Expanded(
                            child: Text('मतदाता ($total)',
                                style: const TextStyle(
                                    color: navy, fontWeight: FontWeight.w900)),
                          ),
                          TextButton.icon(
                            onPressed: pageIds.isEmpty
                                ? null
                                : () => setState(() {
                                      for (final id in pageIds) {
                                        allPageSelected
                                            ? (selectAllFiltered
                                                ? excludedIds.add(id)
                                                : selectedIds.remove(id))
                                            : (selectAllFiltered
                                                ? excludedIds.remove(id)
                                                : selectedIds.add(id));
                                      }
                                    }),
                            icon: const Icon(Icons.library_add_check_rounded),
                            label: Text(allPageSelected
                                ? 'इस पेज का चयन हटाएँ'
                                : 'इस पेज के सभी चुनें'),
                          ),
                        ]),
                        if (loading)
                          const Padding(
                              padding: EdgeInsets.all(28),
                              child: CircularProgressIndicator())
                        else if (snapshot.hasError)
                          Padding(
                              padding: const EdgeInsets.all(18),
                              child: Text('${snapshot.error}',
                                  style: const TextStyle(color: Colors.red)))
                        else if (items.isEmpty)
                          const Padding(
                              padding: EdgeInsets.all(28),
                              child:
                                  Text('इन filters में कोई मतदाता नहीं मिला।'))
                        else
                          ...items.map((voter) => _VoterChoice(
                                voter: voter,
                                selected: isSelected('${voter['_id']}'),
                                onChanged: (value) =>
                                    toggleVoter('${voter['_id']}', value),
                              )),
                        if (pages > 1)
                          Padding(
                            padding: const EdgeInsets.only(top: 12),
                            child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  IconButton.outlined(
                                      onPressed: page <= 1
                                          ? null
                                          : () => setState(() => page--),
                                      icon: const Icon(
                                          Icons.chevron_left_rounded)),
                                  Padding(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 14),
                                      child: Text('पेज $page / $pages',
                                          style: const TextStyle(
                                              color: navy,
                                              fontWeight: FontWeight.w800))),
                                  IconButton.outlined(
                                      onPressed: page >= pages
                                          ? null
                                          : () => setState(() => page++),
                                      icon: const Icon(
                                          Icons.chevron_right_rounded)),
                                ]),
                          ),
                      ]),
                    ),
                  ]),
            ),
            SectionCard(
              title: '2. Print में जानकारी चुनें',
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(spacing: 8, runSpacing: 8, children: [
                      ActionChip(
                          avatar: const Icon(Icons.badge_outlined, size: 18),
                          label: const Text('Basic'),
                          onPressed: () => applyFieldPreset('basic')),
                      ActionChip(
                          avatar: const Icon(Icons.call_outlined, size: 18),
                          label: const Text('Contact'),
                          onPressed: () => applyFieldPreset('contact')),
                      ActionChip(
                          avatar: const Icon(Icons.map_outlined, size: 18),
                          label: const Text('पता एवं क्षेत्र'),
                          onPressed: () => applyFieldPreset('location')),
                      ActionChip(
                          avatar: const Icon(Icons.groups_outlined, size: 18),
                          label: const Text('राजनीतिक'),
                          onPressed: () => applyFieldPreset('political')),
                      ActionChip(
                          avatar: const Icon(Icons.done_all_rounded, size: 18),
                          label: const Text('सभी जानकारी'),
                          onPressed: () => applyFieldPreset('all')),
                      ActionChip(
                          avatar: const Icon(Icons.clear_all_rounded, size: 18),
                          label: const Text('साफ करें'),
                          onPressed: () => setState(selectedFields.clear)),
                    ]),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 7,
                      runSpacing: 7,
                      children: availableFields.entries
                          .map((entry) => FilterChip(
                                label: Text(entry.value),
                                selected: selectedFields.contains(entry.key),
                                onSelected: (value) => setState(() => value
                                    ? selectedFields.add(entry.key)
                                    : selectedFields.remove(entry.key)),
                              ))
                          .toList(),
                    ),
                    const SizedBox(height: 8),
                    Text('${selectedFields.length} fields चुने गए',
                        style: const TextStyle(color: muted, fontSize: 12)),
                  ]),
            ),
            SectionCard(
              title: '3. Page layout और preview',
              child: LayoutBuilder(builder: (context, constraints) {
                final controls = Wrap(spacing: 10, runSpacing: 10, children: [
                  _SimpleDropdown(
                      label: 'पेपर',
                      value: paper,
                      items: const ['A4', 'A3', 'LETTER'],
                      onChanged: (value) => setState(() => paper = value)),
                  _SimpleDropdown(
                      label: 'दिशा',
                      value: orientation,
                      items: const ['portrait', 'landscape'],
                      display: const {
                        'portrait': 'Portrait',
                        'landscape': 'Landscape'
                      },
                      onChanged: (value) =>
                          setState(() => orientation = value)),
                  _SimpleDropdown(
                      label: 'प्रति पंक्ति कार्ड',
                      value: '$columns',
                      items: const ['1', '2', '3'],
                      onChanged: (value) =>
                          setState(() => columns = int.parse(value))),
                  FilterChip(
                      avatar: const Icon(Icons.photo_outlined, size: 18),
                      label: const Text('फोटो शामिल करें'),
                      selected: photo,
                      onSelected: (value) => setState(() => photo = value)),
                ]);
                final preview = _PrintPreviewMock(
                    columns: columns,
                    photo: photo,
                    fields: selectedFields
                        .take(6)
                        .map((key) => availableFields[key]!)
                        .toList());
                if (constraints.maxWidth < 760) {
                  return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        controls,
                        const SizedBox(height: 18),
                        preview,
                      ]);
                }
                return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: controls),
                      const SizedBox(width: 20),
                      SizedBox(width: 330, child: preview),
                    ]);
              }),
            ),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                  color: const Color(0xffedf4ff),
                  border: Border.all(color: const Color(0xffcbdcff)),
                  borderRadius: BorderRadius.circular(14)),
              child: Row(children: [
                const Icon(Icons.print_rounded, color: blue, size: 30),
                const SizedBox(width: 12),
                Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text(
                          '$selectedCount मतदाता · ${selectedFields.length} fields',
                          style: const TextStyle(
                              color: navy, fontWeight: FontWeight.w900)),
                      const Text('Print dialog में PDF preview दिखेगा',
                          style: TextStyle(color: muted, fontSize: 12)),
                    ])),
                FilledButton.icon(
                  onPressed: selectedCount == 0 || selectedFields.isEmpty
                      ? null
                      : () => printSelected(total),
                  icon: const Icon(Icons.picture_as_pdf_rounded),
                  label: const Text('Preview एवं Print'),
                ),
              ]),
            ),
          ]);
        },
      );
}

class _SelectionBadge extends StatelessWidget {
  const _SelectionBadge({required this.count, required this.allFiltered});
  final int count;
  final bool allFiltered;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
        decoration: BoxDecoration(
            color: count > 0 ? const Color(0xffeaf8f0) : Colors.white,
            border: Border.all(color: count > 0 ? green : border),
            borderRadius: BorderRadius.circular(10)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(count > 0 ? Icons.check_circle_rounded : Icons.touch_app_rounded,
              color: count > 0 ? green : muted, size: 19),
          const SizedBox(width: 7),
          Text(
              count > 0
                  ? '$count चयनित${allFiltered ? ' (filtered)' : ''}'
                  : 'मतदाता चुनें',
              style: TextStyle(
                  color: count > 0 ? green : muted,
                  fontWeight: FontWeight.w800)),
        ]),
      );
}

class _SmartChip extends StatelessWidget {
  const _SmartChip(this.icon, this.label, this.color, this.onTap);
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => ActionChip(
        avatar: Icon(icon, color: color, size: 18),
        label: Text(label),
        onPressed: onTap,
        side: BorderSide(color: color.withValues(alpha: .35)),
        backgroundColor: color.withValues(alpha: .06),
      );
}

class _FilterOption {
  const _FilterOption(
      {required this.label, required this.count, required this.filters});
  final String label;
  final int count;
  final Map<String, String> filters;

  factory _FilterOption.fromMap(Map<String, dynamic> map) => _FilterOption(
        label: '${map['label'] ?? map['value'] ?? '-'}',
        count: _number(map['count']),
        filters: Map<String, String>.from(
          (map['filters'] as Map? ?? const {}).map(
            (key, value) => MapEntry('$key', '$value'),
          ),
        ),
      );
}

class _FilterOptionDialog extends StatefulWidget {
  const _FilterOptionDialog({
    required this.field,
    required this.title,
    required this.currentFilters,
  });
  final String field;
  final String title;
  final Map<String, String?> currentFilters;

  @override
  State<_FilterOptionDialog> createState() => _FilterOptionDialogState();
}

class _FilterOptionDialogState extends State<_FilterOptionDialog> {
  final search = TextEditingController();

  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        titlePadding: const EdgeInsets.fromLTRB(20, 18, 12, 8),
        contentPadding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
        title: Row(children: [
          Expanded(
              child: Text('${widget.title} चुनें',
                  style: const TextStyle(
                      color: navy, fontWeight: FontWeight.w900))),
          IconButton(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.close_rounded)),
        ]),
        content: SizedBox(
          width: 520,
          height: 560,
          child: Column(children: [
            TextField(
              controller: search,
              autofocus: true,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search_rounded),
                hintText: '${widget.title} खोजें...',
                suffixIcon: search.text.isEmpty
                    ? null
                    : IconButton(
                        onPressed: () {
                          search.clear();
                          setState(() {});
                        },
                        icon: const Icon(Icons.close_rounded)),
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: FutureBuilder<Map<String, dynamic>>(
                future: api.getQuery('/api/members/filter-options', {
                  ...widget.currentFilters,
                  'field': widget.field,
                  'q': search.text.trim(),
                  'limit': '120',
                }),
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return Center(
                        child: Text('${snapshot.error}',
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Colors.red)));
                  }
                  final options = List<Map<String, dynamic>>.from(
                    (snapshot.data?['items'] as List? ?? [])
                        .map((item) => Map<String, dynamic>.from(item)),
                  ).map(_FilterOption.fromMap).toList();
                  if (options.isEmpty) {
                    return const Center(
                        child: Text('Database में matching option नहीं मिला।',
                            style: TextStyle(color: muted)));
                  }
                  return ListView.separated(
                    itemCount: options.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (_, index) {
                      final option = options[index];
                      return ListTile(
                        leading: const CircleAvatar(
                            backgroundColor: Color(0xffedf4ff),
                            child: Icon(Icons.location_on_rounded,
                                color: blue, size: 20)),
                        title: Text(option.label,
                            style: const TextStyle(
                                color: navy, fontWeight: FontWeight.w800)),
                        subtitle: Text('${option.count} मतदाता'),
                        trailing: const Icon(Icons.chevron_right_rounded),
                        onTap: () => Navigator.pop(context, option),
                      );
                    },
                  );
                },
              ),
            ),
          ]),
        ),
      );
}

class _DatabaseFilterPicker extends StatelessWidget {
  const _DatabaseFilterPicker({
    required this.label,
    required this.icon,
    required this.value,
    required this.onTap,
    required this.onClear,
  });
  final String label;
  final IconData icon;
  final String? value;
  final VoidCallback onTap;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final selected = value != null && value!.trim().isNotEmpty;
    return SizedBox(
      width: 210,
      child: Material(
        color: selected ? const Color(0xffedf4ff) : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(color: selected ? blue : border),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 9, 6, 9),
            child: Row(children: [
              Icon(icon, color: selected ? blue : muted, size: 21),
              const SizedBox(width: 9),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text(label,
                        style: const TextStyle(color: muted, fontSize: 10)),
                    const SizedBox(height: 2),
                    Text(selected ? value! : 'Database से चुनें',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            color: selected ? navy : muted,
                            fontSize: 12,
                            fontWeight: FontWeight.w800)),
                  ])),
              if (selected)
                IconButton(
                    tooltip: 'हटाएँ',
                    visualDensity: VisualDensity.compact,
                    onPressed: onClear,
                    icon: const Icon(Icons.close_rounded, size: 18))
              else
                const Icon(Icons.arrow_drop_down_rounded, color: muted),
            ]),
          ),
        ),
      ),
    );
  }
}

class _SearchBox extends StatelessWidget {
  const _SearchBox(
      {required this.controller,
      required this.label,
      required this.icon,
      required this.onChanged,
      this.width = 180});
  final TextEditingController controller;
  final String label;
  final IconData icon;
  final ValueChanged<String> onChanged;
  final double width;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: width,
        child: TextField(
          controller: controller,
          onChanged: onChanged,
          decoration: InputDecoration(
              labelText: label, prefixIcon: Icon(icon, size: 20)),
        ),
      );
}

class _DropFilter extends StatelessWidget {
  const _DropFilter(
      {required this.label,
      required this.value,
      required this.items,
      required this.onChanged});
  final String label;
  final String value;
  final Map<String, String> items;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 180,
        child: DropdownButtonFormField<String>(
          key: ValueKey('$label-$value'),
          initialValue: value,
          decoration: InputDecoration(labelText: label),
          items: items.entries
              .map((entry) =>
                  DropdownMenuItem(value: entry.key, child: Text(entry.value)))
              .toList(),
          onChanged: (value) => onChanged(value ?? ''),
        ),
      );
}

class _SimpleDropdown extends StatelessWidget {
  const _SimpleDropdown(
      {required this.label,
      required this.value,
      required this.items,
      required this.onChanged,
      this.display = const {}});
  final String label;
  final String value;
  final List<String> items;
  final ValueChanged<String> onChanged;
  final Map<String, String> display;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 180,
        child: DropdownButtonFormField<String>(
          key: ValueKey('$label-$value'),
          initialValue: value,
          decoration: InputDecoration(labelText: label),
          items: items
              .map((item) => DropdownMenuItem(
                  value: item, child: Text(display[item] ?? item)))
              .toList(),
          onChanged: (value) => onChanged(value!),
        ),
      );
}

class _VoterChoice extends StatelessWidget {
  const _VoterChoice(
      {required this.voter, required this.selected, required this.onChanged});
  final Map<String, dynamic> voter;
  final bool selected;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) => Material(
        color: selected ? const Color(0xffedf4ff) : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: CheckboxListTile(
          value: selected,
          onChanged: (value) => onChanged(value ?? false),
          controlAffinity: ListTileControlAffinity.leading,
          contentPadding: const EdgeInsets.symmetric(horizontal: 8),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          title: Text('${voter['name'] ?? '-'}',
              style: const TextStyle(color: navy, fontWeight: FontWeight.w800)),
          subtitle: Text(
            '${voter['voterId'] ?? '-'}  ·  घर ${voter['houseNumber'] ?? '-'}  ·  ${voter['village'] ?? voter['location'] ?? '-'}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          secondary: Text('${voter['mobile'] ?? ''}',
              style: const TextStyle(color: muted, fontSize: 12)),
        ),
      );
}

class _PrintPreviewMock extends StatelessWidget {
  const _PrintPreviewMock(
      {required this.columns, required this.photo, required this.fields});
  final int columns;
  final bool photo;
  final List<String> fields;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
            color: const Color(0xffe8edf5),
            borderRadius: BorderRadius.circular(12)),
        child: AspectRatio(
          aspectRatio: 1.414,
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(4),
                boxShadow: const [
                  BoxShadow(color: Colors.black12, blurRadius: 8)
                ]),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('मतदाता सूची',
                  style: TextStyle(
                      color: navy, fontSize: 8, fontWeight: FontWeight.w900)),
              const Divider(height: 8),
              Expanded(
                child: GridView.builder(
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: columns,
                      crossAxisSpacing: 4,
                      mainAxisSpacing: 4,
                      childAspectRatio: .9),
                  itemCount: columns * 2,
                  itemBuilder: (_, __) => Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                        border: Border.all(color: border),
                        borderRadius: BorderRadius.circular(3)),
                    child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (photo) ...[
                            Container(
                                width: 16,
                                height: 22,
                                color: const Color(0xffe9eef7)),
                            const SizedBox(width: 3),
                          ],
                          Expanded(
                              child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: fields
                                      .map((field) => Padding(
                                          padding:
                                              const EdgeInsets.only(bottom: 2),
                                          child: Text('$field: —',
                                              maxLines: 1,
                                              style: const TextStyle(
                                                  fontSize: 4, color: navy))))
                                      .toList())),
                        ]),
                  ),
                ),
              ),
            ]),
          ),
        ),
      );
}

int _number(dynamic value) =>
    value is num ? value.toInt() : int.tryParse('$value') ?? 0;
