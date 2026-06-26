import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../../core/api_client.dart';
import '../../core/contact_actions.dart';
import '../../core/download_helper.dart';
import '../../core/offline_voter_cache.dart';
import '../../core/print_helper.dart';
import '../../core/theme.dart';
import '../../layout/app_layout.dart';
import '../../widgets/common.dart';
import '../../widgets/mobile_components.dart';
import '../families/family_members.dart';
import '../reports/configurable_print_page.dart';
import 'voter_contact_actions.dart';
import 'voter_edit_page.dart';

class VoterManagementPage extends StatefulWidget {
  const VoterManagementPage(
      {super.key, this.initialAreaId, this.initialAreaName});

  final String? initialAreaId;
  final String? initialAreaName;

  @override
  State<VoterManagementPage> createState() => _VoterManagementPageState();
}

class _VoterManagementPageState extends State<VoterManagementPage> {
  final search = TextEditingController();
  final sectionNumber = TextEditingController();
  final boothNumber = TextEditingController();
  final location = TextEditingController();
  final village = TextEditingController();
  final gramPanchayat = TextEditingController();
  final tehsil = TextEditingController();
  final municipality = TextEditingController();
  final caste = TextEditingController();
  final organizationPost = TextEditingController();
  final sectionName = TextEditingController();
  final assemblyNumber = TextEditingController();
  final speech = SpeechToText();
  final selectedIds = <String>{};
  final selectedOptionFilters = <String, Map<String, String>>{};
  final selectedOptionLabels = <String, String>{};
  bool listening = false;
  bool showAdvancedFilters = false;
  String gender = '';
  String verificationStatus = '';
  String support = '';
  int currentPage = 1;
  static const int pageSize = 100;

  void filtersChanged() => setState(() => currentPage = 1);

  @override
  void dispose() {
    search.dispose();
    sectionNumber.dispose();
    boothNumber.dispose();
    location.dispose();
    village.dispose();
    gramPanchayat.dispose();
    tehsil.dispose();
    municipality.dispose();
    caste.dispose();
    organizationPost.dispose();
    sectionName.dispose();
    assemblyNumber.dispose();
    speech.stop();
    super.dispose();
  }

  Map<String, String?> get filterQuery {
    final query = <String, String?>{
      'q': search.text.trim(),
      'sectionNumber': sectionNumber.text.trim(),
      'sectionName': sectionName.text.trim(),
      'partNumber': boothNumber.text.trim(),
      'assemblyNumber': assemblyNumber.text.trim(),
      'location': location.text.trim(),
      'village': village.text.trim(),
      'gramPanchayat': gramPanchayat.text.trim(),
      'tehsil': tehsil.text.trim(),
      'municipality': municipality.text.trim(),
      'caste': caste.text.trim(),
      'organizationPost': organizationPost.text.trim(),
      'supportLevel': support,
      'gender': gender,
      'verificationStatus': verificationStatus,
      'area': widget.initialAreaId,
    };
    for (final values in selectedOptionFilters.values) {
      query.addAll(values);
    }
    return query;
  }

  Future<void> toggleVoiceSearch() async {
    if (listening) {
      await speech.stop();
      if (mounted) setState(() => listening = false);
      return;
    }
    final available = await speech.initialize(
      onStatus: (status) {
        if (mounted && (status == 'done' || status == 'notListening')) {
          setState(() => listening = false);
        }
      },
      onError: (_) {
        if (mounted) setState(() => listening = false);
      },
    );
    if (!available) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('इस डिवाइस पर voice search उपलब्ध नहीं है।')),
      );
      return;
    }
    setState(() => listening = true);
    await speech.listen(
      listenOptions: SpeechListenOptions(
        localeId: 'hi_IN',
        listenMode: ListenMode.search,
        partialResults: true,
      ),
      onResult: (result) {
        search.text = result.recognizedWords;
        search.selection = TextSelection.collapsed(offset: search.text.length);
        filtersChanged();
      },
    );
  }

  void clearFilters() {
    for (final controller in [
      search,
      sectionNumber,
      sectionName,
      boothNumber,
      assemblyNumber,
      location,
      village,
      gramPanchayat,
      tehsil,
      municipality,
      caste,
      organizationPost,
    ]) {
      controller.clear();
    }
    setState(() {
      support = '';
      gender = '';
      verificationStatus = '';
      currentPage = 1;
      selectedIds.clear();
      selectedOptionFilters.clear();
      selectedOptionLabels.clear();
    });
  }

  static const smartFieldKeys = <String, List<String>>{
    'assembly': ['assemblyNumber', 'assemblyName'],
    'village': ['village'],
    'gramPanchayat': ['gramPanchayat'],
    'tehsil': ['tehsil'],
    'municipality': ['municipality'],
    'partNumber': ['partNumber'],
    'section': ['sectionNumber', 'sectionName'],
    'caste': ['caste'],
    'organizationPost': ['organizationPost'],
  };

  Future<void> openSmartFilter(String field, String title) async {
    final current = Map<String, String?>.from(filterQuery);
    for (final key in smartFieldKeys[field] ?? const <String>[]) {
      current.remove(key);
    }
    for (final key in selectedOptionFilters[field]?.keys ?? const <String>[]) {
      current.remove(key);
    }
    final option = await showDialog<_FilterOption>(
      context: context,
      builder: (_) => _FilterOptionDialog(
        field: field,
        title: title,
        currentFilters: current,
      ),
    );
    if (option == null || !mounted) return;
    setState(() {
      selectedOptionFilters[field] = option.filters;
      selectedOptionLabels[field] = option.label;
      currentPage = 1;
      selectedIds.clear();
    });
  }

  void clearSmartFilter(String field) => setState(() {
        selectedOptionFilters.remove(field);
        selectedOptionLabels.remove(field);
        currentPage = 1;
        selectedIds.clear();
      });
  Future<void> openCustomPrint() async {
    final options = await showDialog<_PrintOptions>(
      context: context,
      builder: (_) => _PrintOptionsDialog(selectedCount: selectedIds.length),
    );
    if (options == null || !mounted) return;
    await printApiPdf(
      context,
      path: '/api/print/members.pdf',
      jobName: selectedIds.isEmpty ? 'फ़िल्टर किए मतदाता' : 'चयनित मतदाता',
      query: {
        ...filterQuery,
        if (selectedIds.isNotEmpty) 'ids': selectedIds.join(','),
        'fields': options.fields.join(','),
        'columns': '${options.columns}',
        'photo': '${options.photo}',
        'paperSize': options.paperSize,
        'orientation': options.orientation,
      },
    );
  }

  Future<void> deleteAll() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.warning_amber_rounded,
            color: Colors.red, size: 42),
        title: const Text('सभी मतदाता हटा दें?'),
        content: const Text(
          'यह सभी मतदाताओं और संबंधित परिवारों को स्थायी रूप से हटा देगा। '
          'इस कार्रवाई को वापस नहीं किया जा सकता।',
          textAlign: TextAlign.center,
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('रद्द करें')),
          FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            icon: const Icon(Icons.delete_forever),
            label: const Text('हाँ, सभी हटाएं'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      final result = await api.deleteWithBody(
        '/api/members',
        {'confirmation': 'DELETE ALL VOTERS'},
      );
      if (!mounted) return;
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(
            '${result['deletedMembers'] ?? 0} मतदाता और ${result['deletedFamilies'] ?? 0} परिवार हटा दिए गए'),
      ));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('$error')));
    }
  }

  @override
  Widget build(BuildContext context) => AppPage(children: [
        PageHeading(
          title: 'मतदाता प्रबंधन',
          subtitle: 'नाम, EPIC, मोबाइल, गाँव या घर संख्या से तेजी से खोजें',
          action: Builder(builder: (context) {
            final compact = MediaQuery.sizeOf(context).width < 520;
            return Wrap(spacing: 8, runSpacing: 8, children: [
              OutlinedButton.icon(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const ConfigurablePrintPage()),
                ),
                icon: const Icon(Icons.print_rounded),
                label: Text(compact ? 'Bulk Print' : 'Smart Bulk Print'),
              ),
              FilledButton.icon(
                onPressed: () => showDialog(
                    context: context,
                    builder: (_) => VoterForm(onSaved: () => setState(() {}))),
                icon: const Icon(Icons.add),
                label: Text(compact ? 'नया मतदाता' : 'नया मतदाता जोड़ें'),
              ),
            ]);
          }),
        ),
        LayoutBuilder(builder: (context, constraints) {
          final compact = constraints.maxWidth < 620;
          final searchBox = TextField(
            controller: search,
            onChanged: (_) => filtersChanged(),
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search_rounded),
              hintText: compact
                  ? 'नाम, मोबाइल, EPIC...'
                  : 'नाम, मोबाइल, EPIC, घर, गाँव, पंचायत या पता खोजें...',
              suffixIcon: IconButton(
                tooltip: listening ? 'सुनना बंद करें' : 'बोलकर खोजें',
                onPressed: toggleVoiceSearch,
                icon: Icon(
                  listening ? Icons.mic_rounded : Icons.mic_none_rounded,
                  color: listening ? Colors.red : blue,
                ),
              ),
            ),
          );
          final filterButton = OutlinedButton.icon(
            onPressed: () =>
                setState(() => showAdvancedFilters = !showAdvancedFilters),
            icon: Icon(
              showAdvancedFilters
                  ? Icons.filter_alt_rounded
                  : Icons.tune_rounded,
              color: blue,
            ),
            label:
                Text(showAdvancedFilters ? 'फ़िल्टर छिपाएँ' : 'एडवांस फ़िल्टर'),
          );
          if (compact) {
            return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  searchBox,
                  const SizedBox(height: 10),
                  filterButton,
                ]);
          }
          return Row(children: [
            Expanded(child: searchBox),
            const SizedBox(width: 10),
            filterButton,
          ]);
        }),
        if (listening)
          const Padding(
            padding: EdgeInsets.only(top: 6),
            child: Text('सुन रहा हूँ… नाम, मोबाइल, EPIC या गाँव बोलें',
                style:
                    TextStyle(color: Colors.red, fontWeight: FontWeight.w700)),
          ),
        _SmartSearchPanel(
          selectedLabels: selectedOptionLabels,
          onPick: openSmartFilter,
          onClear: clearSmartFilter,
          onClearAll: selectedOptionLabels.isEmpty
              ? null
              : () => setState(() {
                    selectedOptionFilters.clear();
                    selectedOptionLabels.clear();
                    currentPage = 1;
                    selectedIds.clear();
                  }),
        ),
        if (showAdvancedFilters) ...[
          const SizedBox(height: 10),
          SectionCard(
            title: 'एडवांस खोज',
            action: TextButton.icon(
              onPressed: clearFilters,
              icon: const Icon(Icons.clear_all),
              label: const Text('सभी साफ करें'),
            ),
            child: Wrap(spacing: 10, runSpacing: 10, children: [
              _SearchFilter(
                  controller: assemblyNumber,
                  label: 'विधानसभा संख्या',
                  icon: Icons.account_balance_outlined,
                  onChanged: (_) => filtersChanged()),
              _SearchFilter(
                  controller: boothNumber,
                  label: 'भाग / बूथ संख्या',
                  icon: Icons.how_to_vote_outlined,
                  onChanged: (_) => filtersChanged()),
              _SearchFilter(
                  controller: sectionNumber,
                  label: 'अनुभाग संख्या',
                  icon: Icons.format_list_numbered,
                  onChanged: (_) => filtersChanged()),
              _SearchFilter(
                  controller: sectionName,
                  label: 'अनुभाग नाम',
                  icon: Icons.segment,
                  onChanged: (_) => filtersChanged()),
              _SearchFilter(
                  controller: village,
                  label: 'गाँव',
                  icon: Icons.home_work_outlined,
                  onChanged: (_) => filtersChanged()),
              _SearchFilter(
                  controller: gramPanchayat,
                  label: 'ग्राम पंचायत',
                  icon: Icons.holiday_village_outlined,
                  onChanged: (_) => filtersChanged()),
              _SearchFilter(
                  controller: tehsil,
                  label: 'तहसील',
                  icon: Icons.location_city_outlined,
                  onChanged: (_) => filtersChanged()),
              _SearchFilter(
                  controller: municipality,
                  label: 'नगर पालिका',
                  icon: Icons.apartment_outlined,
                  onChanged: (_) => filtersChanged()),
              _SearchFilter(
                  controller: location,
                  label: 'पता / स्थान',
                  icon: Icons.location_on_outlined,
                  onChanged: (_) => filtersChanged()),
              _SearchFilter(
                  controller: caste,
                  label: 'जाति',
                  icon: Icons.groups_2_outlined,
                  onChanged: (_) => filtersChanged()),
              _SearchFilter(
                  controller: organizationPost,
                  label: 'राजनीतिक पद',
                  icon: Icons.badge_outlined,
                  onChanged: (_) => filtersChanged()),
              _FilterDropdown(
                label: 'समर्थन स्तर',
                value: support,
                items: const {
                  '': 'सभी',
                  'supporter': 'समर्थक',
                  'neutral': 'तटस्थ',
                  'opposite': 'विरोधी',
                  'undecided': 'अनिर्णीत',
                },
                onChanged: (value) => setState(() {
                  support = value;
                  currentPage = 1;
                }),
              ),
              _FilterDropdown(
                label: 'लिंग',
                value: gender,
                items: const {
                  '': 'सभी',
                  'male': 'पुरुष',
                  'female': 'महिला',
                  'other': 'अन्य',
                },
                onChanged: (value) => setState(() {
                  gender = value;
                  currentPage = 1;
                }),
              ),
              _FilterDropdown(
                label: 'सत्यापन',
                value: verificationStatus,
                items: const {
                  '': 'सभी',
                  'pending': 'लंबित',
                  'verified': 'सत्यापित',
                  'needs_review': 'Review आवश्यक',
                  'duplicate': 'डुप्लीकेट',
                },
                onChanged: (value) => setState(() {
                  verificationStatus = value;
                  currentPage = 1;
                }),
              ),
            ]),
          ),
        ],
        FutureBlock<Map<String, dynamic>>(
          load: () => api.get('/api/reports/dashboard'),
          builder: (d) => LayoutBuilder(builder: (context, constraints) {
            final columns = constraints.maxWidth >= 720
                ? 3
                : constraints.maxWidth >= 360
                    ? 2
                    : 1;
            final width = (constraints.maxWidth - (columns - 1) * 10) / columns;
            final items = [
              MetricCard(
                  label: 'कुल मतदाता',
                  value: '${d['members'] ?? 0}',
                  icon: Icons.groups,
                  color: blue),
              MetricCard(
                  label: 'समर्थक मतदाता',
                  value: '${_supportCount(d, 'supporter')}',
                  icon: Icons.group,
                  color: green),
              MetricCard(
                  label: 'विरोधी मतदाता',
                  value: '${_supportCount(d, 'opposite')}',
                  icon: Icons.local_florist,
                  color: orange),
            ];
            return Wrap(
              spacing: 10,
              runSpacing: 10,
              children: items
                  .map((card) => SizedBox(width: width, child: card))
                  .toList(),
            );
          }),
        ),
        FutureBlock<VoterPageResult>(
          load: () => OfflineVoterCache.loadPage(
            query: filterQuery,
            page: currentPage,
            limit: pageSize,
          ),
          builder: (result) => VoterTable(
            items:
                result.items.map((e) => Map<String, dynamic>.from(e)).toList(),
            refresh: () => setState(() {}),
            onDeleteAll: deleteAll,
            total: result.total,
            page: result.page,
            pages: result.pages,
            onPageChanged: (page) => setState(() => currentPage = page),
            pageSize: result.limit,
            selectedIds: selectedIds,
            onSelectionChanged: (id, selected) => setState(() {
              if (selected) {
                selectedIds.add(id);
              } else {
                selectedIds.remove(id);
              }
            }),
            onSelectPage: (ids, selected) => setState(() {
              if (selected) {
                selectedIds.addAll(ids);
              } else {
                selectedIds.removeAll(ids);
              }
            }),
          ),
        ),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
              color: const Color(0xfff2f6ff),
              borderRadius: BorderRadius.circular(10)),
          child: Wrap(spacing: 8, runSpacing: 8, children: [
            if (selectedIds.isNotEmpty)
              Chip(
                avatar: const Icon(Icons.check_circle, color: green, size: 18),
                label: Text('${selectedIds.length} मतदाता चयनित'),
                onDeleted: () => setState(selectedIds.clear),
              ),
            OutlinedButton.icon(
                onPressed: () => saveApiFile(context,
                        path: '/api/export/members.xlsx',
                        fallbackName: 'voters.xlsx',
                        query: {
                          ...filterQuery,
                          if (selectedIds.isNotEmpty)
                            'ids': selectedIds.join(','),
                        }),
                icon: const Icon(Icons.table_view, color: green),
                label: Text(
                    selectedIds.isEmpty ? 'फ़िल्टर Excel' : 'चयनित Excel')),
            FilledButton.icon(
                onPressed: openCustomPrint,
                icon: const Icon(Icons.print),
                label: Text(selectedIds.isEmpty
                    ? 'कस्टम Bulk Print'
                    : 'चयनित (${selectedIds.length}) Print')),
          ]),
        )
      ]);
}

class _SmartSearchPanel extends StatelessWidget {
  const _SmartSearchPanel({
    required this.selectedLabels,
    required this.onPick,
    required this.onClear,
    required this.onClearAll,
  });

  final Map<String, String> selectedLabels;
  final void Function(String field, String title) onPick;
  final ValueChanged<String> onClear;
  final VoidCallback? onClearAll;

  static const fields = <_SmartFilterDef>[
    _SmartFilterDef('assembly', 'विधानसभा', Icons.account_balance_rounded),
    _SmartFilterDef('village', 'गाँव', Icons.location_city_rounded),
    _SmartFilterDef(
        'gramPanchayat', 'ग्राम पंचायत', Icons.holiday_village_rounded),
    _SmartFilterDef('tehsil', 'तहसील', Icons.apartment_rounded),
    _SmartFilterDef('municipality', 'नगर पालिका', Icons.location_city_outlined),
    _SmartFilterDef('partNumber', 'भाग / बूथ', Icons.how_to_vote_rounded),
    _SmartFilterDef('section', 'अनुभाग', Icons.format_list_numbered_rounded),
    _SmartFilterDef('caste', 'जाति', Icons.groups_2_rounded),
    _SmartFilterDef('organizationPost', 'संगठन पद', Icons.badge_rounded),
  ];

  @override
  Widget build(BuildContext context) => SectionCard(
        title: 'स्मार्ट खोज',
        subtitle:
            'Database में मौजूद option चुनें या नीचे Advanced Filter में type करके खोजें',
        icon: Icons.manage_search_rounded,
        action: onClearAll == null
            ? null
            : TextButton.icon(
                onPressed: onClearAll,
                icon: const Icon(Icons.clear_all_rounded),
                label: const Text('सभी साफ करें'),
              ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Wrap(
            spacing: 9,
            runSpacing: 9,
            children: fields
                .map((field) => _DatabaseFilterPicker(
                      label: field.label,
                      icon: field.icon,
                      value: selectedLabels[field.field],
                      onTap: () => onPick(field.field, field.label),
                      onClear: () => onClear(field.field),
                    ))
                .toList(),
          ),
          if (selectedLabels.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 7,
              runSpacing: 7,
              children: selectedLabels.entries
                  .map((entry) => InputChip(
                        avatar: const Icon(Icons.check_circle_rounded,
                            color: green, size: 18),
                        label: Text(entry.value),
                        onDeleted: () => onClear(entry.key),
                      ))
                  .toList(),
            ),
          ],
          const SizedBox(height: 10),
          const Text(
            'Tip: गाँव/पंचायत/भाग select करते ही उसी से जुड़े सभी voter list में दिखेंगे।',
            style: TextStyle(color: muted, fontSize: 12),
          ),
        ]),
      );
}

class _SmartFilterDef {
  const _SmartFilterDef(this.field, this.label, this.icon);
  final String field;
  final String label;
  final IconData icon;
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
      width: MediaQuery.sizeOf(context).width < 420 ? double.infinity : 205,
      child: Material(
        color: selected ? const Color(0xffedf4ff) : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(13),
          side: BorderSide(color: selected ? blue : border),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(13),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 6, 10),
            child: Row(children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: selected ? blue.withValues(alpha: .11) : softBlue,
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(icon, color: selected ? blue : muted, size: 19),
              ),
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
                              fontWeight: FontWeight.w900)),
                    ]),
              ),
              if (selected)
                IconButton(
                  tooltip: 'हटाएँ',
                  visualDensity: VisualDensity.compact,
                  onPressed: onClear,
                  icon: const Icon(Icons.close_rounded, size: 18),
                )
              else
                const Icon(Icons.arrow_drop_down_rounded, color: muted),
            ]),
          ),
        ),
      ),
    );
  }
}

class _FilterOption {
  const _FilterOption({
    required this.label,
    required this.count,
    required this.filters,
  });

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
        contentPadding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        title: Row(children: [
          Expanded(
            child: Text('${widget.title} चुनें',
                style:
                    const TextStyle(color: navy, fontWeight: FontWeight.w900)),
          ),
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.close_rounded),
          ),
        ]),
        content: SizedBox(
          width: 540,
          height: MediaQuery.sizeOf(context).height * .72,
          child: Column(children: [
            TextField(
              controller: search,
              autofocus: true,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search_rounded),
                hintText: '${widget.title} search करें...',
                suffixIcon: search.text.isEmpty
                    ? null
                    : IconButton(
                        onPressed: () {
                          search.clear();
                          setState(() {});
                        },
                        icon: const Icon(Icons.close_rounded),
                      ),
              ),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: FutureBuilder<Map<String, dynamic>>(
                future: api.getQuery('/api/members/filter-options', {
                  ...widget.currentFilters,
                  'field': widget.field,
                  'q': search.text.trim(),
                  'limit': '160',
                }),
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return Center(
                      child: Text('${snapshot.error}',
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.red)),
                    );
                  }
                  final options = List<Map<String, dynamic>>.from(
                    (snapshot.data?['items'] as List? ?? [])
                        .map((item) => Map<String, dynamic>.from(item)),
                  ).map(_FilterOption.fromMap).toList();
                  if (options.isEmpty) {
                    return const EmptyIllustration(
                      icon: Icons.search_off_rounded,
                      title: 'Matching option नहीं मिला',
                      subtitle:
                          'थोड़ा अलग शब्द type करें या manual filter use करें',
                    );
                  }
                  return ListView.separated(
                    itemCount: options.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (_, index) {
                      final option = options[index];
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: softBlue,
                          child: Text('${index + 1}',
                              style: const TextStyle(
                                  color: blue,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w900)),
                        ),
                        title: Text(option.label,
                            style: const TextStyle(
                                color: navy, fontWeight: FontWeight.w900)),
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

class _SearchFilter extends StatelessWidget {
  const _SearchFilter(
      {required this.controller,
      required this.label,
      required this.icon,
      required this.onChanged});
  final TextEditingController controller;
  final String label;
  final IconData icon;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 180,
        child: TextField(
          controller: controller,
          onChanged: onChanged,
          decoration: InputDecoration(
            labelText: label,
            prefixIcon: Icon(icon, size: 20),
            suffixIcon: controller.text.isEmpty
                ? null
                : IconButton(
                    tooltip: 'देखें',
                    onPressed: () {
                      controller.clear();
                      onChanged('');
                    },
                    icon: const Icon(Icons.close, size: 18),
                  ),
          ),
        ),
      );
}

class _FilterDropdown extends StatelessWidget {
  const _FilterDropdown({
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
  });

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
          onChanged: (next) => onChanged(next ?? ''),
        ),
      );
}

class _PrintOptions {
  const _PrintOptions({
    required this.fields,
    required this.columns,
    required this.photo,
    required this.paperSize,
    required this.orientation,
  });

  final Set<String> fields;
  final int columns;
  final bool photo;
  final String paperSize;
  final String orientation;
}

class _PrintOptionsDialog extends StatefulWidget {
  const _PrintOptionsDialog({required this.selectedCount});
  final int selectedCount;

  @override
  State<_PrintOptionsDialog> createState() => _PrintOptionsDialogState();
}

class _PrintOptionsDialogState extends State<_PrintOptionsDialog> {
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
    'address': 'पता',
    'village': 'गाँव',
    'gramPanchayat': 'ग्राम पंचायत',
    'tehsil': 'तहसील',
    'municipality': 'नगर पालिका',
    'caste': 'जाति',
    'subCaste': 'उपजाति',
    'occupation': 'व्यवसाय',
    'education': 'शिक्षा',
    'organizationPost': 'राजनीतिक पद',
    'supportLevel': 'समर्थन स्तर',
    'assembly': 'विधानसभा',
    'partNumber': 'भाग संख्या',
    'section': 'अनुभाग',
    'booth': 'बूथ',
    'ward': 'वार्ड',
  };

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
  int columns = 2;
  bool photo = true;
  String paperSize = 'A4';
  String orientation = 'portrait';

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: Text(widget.selectedCount > 0
            ? '${widget.selectedCount} चयनित मतदाता प्रिंट करें'
            : 'फ़िल्टर किए मतदाता Bulk Print'),
        content: SizedBox(
          width: 650,
          child: SingleChildScrollView(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('प्रिंट में दिखाई देने वाली जानकारी चुनें',
                  style: TextStyle(fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: availableFields.entries
                    .map((entry) => FilterChip(
                          label: Text(entry.value),
                          selected: selectedFields.contains(entry.key),
                          onSelected: (selected) => setState(() {
                            if (selected) {
                              selectedFields.add(entry.key);
                            } else {
                              selectedFields.remove(entry.key);
                            }
                          }),
                        ))
                    .toList(),
              ),
              const Divider(height: 28),
              Wrap(spacing: 12, runSpacing: 12, children: [
                SizedBox(
                  width: 150,
                  child: DropdownButtonFormField<int>(
                    initialValue: columns,
                    decoration:
                        const InputDecoration(labelText: 'प्रति पंक्ति कार्ड'),
                    items: const [
                      DropdownMenuItem(value: 1, child: Text('1 कार्ड')),
                      DropdownMenuItem(value: 2, child: Text('2 कार्ड')),
                      DropdownMenuItem(value: 3, child: Text('3 कार्ड')),
                    ],
                    onChanged: (value) => setState(() => columns = value ?? 2),
                  ),
                ),
                SizedBox(
                  width: 140,
                  child: DropdownButtonFormField<String>(
                    initialValue: paperSize,
                    decoration: const InputDecoration(labelText: 'पेपर'),
                    items: const [
                      DropdownMenuItem(value: 'A4', child: Text('A4')),
                      DropdownMenuItem(value: 'A3', child: Text('A3')),
                      DropdownMenuItem(value: 'LETTER', child: Text('Letter')),
                    ],
                    onChanged: (value) =>
                        setState(() => paperSize = value ?? 'A4'),
                  ),
                ),
                SizedBox(
                  width: 160,
                  child: DropdownButtonFormField<String>(
                    initialValue: orientation,
                    decoration: const InputDecoration(labelText: 'दिशा'),
                    items: const [
                      DropdownMenuItem(
                          value: 'portrait', child: Text('Portrait')),
                      DropdownMenuItem(
                          value: 'landscape', child: Text('Landscape')),
                    ],
                    onChanged: (value) =>
                        setState(() => orientation = value ?? 'portrait'),
                  ),
                ),
                FilterChip(
                  avatar: const Icon(Icons.photo_outlined, size: 18),
                  label: const Text('फोटो'),
                  selected: photo,
                  onSelected: (value) => setState(() => photo = value),
                ),
              ]),
            ]),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('रद्द करें')),
          FilledButton.icon(
            onPressed: selectedFields.isEmpty
                ? null
                : () => Navigator.pop(
                      context,
                      _PrintOptions(
                        fields: Set.of(selectedFields),
                        columns: columns,
                        photo: photo,
                        paperSize: paperSize,
                        orientation: orientation,
                      ),
                    ),
            icon: const Icon(Icons.print),
            label: const Text('प्रिंट करें'),
          ),
        ],
      );
}

class VoterTable extends StatelessWidget {
  const VoterTable({
    super.key,
    required this.items,
    required this.refresh,
    required this.onDeleteAll,
    required this.total,
    required this.page,
    required this.pages,
    required this.pageSize,
    required this.onPageChanged,
    required this.selectedIds,
    required this.onSelectionChanged,
    required this.onSelectPage,
  });

  final List<Map<String, dynamic>> items;
  final VoidCallback refresh;
  final VoidCallback onDeleteAll;
  final int total;
  final int page;
  final int pages;
  final int pageSize;
  final ValueChanged<int> onPageChanged;
  final Set<String> selectedIds;
  final void Function(String id, bool selected) onSelectionChanged;
  final void Function(Iterable<String> ids, bool selected) onSelectPage;

  @override
  Widget build(BuildContext context) {
    final mobile = MediaQuery.sizeOf(context).width < 700;
    final start = total == 0 ? 0 : ((page - 1) * pageSize) + 1;
    final end = ((page - 1) * pageSize) + items.length;
    final pageIds = items.map((item) => '${item['_id']}').toList();
    final allPageSelected =
        pageIds.isNotEmpty && pageIds.every(selectedIds.contains);
    return SectionCard(
      title: 'मतदाता सूची ($start-$end / $total)',
      subtitle: selectedIds.isEmpty
          ? 'रिकॉर्ड खोलने के लिए card पर tap करें'
          : '${selectedIds.length} मतदाता चयनित',
      icon: Icons.groups_rounded,
      action: Wrap(spacing: 8, runSpacing: 8, children: [
        OutlinedButton.icon(
          onPressed: pageIds.isEmpty
              ? null
              : () => onSelectPage(pageIds, !allPageSelected),
          icon: const Icon(Icons.library_add_check_outlined),
          label: Text(
              allPageSelected ? 'इस पेज का चयन हटाएँ' : 'इस पेज के सभी चुनें'),
        ),
        if (api.user?['role'] == 'admin')
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
                foregroundColor: Colors.red,
                side: const BorderSide(color: Colors.red)),
            onPressed: onDeleteAll,
            icon: const Icon(Icons.delete_forever),
            label: const Text('सभी मतदाता हटाएं'),
          ),
      ]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (mobile)
          items.isEmpty
              ? const EmptyIllustration(
                  icon: Icons.search_off_rounded,
                  title: 'कोई मतदाता नहीं मिला',
                  subtitle: 'Search या filters बदलकर फिर कोशिश करें',
                )
              : Column(
                  children: items
                      .asMap()
                      .entries
                      .map((entry) => _VoterRow(
                            index: ((page - 1) * pageSize) + entry.key,
                            member: entry.value,
                            selected:
                                selectedIds.contains('${entry.value['_id']}'),
                            onSelected: (selected) => onSelectionChanged(
                                '${entry.value['_id']}', selected),
                            refresh: refresh,
                          ))
                      .toList())
        else
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
                columns: const [
                  DataColumn(label: Text('फोटो')),
                  DataColumn(label: Text('नाम')),
                  DataColumn(label: Text('पिता / पति')),
                  DataColumn(label: Text('मोबाइल')),
                  DataColumn(label: Text('वोटर आईडी')),
                  DataColumn(label: Text('घर नं.')),
                  DataColumn(label: Text('गाँव')),
                  DataColumn(label: Text('समर्थन स्तर')),
                  DataColumn(label: Text('कार्रवाई')),
                ],
                rows: items
                    .map((m) => DataRow(
                          selected: selectedIds.contains('${m['_id']}'),
                          onSelectChanged: (selected) => onSelectionChanged(
                              '${m['_id']}', selected ?? false),
                          cells: [
                            DataCell(
                                _VoterPhoto(photo: m['photo'], radius: 20)),
                            DataCell(Text(m['name'] ?? '-')),
                            DataCell(Text(m['guardianName'] ?? '-')),
                            DataCell(
                                Row(mainAxisSize: MainAxisSize.min, children: [
                              Text('${m['mobile'] ?? '-'}'),
                              IconButton(
                                tooltip: 'कॉल करें',
                                onPressed: () =>
                                    callNumber(context, '${m['mobile'] ?? ''}'),
                                icon:
                                    const Icon(Icons.call, color: Colors.green),
                              ),
                            ])),
                            DataCell(Text('${m['voterId'] ?? '-'}')),
                            DataCell(Text('${m['houseNumber'] ?? '-'}')),
                            DataCell(Text('${m['village'] ?? '-'}')),
                            DataCell(Chip(
                                label: Text(
                                    '${m['supportLevel'] ?? 'undecided'}'))),
                            DataCell(Row(children: [
                              IconButton(
                                  tooltip: 'देखें',
                                  onPressed: () => Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                          builder: (_) => VoterDetailPage(
                                              voter: m, onChanged: refresh))),
                                  icon: const Icon(Icons.visibility,
                                      color: blue)),
                              IconButton(
                                  tooltip: 'संपादित करें',
                                  onPressed: () => Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                          builder: (_) => VoterEditPage(
                                              voter: m, onSaved: refresh))),
                                  icon: const Icon(Icons.edit, color: blue)),
                              IconButton(
                                  tooltip: 'हटाएं',
                                  onPressed: () async {
                                    await api
                                        .delete('/api/members/${m['_id']}');
                                    refresh();
                                  },
                                  icon: const Icon(Icons.delete_outline,
                                      color: Colors.red)),
                            ])),
                          ],
                        ))
                    .toList()),
          ),
        const SizedBox(height: 12),
        _PaginationBar(page: page, pages: pages, onChanged: onPageChanged),
      ]),
    );
  }
}

class _PaginationBar extends StatelessWidget {
  const _PaginationBar({
    required this.page,
    required this.pages,
    required this.onChanged,
  });

  final int page;
  final int pages;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    if (pages <= 1) return const SizedBox.shrink();
    final numbers = <int>{1, pages};
    for (var i = page - 2; i <= page + 2; i++) {
      if (i >= 1 && i <= pages) numbers.add(i);
    }
    final sorted = numbers.toList()..sort();

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(children: [
        IconButton.outlined(
          tooltip: 'पिछला पृष्ठ',
          onPressed: page <= 1 ? null : () => onChanged(page - 1),
          icon: const Icon(Icons.chevron_left),
        ),
        const SizedBox(width: 6),
        for (var i = 0; i < sorted.length; i++) ...[
          if (i > 0 && sorted[i] - sorted[i - 1] > 1)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 6),
              child: Text('...', style: TextStyle(color: muted)),
            ),
          Padding(
            padding: const EdgeInsets.only(right: 6),
            child: SizedBox(
              width: 42,
              height: 38,
              child: sorted[i] == page
                  ? FilledButton(
                      onPressed: null,
                      style: FilledButton.styleFrom(
                        disabledBackgroundColor: blue,
                        disabledForegroundColor: Colors.white,
                      ),
                      child: Text('${sorted[i]}'),
                    )
                  : OutlinedButton(
                      onPressed: () => onChanged(sorted[i]),
                      child: Text('${sorted[i]}'),
                    ),
            ),
          ),
        ],
        IconButton.outlined(
          tooltip: 'अगला पृष्ठ',
          onPressed: page >= pages ? null : () => onChanged(page + 1),
          icon: const Icon(Icons.chevron_right),
        ),
      ]),
    );
  }
}

class _VoterRow extends StatelessWidget {
  const _VoterRow({
    required this.index,
    required this.member,
    required this.selected,
    required this.onSelected,
    required this.refresh,
  });
  final int index;
  final Map<String, dynamic> member;
  final bool selected;
  final ValueChanged<bool> onSelected;
  final VoidCallback refresh;

  @override
  Widget build(BuildContext context) {
    final name = '${member['name'] ?? '-'}';
    final epic = '${member['voterId'] ?? '-'}';
    final mobile = '${member['mobile'] ?? ''}'.trim();
    final house = '${member['houseNumber'] ?? '-'}';
    final place = [
      '${member['village'] ?? ''}'.trim(),
      '${member['gramPanchayat'] ?? ''}'.trim(),
    ].where((v) => v.isNotEmpty && v != '-').join(' · ');

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: selected ? const Color(0xfff0f6ff) : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(
              color: selected ? blue.withValues(alpha: .45) : border),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) =>
                  VoterDetailPage(voter: member, onChanged: refresh),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Checkbox(
                  value: selected,
                  onChanged: (value) => onSelected(value ?? false),
                  visualDensity: VisualDensity.compact,
                ),
                _VoterPhoto(photo: member['photo'], radius: 24),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 7, vertical: 3),
                            decoration: BoxDecoration(
                              color: softBlue,
                              borderRadius: BorderRadius.circular(9),
                            ),
                            child: Text('#${index + 1}',
                                style: const TextStyle(
                                    color: blue,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w900)),
                          ),
                          const SizedBox(width: 7),
                          Expanded(
                            child: Text(name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    color: navy,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w900)),
                          ),
                        ]),
                        const SizedBox(height: 5),
                        Text('EPIC: $epic',
                            style: const TextStyle(
                                color: muted,
                                fontSize: 11,
                                fontWeight: FontWeight.w700)),
                        const SizedBox(height: 6),
                        Wrap(spacing: 6, runSpacing: 6, children: [
                          _InfoPill(Icons.home_rounded, 'घर $house'),
                          if (place.isNotEmpty)
                            _InfoPill(Icons.location_on_rounded, place),
                        ]),
                      ]),
                ),
                PopupMenuButton<String>(
                  onSelected: (action) async {
                    if (action == 'view') {
                      Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => VoterDetailPage(
                                  voter: member, onChanged: refresh)));
                    } else if (action == 'edit') {
                      Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => VoterEditPage(
                                  voter: member, onSaved: refresh)));
                    } else if (action == 'delete') {
                      await api.delete('/api/members/${member['_id']}');
                      refresh();
                    }
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'view', child: Text('देखें')),
                    PopupMenuItem(value: 'edit', child: Text('संपादित करें')),
                    PopupMenuItem(value: 'delete', child: Text('हटाएं')),
                  ],
                ),
              ]),
              const SizedBox(height: 10),
              Row(children: [
                SupportChip(value: '${member['supportLevel'] ?? 'undecided'}'),
                const Spacer(),
                IconButton.filledTonal(
                  tooltip: 'कॉल करें',
                  onPressed:
                      mobile.isEmpty ? null : () => callNumber(context, mobile),
                  icon: const Icon(Icons.call_rounded, color: green, size: 19),
                ),
                const SizedBox(width: 6),
                IconButton.filledTonal(
                  tooltip: 'संपादित करें',
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          VoterEditPage(voter: member, onSaved: refresh),
                    ),
                  ),
                  icon: const Icon(Icons.edit_rounded, color: blue, size: 19),
                ),
              ]),
            ]),
          ),
        ),
      ),
    );
  }
}

class _InfoPill extends StatelessWidget {
  const _InfoPill(this.icon, this.text);
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          color: const Color(0xfff6f8fc),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: border),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, color: muted, size: 13),
          const SizedBox(width: 4),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 160),
            child: Text(text,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    color: muted, fontSize: 11, fontWeight: FontWeight.w700)),
          ),
        ]),
      );
}

class _VoterPhoto extends StatelessWidget {
  const _VoterPhoto({required this.photo, required this.radius});
  final dynamic photo;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final path = '${photo ?? ''}'.trim();
    final url = path.startsWith('http') ? path : '${api.baseUrl}$path';
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: radius * 2,
        height: radius * 2,
        color: const Color(0xffeef3ff),
        child: path.isEmpty
            ? const Icon(Icons.person, color: muted)
            : Image.network(
                url,
                fit: BoxFit.contain,
                alignment: Alignment.center,
                errorBuilder: (_, __, ___) =>
                    const Icon(Icons.person, color: muted),
              ),
      ),
    );
  }
}

class VoterDetailPage extends StatelessWidget {
  const VoterDetailPage(
      {super.key, required this.voter, required this.onChanged});
  final Map<String, dynamic> voter;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          backgroundColor: royalBlue,
          foregroundColor: Colors.white,
          title: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('मतदाता विवरण पृष्ठ',
                    style:
                        TextStyle(fontSize: 19, fontWeight: FontWeight.w900)),
                Text('मतदाता की विस्तृत जानकारी',
                    style: TextStyle(fontSize: 11)),
              ]),
          actions: [
            IconButton(
                onPressed: () => printApiPdf(context,
                    path: '/api/export/members/${voter['_id']}.pdf',
                    jobName: 'मतदाता प्रोफाइल'),
                icon: const Icon(Icons.print)),
          ],
        ),
        body: AppPage(children: [
          SectionCard(
            title: '${voter['name'] ?? '-'}',
            child: Row(children: [
              CircleAvatar(
                  radius: 58,
                  backgroundImage: voter['photo'] != null
                      ? NetworkImage('${api.baseUrl}${voter['photo']}')
                      : null,
                  child: voter['photo'] == null
                      ? const Icon(Icons.person, size: 48)
                      : null),
              const SizedBox(width: 16),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    const Text('मतदाता पहचान पत्र (EPIC)',
                        style: TextStyle(color: muted)),
                    Text('${voter['voterId'] ?? '-'}',
                        style: const TextStyle(
                            color: blue, fontWeight: FontWeight.w900)),
                    const Divider(),
                    Text('अंतिम अपडेट: ${voter['updatedAt'] ?? '-'}',
                        style: const TextStyle(color: muted, fontSize: 11)),
                  ])),
            ]),
          ),
          Row(mainAxisAlignment: MainAxisAlignment.end, children: [
            OutlinedButton.icon(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.arrow_back),
                label: const Text('वापस जाएं')),
            const SizedBox(width: 10),
            FilledButton.icon(
                onPressed: () => printApiPdf(context,
                    path: '/api/export/members/${voter['_id']}.pdf',
                    jobName: 'मतदाता प्रोफाइल'),
                icon: const Icon(Icons.print),
                label: const Text('प्रिंट करें')),
            const SizedBox(width: 10),
            FilledButton.icon(
                onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) =>
                            VoterEditPage(voter: voter, onSaved: onChanged))),
                icon: const Icon(Icons.edit),
                label: const Text('संपादित करें')),
          ]),
          SectionCard(
              title: 'व्यक्तिगत जानकारी', child: DetailList(voter: voter)),
          VoterContactActions(voter: voter),
          Panel(
              title: 'परिवार विवरण',
              child: FamilyMembers(voter: voter, onChanged: onChanged)),
          Panel(
              title: 'राजनीतिक जानकारी',
              child: Text(
                  'समर्थन: ${voter['supportLevel'] ?? '-'}\nटिप्पणी: ${voter['notes'] ?? '-'}')),
        ]),
      );
}

class DetailList extends StatelessWidget {
  const DetailList({super.key, required this.voter});
  final Map voter;

  @override
  Widget build(BuildContext context) => Column(children: [
        info('नाम', voter['name']),
        info('मतदाता पहचान पत्र (EPIC)', voter['voterId']),
        info('पिता / पति का नाम', voter['guardianName']),
        info('घर संख्या', voter['houseNumber']),
        info('उम्र / लिंग',
            '${voter['age'] ?? '-'} / ${voter['gender'] ?? '-'}'),
        info('मोबाइल', voter['mobile']),
        info('पता', voter['address']),
        info('गाँव', voter['village']),
        info('ग्राम पंचायत', voter['gramPanchayat']),
        info('तहसील / ब्लॉक', voter['tehsil']),
        info('नगर पालिका', voter['municipality']),
        info('जाति', voter['caste']),
        info('उपजाति', voter['subCaste']),
        info('व्यवसाय', voter['occupation']),
        info('शिक्षा', voter['education']),
        info('संगठन पद', voter['organizationPost']),
        info('विधानसभा',
            '${voter['assemblyNumber'] ?? '-'} - ${voter['assemblyName'] ?? '-'}'),
        info('भाग / अनुभाग',
            '${voter['partNumber'] ?? '-'} / ${voter['sectionNumber'] ?? '-'} - ${voter['sectionName'] ?? '-'}'),
        info('वार्ड / बूथ',
            '${voter['ward']?['number'] ?? '-'} / ${voter['booth']?['number'] ?? '-'}'),
        ..._extraDetails(voter['extraDetails']),
      ]);

  List<Widget> _extraDetails(dynamic details) {
    if (details is! List) return const [];
    return details
        .whereType<Map>()
        .where((item) =>
            '${item['label'] ?? ''}'.trim().isNotEmpty &&
            '${item['value'] ?? ''}'.trim().isNotEmpty)
        .map((item) => info('${item['label']}', item['value']))
        .toList();
  }

  Widget info(String k, dynamic v) => ListTile(
      dense: true,
      title: Text(k, style: const TextStyle(color: Color(0xff63708a))),
      subtitle: Text('${v ?? '-'}',
          style: const TextStyle(fontWeight: FontWeight.w800)));
}

class VoterForm extends StatefulWidget {
  const VoterForm({super.key, this.voter, required this.onSaved});
  final Map<String, dynamic>? voter;
  final VoidCallback onSaved;

  @override
  State<VoterForm> createState() => _VoterFormState();
}

class _VoterFormState extends State<VoterForm> {
  final ctrls = <String, TextEditingController>{};
  String support = 'undecided';

  @override
  void initState() {
    super.initState();
    for (final f in [
      'name',
      'guardianName',
      'age',
      'dob',
      'gender',
      'mobile',
      'altMobile',
      'voterId',
      'houseNumber',
      'address',
      'occupation',
      'education',
      'notes',
      'ward',
      'booth'
    ]) {
      ctrls[f] = TextEditingController(text: '${widget.voter?[f] ?? ''}');
    }
    support = widget.voter?['supportLevel'] ?? 'undecided';
  }

  Future<void> save() async {
    final body = {
      for (final e in ctrls.entries) e.key: e.value.text,
      'supportLevel': support
    };
    if (widget.voter == null) {
      await api.post('/api/members', body);
    } else {
      await api.put('/api/members/${widget.voter!['_id']}', body);
    }
    widget.onSaved();
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: Text(
            widget.voter == null ? 'नया मतदाता जोड़ें' : 'मतदाता संपादित करें'),
        content: SizedBox(
            width: 760,
            child: SingleChildScrollView(
                child: Wrap(spacing: 12, runSpacing: 12, children: [
              for (final e in ctrls.entries)
                SizedBox(
                    width: 340,
                    child: TextField(
                        controller: e.value,
                        decoration: InputDecoration(
                            labelText: voterFieldLabel(e.key)))),
              SizedBox(
                  width: 340,
                  child: DropdownButtonFormField(
                      initialValue: support,
                      decoration:
                          const InputDecoration(labelText: 'समर्थन स्तर'),
                      items: const [
                        DropdownMenuItem(
                            value: 'supporter', child: Text('समर्थक मतदाता')),
                        DropdownMenuItem(
                            value: 'opposite', child: Text('विरोधी मतदाता')),
                        DropdownMenuItem(
                            value: 'neutral', child: Text('तटस्थ')),
                        DropdownMenuItem(
                            value: 'undecided', child: Text('अनिर्णीत')),
                      ],
                      onChanged: (v) => setState(() => support = '$v'))),
            ]))),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('रद्द करें')),
          FilledButton.icon(
              onPressed: save,
              icon: const Icon(Icons.save),
              label: const Text('सहेजें')),
        ],
      );
}

String voterFieldLabel(String key) =>
    {
      'name': 'नाम',
      'guardianName': 'पिता / पति का नाम',
      'age': 'उम्र',
      'dob': 'जन्म तिथि',
      'gender': 'लिंग',
      'mobile': 'मोबाइल नंबर',
      'altMobile': 'वैकल्पिक मोबाइल',
      'voterId': 'मतदाता पहचान पत्र (EPIC)',
      'houseNumber': 'घर संख्या',
      'address': 'पता',
      'occupation': 'व्यवसाय',
      'education': 'शिक्षा',
      'notes': 'टिप्पणी',
      'ward': 'वार्ड ID',
      'booth': 'बूथ ID',
    }[key] ??
    key;

int _supportCount(Map data, String key) => (data['support'] as List? ?? [])
    .where((e) => e['_id'] == key)
    .fold<int>(0, (sum, e) => sum + ((e['count'] ?? 0) as num).toInt());

int _number(dynamic value) =>
    value is num ? value.toInt() : int.tryParse('$value') ?? 0;
