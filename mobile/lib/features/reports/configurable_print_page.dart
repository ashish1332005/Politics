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
  bool votersExpanded = true;
  bool fieldsExpanded = false;
  bool layoutExpanded = false;
  bool generateExpanded = false;
  String fieldCategory = 'identity';
  int refreshKey = 0;
  late Future<Map<String, dynamic>> votersFuture;
  static const pageSize = 50;

  static const availableFields = <String, String>{
    'name': 'नाम',
    'voterId': 'EPIC',
    'mobile': 'मोबाइल',
    'altMobile': 'अन्य मोबाइल',
    'guardianName': 'पिता / पति का नाम',
    'relationType': 'संबंध',
    'age': 'उम्र',
    'gender': 'लिंग',
    'houseNumber': 'घर संख्या',
    'address': 'पता',
    'village': 'गाँव',
    'gramPanchayat': 'ग्राम पंचायत',
    'tehsil': 'तहसील',
    'municipality': 'नगर पालिका',
    'caste': 'जाति',
    'subCaste': 'उपजाति',
    'occupation': 'व्यवसाय',
    'education': 'शिक्षा',
    'organizationPost': 'संगठन पद',
    'supportLevel': 'समर्थन',
    'assembly': 'विधानसभा',
    'partNumber': 'भाग / बूथ',
    'section': 'अनुभाग',
    'booth': 'बूथ',
    'ward': 'वार्ड',
  };

  static const fieldCategories = <String, List<String>>{
    'identity': [
      'name',
      'voterId',
      'guardianName',
      'relationType',
      'age',
      'gender'
    ],
    'contact': ['mobile', 'altMobile', 'address', 'houseNumber'],
    'location': [
      'village',
      'gramPanchayat',
      'tehsil',
      'municipality',
      'assembly',
      'partNumber',
      'section',
      'booth',
      'ward'
    ],
    'profile': [
      'caste',
      'subCaste',
      'occupation',
      'education',
      'organizationPost',
      'supportLevel'
    ],
  };

  static const fieldCategoryLabels = <String, String>{
    'identity': 'पहचान',
    'contact': 'संपर्क',
    'location': 'क्षेत्र',
    'profile': 'प्रोफ़ाइल',
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
  void initState() {
    super.initState();
    refreshVoters();
  }

  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  void refreshVoters() {
    votersFuture = api.getQuery('/api/members', listQuery);
  }

  void filtersChanged() => setState(() {
        page = 1;
        refreshKey++;
        selectAllFiltered = false;
        selectedIds.clear();
        excludedIds.clear();
        refreshVoters();
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
        refreshVoters();
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
        refreshVoters();
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
      refreshVoters();
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
        refreshVoters();
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
      jobName: 'Selected voter list',
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
        'title': 'Selected voter list ($count)',
      },
    );
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<Map<String, dynamic>>(
        future: votersFuture,
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
          final activeFilterCount = selectedOptionLabels.length +
              (search.text.trim().isEmpty ? 0 : 1) +
              (support.isEmpty ? 0 : 1) +
              (verification.isEmpty ? 0 : 1) +
              (missingMobile ? 1 : 0) +
              (missingHouse ? 1 : 0);
          final pageIds = items.map((item) => '${item['_id']}').toList();
          final allPageSelected =
              pageIds.isNotEmpty && pageIds.every(isSelected);

          return AppPage(children: [
            AppHeroBanner(
              title: 'Smart Print',
              subtitle:
                  'मतदाता चुनें, जरूरी जानकारी और लेआउट तय करें, फिर सुरक्षित PDF बनाएं।',
              icon: Icons.print_rounded,
              primaryAction: _SelectionBadge(
                  count: selectedCount, allFiltered: selectAllFiltered),
            ),
            _PrintSetupSummary(
              selectedCount: selectedCount,
              fieldCount: selectedFields.length,
              activeFilterCount: activeFilterCount,
              layout:
                  '$paper · ${orientation == 'portrait' ? 'पोर्ट्रेट' : 'लैंडस्केप'} · $columns कार्ड/पंक्ति',
              ready: selectedCount > 0 && selectedFields.isNotEmpty,
            ),
            _PrintStepProgress(
              selectedCount: selectedCount,
              fieldsReady: selectedFields.isNotEmpty,
              layoutReady: true,
            ),
            _PrintStepCard(
              title: '1. मतदाता चुनें',
              subtitle: 'नाम, EPIC या मोबाइल से खोजें और जरूरी मतदाता चुनें।',
              icon: Icons.groups_rounded,
              expanded: votersExpanded,
              onToggle: () => setState(() => votersExpanded = !votersExpanded),
              action: selectedCount > 0
                  ? TextButton.icon(
                      onPressed: clearSelection,
                      icon: const Icon(Icons.close_rounded),
                      label: const Text('चयन हटाएं'))
                  : null,
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _QuickSelectPanel(
                      onMissingMobile: () => smartSelect('missingMobile'),
                      onMissingHouse: () => smartSelect('missingHouse'),
                      onReview: () => smartSelect('review'),
                      onSupporter: () => smartSelect('supporter'),
                      onAllFiltered: chooseAllFiltered,
                    ),
                    if (missingMobile ||
                        missingHouse ||
                        verification == 'needs_review' ||
                        support == 'supporter') ...[
                      const SizedBox(height: 10),
                      Wrap(spacing: 7, runSpacing: 7, children: [
                        if (missingMobile)
                          InputChip(
                              label: const Text('मोबाइल नहीं है'),
                              onDeleted: () =>
                                  clearSmartFilter('missingMobile')),
                        if (missingHouse)
                          InputChip(
                              label: const Text('घर संख्या नहीं है'),
                              onDeleted: () =>
                                  clearSmartFilter('missingHouse')),
                        if (verification == 'needs_review')
                          InputChip(
                              label: const Text('समीक्षा जरूरी'),
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
                          label: 'नाम, EPIC या मोबाइल खोजें',
                          icon: Icons.search_rounded,
                          onChanged: (_) => filtersChanged(),
                          width: 260),
                      _DatabaseFilterPicker(
                        label: 'विधानसभा',
                        icon: Icons.account_balance_rounded,
                        value: selectedOptionLabels['assembly'],
                        onTap: () => openOptionSelector('assembly', 'Assembly'),
                        onClear: () => clearOption('assembly'),
                      ),
                      _DatabaseFilterPicker(
                        label: 'गाँव',
                        icon: Icons.location_city_rounded,
                        value: selectedOptionLabels['village'],
                        onTap: () => openOptionSelector('village', 'Village'),
                        onClear: () => clearOption('village'),
                      ),
                      _DatabaseFilterPicker(
                        label: 'ग्राम पंचायत',
                        icon: Icons.holiday_village_rounded,
                        value: selectedOptionLabels['gramPanchayat'],
                        onTap: () => openOptionSelector(
                            'gramPanchayat', 'Gram Panchayat'),
                        onClear: () => clearOption('gramPanchayat'),
                      ),
                      _DatabaseFilterPicker(
                        label: 'तहसील',
                        icon: Icons.apartment_rounded,
                        value: selectedOptionLabels['tehsil'],
                        onTap: () => openOptionSelector('tehsil', 'Tehsil'),
                        onClear: () => clearOption('tehsil'),
                      ),
                      _DatabaseFilterPicker(
                        label: 'नगर पालिका',
                        icon: Icons.location_city_outlined,
                        value: selectedOptionLabels['municipality'],
                        onTap: () =>
                            openOptionSelector('municipality', 'Municipality'),
                        onClear: () => clearOption('municipality'),
                      ),
                      _DatabaseFilterPicker(
                        label: 'भाग / बूथ',
                        icon: Icons.how_to_vote_rounded,
                        value: selectedOptionLabels['partNumber'],
                        onTap: () =>
                            openOptionSelector('partNumber', 'Part / Booth'),
                        onClear: () => clearOption('partNumber'),
                      ),
                      _DatabaseFilterPicker(
                        label: 'अनुभाग',
                        icon: Icons.format_list_numbered_rounded,
                        value: selectedOptionLabels['section'],
                        onTap: () => openOptionSelector('section', 'Section'),
                        onClear: () => clearOption('section'),
                      ),
                      _DatabaseFilterPicker(
                        label: 'जाति',
                        icon: Icons.groups_2_rounded,
                        value: selectedOptionLabels['caste'],
                        onTap: () => openOptionSelector('caste', 'Caste'),
                        onClear: () => clearOption('caste'),
                      ),
                      _DatabaseFilterPicker(
                        label: 'संगठन पद',
                        icon: Icons.badge_rounded,
                        value: selectedOptionLabels['organizationPost'],
                        onTap: () =>
                            openOptionSelector('organizationPost', 'Org Post'),
                        onClear: () => clearOption('organizationPost'),
                      ),
                      _DropFilter(
                        label: 'समर्थन',
                        value: support,
                        items: const {
                          '': 'All',
                          'supporter': 'Supporter',
                          'opposite': 'Opposite',
                          'neutral': 'Neutral',
                          'undecided': 'Undecided',
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
                                ? 'Unselect this page'
                                : 'Select this page'),
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
                                  Text('इन फ़िल्टर में कोई मतदाता नहीं मिला।'))
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
                                          : () => setState(() {
                                                page--;
                                                refreshVoters();
                                              }),
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
                                          : () => setState(() {
                                                page++;
                                                refreshVoters();
                                              }),
                                      icon: const Icon(
                                          Icons.chevron_right_rounded)),
                                ]),
                          ),
                      ]),
                    ),
                  ]),
            ),
            _PrintStepCard(
              title: '2. फ़ील्ड और जानकारी चुनें',
              subtitle: 'PDF में कौन-कौन सी जानकारी दिखानी है, उसे चुनें।',
              icon: Icons.fact_check_rounded,
              expanded: fieldsExpanded,
              onToggle: () => setState(() => fieldsExpanded = !fieldsExpanded),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _PresetBar(
                      onPreset: applyFieldPreset,
                      onClear: () => setState(selectedFields.clear),
                    ),
                    const SizedBox(height: 8),
                    _FieldCategoryBar(
                      selected: fieldCategory,
                      labels: fieldCategoryLabels,
                      onChanged: (value) =>
                          setState(() => fieldCategory = value),
                    ),
                    const SizedBox(height: 10),
                    _FieldCategoryPanel(
                      title: fieldCategoryLabels[fieldCategory] ?? 'Fields',
                      fields: fieldCategories[fieldCategory] ?? const [],
                      labels: availableFields,
                      selectedFields: selectedFields,
                      onChanged: (field, selected) => setState(() => selected
                          ? selectedFields.add(field)
                          : selectedFields.remove(field)),
                    ),
                    const SizedBox(height: 10),
                    _SelectedFieldSummary(
                      count: selectedFields.length,
                      fields: selectedFields,
                      labels: availableFields,
                      onRemove: (field) =>
                          setState(() => selectedFields.remove(field)),
                    ),
                  ]),
            ),
            _PrintStepCard(
              title: '3. लेआउट और प्रीव्यू',
              subtitle: 'पेपर, दिशा, एक पंक्ति में कार्ड और फोटो चुनें।',
              icon: Icons.preview_rounded,
              expanded: layoutExpanded,
              onToggle: () => setState(() => layoutExpanded = !layoutExpanded),
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
                        'portrait': 'पोर्ट्रेट',
                        'landscape': 'लैंडस्केप'
                      },
                      onChanged: (value) =>
                          setState(() => orientation = value)),
                  _SimpleDropdown(
                      label: 'एक पंक्ति में कार्ड',
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
            _PrintStepCard(
              title: '4. PDF बनाएं',
              subtitle:
                  'अपनी सेटिंग जांचें, फिर PDF बनाकर डाउनलोड या प्रिंट करें।',
              icon: Icons.picture_as_pdf_rounded,
              expanded: generateExpanded,
              onToggle: () =>
                  setState(() => generateExpanded = !generateExpanded),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xffedf4ff), Color(0xfff8fbff)],
                    ),
                    border: Border.all(color: const Color(0xffcbdcff)),
                    borderRadius: BorderRadius.circular(14)),
                child: LayoutBuilder(builder: (context, constraints) {
                  final summary = Row(children: [
                    const Icon(Icons.print_rounded, color: blue, size: 30),
                    const SizedBox(width: 12),
                    Expanded(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                          Text(
                              '$selectedCount मतदाता · ${selectedFields.length} फ़ील्ड',
                              style: const TextStyle(
                                  color: navy, fontWeight: FontWeight.w900)),
                          const Text('प्रिंट से पहले PDF प्रीव्यू खुलेगा',
                              style: TextStyle(color: muted, fontSize: 12)),
                        ])),
                  ]);
                  final button = FilledButton.icon(
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(210, 52),
                      textStyle: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                    onPressed: selectedCount == 0 || selectedFields.isEmpty
                        ? null
                        : () => printSelected(total),
                    icon: const Icon(Icons.print_rounded),
                    label: const Text('PDF बनाएं और डाउनलोड करें'),
                  );
                  if (constraints.maxWidth < 560) {
                    return Column(children: [
                      summary,
                      const SizedBox(height: 14),
                      SizedBox(width: double.infinity, child: button),
                    ]);
                  }
                  return Row(children: [
                    Expanded(child: summary),
                    const SizedBox(width: 14),
                    button,
                  ]);
                }),
              ),
            ),
          ]);
        },
      );
}

class _PrintStepProgress extends StatelessWidget {
  const _PrintStepProgress({
    required this.selectedCount,
    required this.fieldsReady,
    required this.layoutReady,
  });

  final int selectedCount;
  final bool fieldsReady;
  final bool layoutReady;

  @override
  Widget build(BuildContext context) {
    final activeStep = selectedCount == 0
        ? 0
        : !fieldsReady
            ? 1
            : layoutReady
                ? 3
                : 2;
    const labels = ['मतदाता', 'फ़ील्ड', 'लेआउट', 'PDF'];
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 16, 12, 13),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: border),
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(
              color: Color(0x0d071b4b), blurRadius: 18, offset: Offset(0, 8)),
        ],
      ),
      child: Row(
        children: List.generate(labels.length, (index) {
          final reached = index <= activeStep;
          return Expanded(
            child: Row(children: [
              Expanded(
                child: Column(children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: reached ? blue : const Color(0xffe8edf6),
                      boxShadow: reached
                          ? const [
                              BoxShadow(
                                  color: Color(0x331457f5),
                                  blurRadius: 10,
                                  offset: Offset(0, 4))
                            ]
                          : null,
                    ),
                    alignment: Alignment.center,
                    child: Text('${index + 1}',
                        style: TextStyle(
                            color: reached ? Colors.white : navy,
                            fontWeight: FontWeight.w900)),
                  ),
                  const SizedBox(height: 7),
                  Text(labels[index],
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          color: reached ? navy : muted,
                          fontSize: 10,
                          fontWeight: FontWeight.w800)),
                ]),
              ),
              if (index < labels.length - 1)
                Container(
                  width: 10,
                  height: 2,
                  margin: const EdgeInsets.only(bottom: 24),
                  color: index < activeStep ? blue : border,
                ),
            ]),
          );
        }),
      ),
    );
  }
}

class _PrintStepCard extends StatelessWidget {
  const _PrintStepCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.expanded,
    required this.onToggle,
    required this.child,
    this.action,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final bool expanded;
  final VoidCallback onToggle;
  final Widget child;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          color: Colors.white,
          border:
              Border.all(color: expanded ? const Color(0xffcbdcff) : border),
          borderRadius: BorderRadius.circular(18),
          boxShadow: const [
            BoxShadow(
                color: Color(0x0d071b4b), blurRadius: 18, offset: Offset(0, 8)),
          ],
        ),
        child: Column(children: [
          InkWell(
            onTap: onToggle,
            borderRadius: BorderRadius.circular(18),
            child: Padding(
              padding: const EdgeInsets.all(15),
              child: Row(children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: softBlue,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: blue, size: 21),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title,
                            style: const TextStyle(
                                color: navy,
                                fontSize: 16,
                                fontWeight: FontWeight.w900)),
                        const SizedBox(height: 3),
                        Text(subtitle,
                            maxLines: expanded ? 2 : 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: muted, fontSize: 11)),
                      ]),
                ),
                if (action != null) ...[
                  const SizedBox(width: 6),
                  action!,
                ],
                AnimatedRotation(
                  turns: expanded ? .5 : 0,
                  duration: const Duration(milliseconds: 220),
                  child: const Icon(Icons.keyboard_arrow_down_rounded,
                      color: navy),
                ),
              ]),
            ),
          ),
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 220),
            crossFadeState:
                expanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
            firstChild: const SizedBox(width: double.infinity),
            secondChild: Padding(
              padding: const EdgeInsets.fromLTRB(15, 0, 15, 15),
              child: Column(children: [
                const Divider(height: 1),
                const SizedBox(height: 15),
                child,
              ]),
            ),
          ),
        ]),
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
                  ? '$count चुने${allFiltered ? ' (फ़िल्टर से)' : ''}'
                  : 'मतदाता चुनें',
              style: TextStyle(
                  color: count > 0 ? green : muted,
                  fontWeight: FontWeight.w800)),
        ]),
      );
}

class _PresetBar extends StatelessWidget {
  const _PresetBar({required this.onPreset, required this.onClear});

  final ValueChanged<String> onPreset;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(children: [
          _PresetButton(
              Icons.badge_outlined, 'बुनियादी', () => onPreset('basic')),
          _PresetButton(
              Icons.call_outlined, 'संपर्क', () => onPreset('contact')),
          _PresetButton(
              Icons.map_outlined, 'क्षेत्र', () => onPreset('location')),
          _PresetButton(
              Icons.groups_outlined, 'राजनीतिक', () => onPreset('political')),
          _PresetButton(Icons.done_all_rounded, 'सभी', () => onPreset('all')),
          _PresetButton(Icons.clear_all_rounded, 'हटाएं', onClear),
        ]),
      );
}

class _PresetButton extends StatelessWidget {
  const _PresetButton(this.icon, this.label, this.onTap);

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(right: 7),
        child: ActionChip(
          avatar: Icon(icon, size: 17),
          label: Text(label),
          visualDensity: VisualDensity.compact,
          onPressed: onTap,
        ),
      );
}

class _FieldCategoryBar extends StatelessWidget {
  const _FieldCategoryBar({
    required this.selected,
    required this.labels,
    required this.onChanged,
  });

  final String selected;
  final Map<String, String> labels;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: labels.entries
              .map((entry) => Padding(
                    padding: const EdgeInsets.only(right: 7),
                    child: ChoiceChip(
                      label: Text(entry.value),
                      selected: selected == entry.key,
                      visualDensity: VisualDensity.compact,
                      onSelected: (_) => onChanged(entry.key),
                    ),
                  ))
              .toList(),
        ),
      );
}

class _FieldCategoryPanel extends StatelessWidget {
  const _FieldCategoryPanel({
    required this.title,
    required this.fields,
    required this.labels,
    required this.selectedFields,
    required this.onChanged,
  });

  final String title;
  final List<String> fields;
  final Map<String, String> labels;
  final Set<String> selectedFields;
  final void Function(String field, bool selected) onChanged;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: const Color(0xfff7f9fd),
          border: Border.all(color: border),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title,
              style: const TextStyle(color: navy, fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: fields
                .map((field) => FilterChip(
                      label: Text(labels[field] ?? field),
                      selected: selectedFields.contains(field),
                      visualDensity: VisualDensity.compact,
                      onSelected: (value) => onChanged(field, value),
                    ))
                .toList(),
          ),
        ]),
      );
}

class _SelectedFieldSummary extends StatelessWidget {
  const _SelectedFieldSummary({
    required this.count,
    required this.fields,
    required this.labels,
    required this.onRemove,
  });

  final int count;
  final Set<String> fields;
  final Map<String, String> labels;
  final ValueChanged<String> onRemove;

  @override
  Widget build(BuildContext context) {
    final preview = fields.take(6).toList();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('$count फ़ील्ड चुने गए',
          style: const TextStyle(color: muted, fontSize: 12)),
      if (preview.isNotEmpty) ...[
        const SizedBox(height: 6),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: preview
                .map((field) => Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: InputChip(
                        label: Text(labels[field] ?? field),
                        visualDensity: VisualDensity.compact,
                        onDeleted: () => onRemove(field),
                      ),
                    ))
                .toList(),
          ),
        ),
      ],
    ]);
  }
}

class _PrintSetupSummary extends StatelessWidget {
  const _PrintSetupSummary({
    required this.selectedCount,
    required this.fieldCount,
    required this.activeFilterCount,
    required this.layout,
    required this.ready,
  });

  final int selectedCount;
  final int fieldCount;
  final int activeFilterCount;
  final String layout;
  final bool ready;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: ready ? const Color(0xffeaf8f0) : Colors.white,
          border: Border.all(color: ready ? green : border),
          borderRadius: BorderRadius.circular(10),
        ),
        child: LayoutBuilder(builder: (context, constraints) {
          final itemWidth = constraints.maxWidth < 720
              ? (constraints.maxWidth - 8) / 2
              : (constraints.maxWidth - 24) / 4;
          return Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _SummaryPill(
                icon: Icons.groups_rounded,
                label: 'मतदाता',
                value: '$selectedCount चुने',
                color: selectedCount > 0 ? green : orange,
                width: itemWidth,
              ),
              _SummaryPill(
                icon: Icons.filter_alt_rounded,
                label: 'फ़िल्टर',
                value: '$activeFilterCount सक्रिय',
                color: blue,
                width: itemWidth,
              ),
              _SummaryPill(
                icon: Icons.view_list_rounded,
                label: 'फ़ील्ड',
                value: '$fieldCount चुने',
                color: fieldCount > 0 ? green : rose,
                width: itemWidth,
              ),
              _SummaryPill(
                icon: Icons.description_rounded,
                label: 'लेआउट',
                value: layout,
                color: purple,
                width: itemWidth,
              ),
            ],
          );
        }),
      );
}

class _SummaryPill extends StatelessWidget {
  const _SummaryPill({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    required this.width,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final double width;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: width,
        child: Row(children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: color.withValues(alpha: .1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 8),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(label, style: const TextStyle(color: muted, fontSize: 11)),
              Text(value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      color: navy, fontWeight: FontWeight.w900, fontSize: 12)),
            ]),
          ),
        ]),
      );
}

class _QuickSelectPanel extends StatelessWidget {
  const _QuickSelectPanel({
    required this.onMissingMobile,
    required this.onMissingHouse,
    required this.onReview,
    required this.onSupporter,
    required this.onAllFiltered,
  });

  final VoidCallback onMissingMobile;
  final VoidCallback onMissingHouse;
  final VoidCallback onReview;
  final VoidCallback onSupporter;
  final VoidCallback onAllFiltered;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('जल्दी चुनें',
              style: TextStyle(color: navy, fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          LayoutBuilder(builder: (context, constraints) {
            final wide = constraints.maxWidth >= 760;
            final width =
                wide ? (constraints.maxWidth - 16) / 3 : constraints.maxWidth;
            return Wrap(spacing: 8, runSpacing: 8, children: [
              _QuickSelectTile(
                icon: Icons.select_all_rounded,
                title: 'फ़िल्टर के सभी मतदाता',
                subtitle: 'मौजूदा फ़िल्टर से मिले सभी मतदाता चुनें',
                color: blue,
                width: width,
                onTap: onAllFiltered,
              ),
              _QuickSelectTile(
                icon: Icons.phone_disabled_rounded,
                title: 'मोबाइल नहीं है',
                subtitle: 'बिना मोबाइल नंबर वाले मतदाता चुनें',
                color: rose,
                width: width,
                onTap: onMissingMobile,
              ),
              _QuickSelectTile(
                icon: Icons.other_houses_rounded,
                title: 'घर संख्या नहीं है',
                subtitle: 'बिना घर संख्या वाले मतदाता चुनें',
                color: orange,
                width: width,
                onTap: onMissingHouse,
              ),
              _QuickSelectTile(
                icon: Icons.fact_check_rounded,
                title: 'समीक्षा जरूरी',
                subtitle: 'समीक्षा के लिए चिह्नित मतदाता चुनें',
                color: purple,
                width: width,
                onTap: onReview,
              ),
              _QuickSelectTile(
                icon: Icons.groups_rounded,
                title: 'समर्थक',
                subtitle: 'केवल समर्थक मतदाता चुनें',
                color: green,
                width: width,
                onTap: onSupporter,
              ),
            ]);
          }),
        ],
      );
}

class _QuickSelectTile extends StatelessWidget {
  const _QuickSelectTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.width,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final double width;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: width,
        child: Material(
          color: color.withValues(alpha: .06),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: BorderSide(color: color.withValues(alpha: .28)),
          ),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(children: [
                Icon(icon, color: color, size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title,
                            style: const TextStyle(
                                color: navy, fontWeight: FontWeight.w900)),
                        const SizedBox(height: 2),
                        Text(subtitle,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: muted, fontSize: 11)),
                      ]),
                ),
                const Icon(Icons.chevron_right_rounded, color: muted),
              ]),
            ),
          ),
        ),
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
                        child: Text('Database में कोई विकल्प नहीं मिला।',
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
                    Text(selected ? value! : 'Select from database',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            color: selected ? navy : muted,
                            fontSize: 12,
                            fontWeight: FontWeight.w800)),
                  ])),
              if (selected)
                IconButton(
                    tooltip: 'Remove',
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
            '${voter['voterId'] ?? '-'} - House ${voter['houseNumber'] ?? '-'} - ${voter['village'] ?? voter['location'] ?? '-'}',
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
              const Text('Voter list',
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
                                          child: Text('$field: -',
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
