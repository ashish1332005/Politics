import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../../core/api_client.dart';
import '../../core/contact_actions.dart';
import '../../core/download_helper.dart';
import '../../core/offline_voter_cache.dart';
import '../../core/picked_file_source.dart';
import '../../core/print_helper.dart';
import '../../core/theme.dart';
import '../../layout/app_layout.dart';
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
  final searchFocus = FocusNode();
  final speech = SpeechToText();
  final selectedIds = <String>{};
  final selectedOptionFilters = <String, Map<String, String>>{};
  final selectedOptionLabels = <String, String>{};
  final recentFilters = <_RecentFilter>[];
  bool listening = false;
  bool showAdvancedFilters = false;
  String gender = '';
  String verificationStatus = '';
  String support = '';
  String nameLetter = '';
  int currentPage = 1;
  late Future<Map<String, dynamic>> dashboardFuture;
  late Future<VoterPageResult> votersFuture;
  Timer? searchDebounce;
  static const int pageSize = 100;

  void refreshVoters() {
    votersFuture = OfflineVoterCache.loadPage(
      query: filterQuery,
      page: currentPage,
      limit: pageSize,
    );
  }

  void filtersChanged() => setState(() {
        currentPage = 1;
        refreshVoters();
      });

  void searchChanged(String _) {
    searchDebounce?.cancel();
    setState(() {});
    searchDebounce = Timer(const Duration(milliseconds: 450), () {
      if (mounted) filtersChanged();
    });
  }

  @override
  void initState() {
    super.initState();
    dashboardFuture = api.get('/api/reports/dashboard');
    refreshVoters();
  }

  @override
  void dispose() {
    searchDebounce?.cancel();
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
    searchFocus.dispose();
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
      'letter': nameLetter,
      if (nameLetter.isNotEmpty) 'qMode': 'name',
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
        setState(() {});
        if (result.finalResult) filtersChanged();
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
      nameLetter = '';
      currentPage = 1;
      selectedIds.clear();
      selectedOptionFilters.clear();
      selectedOptionLabels.clear();
      refreshVoters();
    });
  }

  String _filterValue(String field, TextEditingController controller) =>
      selectedOptionLabels[field] ?? controller.text.trim();

  void _rememberRecentFilter(String field, String title, _FilterOption option) {
    recentFilters.removeWhere(
        (item) => item.field == field && item.label == option.label);
    recentFilters.insert(
      0,
      _RecentFilter(
        field: field,
        title: title,
        label: option.label,
        filters: option.filters,
      ),
    );
    if (recentFilters.length > 8) {
      recentFilters.removeRange(8, recentFilters.length);
    }
  }

  void _applyRecentFilter(_RecentFilter filter) => setState(() {
        selectedOptionFilters[filter.field] = filter.filters;
        selectedOptionLabels[filter.field] = filter.label;
        currentPage = 1;
        selectedIds.clear();
        refreshVoters();
      });

  void _clearFilterText(TextEditingController controller) => setState(() {
        controller.clear();
        currentPage = 1;
        selectedIds.clear();
        refreshVoters();
      });

  void _clearSmartOrText(String field, TextEditingController controller) =>
      setState(() {
        selectedOptionFilters.remove(field);
        selectedOptionLabels.remove(field);
        controller.clear();
        currentPage = 1;
        selectedIds.clear();
        refreshVoters();
      });

  void _clearLocationFilters() => setState(() {
        for (final field in [
          'assembly',
          'village',
          'gramPanchayat',
          'partNumber'
        ]) {
          selectedOptionFilters.remove(field);
          selectedOptionLabels.remove(field);
        }
        assemblyNumber.clear();
        village.clear();
        gramPanchayat.clear();
        boothNumber.clear();
        currentPage = 1;
        selectedIds.clear();
        refreshVoters();
      });

  List<_ActiveFilterData> get activeFilterChips {
    final chips = <_ActiveFilterData>[];
    void add(String label, String value, VoidCallback onClear) {
      final clean = value.trim();
      if (clean.isEmpty) return;
      chips
          .add(_ActiveFilterData(label: label, value: clean, onClear: onClear));
    }

    add('Search', search.text, () => _clearFilterText(search));
    add(
        'अक्षर',
        nameLetter,
        () => setState(() {
              nameLetter = '';
              currentPage = 1;
              selectedIds.clear();
              refreshVoters();
            }));
    add(
        'समर्थन',
        _supportLabel(support),
        () => setState(() {
              support = '';
              currentPage = 1;
              selectedIds.clear();
              refreshVoters();
            }));
    add(
        'लिंग',
        _genderLabel(gender),
        () => setState(() {
              gender = '';
              currentPage = 1;
              selectedIds.clear();
              refreshVoters();
            }));
    add(
        'सत्यापन',
        _verificationLabel(verificationStatus),
        () => setState(() {
              verificationStatus = '';
              currentPage = 1;
              selectedIds.clear();
              refreshVoters();
            }));
    add('विधानसभा', _filterValue('assembly', assemblyNumber),
        () => _clearSmartOrText('assembly', assemblyNumber));
    add('गाँव', _filterValue('village', village),
        () => _clearSmartOrText('village', village));
    add('पंचायत', _filterValue('gramPanchayat', gramPanchayat),
        () => _clearSmartOrText('gramPanchayat', gramPanchayat));
    add('भाग', _filterValue('partNumber', boothNumber),
        () => _clearSmartOrText('partNumber', boothNumber));
    add('अनुभाग नं.', sectionNumber.text,
        () => _clearFilterText(sectionNumber));
    add('अनुभाग', _filterValue('section', sectionName),
        () => _clearSmartOrText('section', sectionName));
    add('तहसील', _filterValue('tehsil', tehsil),
        () => _clearSmartOrText('tehsil', tehsil));
    add('नगर पालिका', _filterValue('municipality', municipality),
        () => _clearSmartOrText('municipality', municipality));
    add('स्थान', location.text, () => _clearFilterText(location));
    add('जाति', _filterValue('caste', caste),
        () => _clearSmartOrText('caste', caste));
    add('पद', _filterValue('organizationPost', organizationPost),
        () => _clearSmartOrText('organizationPost', organizationPost));
    return chips;
  }

  String _supportLabel(String value) => switch (value) {
        'supporter' => 'समर्थक',
        'neutral' => 'तटस्थ',
        'opposite' => 'विरोधी',
        'undecided' => 'अनिर्णीत',
        _ => '',
      };

  String _genderLabel(String value) => switch (value) {
        'male' => 'पुरुष',
        'female' => 'महिला',
        'other' => 'अन्य',
        _ => '',
      };

  String _verificationLabel(String value) => switch (value) {
        'pending' => 'लंबित',
        'verified' => 'सत्यापित',
        'needs_review' => 'Review आवश्यक',
        'duplicate' => 'डुप्लीकेट',
        _ => '',
      };

  Future<void> useQuickSearch(String mode) async {
    final cleanMode = mode.startsWith('जैसे') ? 'नाम' : mode;
    final value = await showDialog<String>(
      context: context,
      builder: (_) => _QuickSearchDialog(mode: cleanMode),
    );
    if (value == null || value.trim().isEmpty || !mounted) {
      searchFocus.requestFocus();
      return;
    }
    setState(() {
      search.text = value.trim();
      search.selection = TextSelection.collapsed(offset: search.text.length);
      currentPage = 1;
      selectedIds.clear();
      refreshVoters();
    });
    searchFocus.requestFocus();
  }

  Future<void> openLocationCorrection() async {
    final changed = await showDialog<bool>(
      context: context,
      builder: (_) => const _LocationCorrectionDialog(),
    );
    if (changed == true && mounted) {
      setState(() {
        currentPage = 1;
        selectedIds.clear();
        refreshVoters();
      });
    }
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
      _rememberRecentFilter(field, title, option);
      currentPage = 1;
      selectedIds.clear();
      refreshVoters();
    });
  }

  Future<_FilterOption?> pickFilterOption(
    String field,
    String title,
    Map<String, String?> currentFilters,
  ) =>
      showDialog<_FilterOption>(
        context: context,
        builder: (_) => _FilterOptionDialog(
          field: field,
          title: title,
          currentFilters: currentFilters,
        ),
      );

  void clearSmartFilter(String field) => setState(() {
        selectedOptionFilters.remove(field);
        selectedOptionLabels.remove(field);
        currentPage = 1;
        selectedIds.clear();
        refreshVoters();
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
      setState(refreshVoters);
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

  Future<void> openPhoneFilters() async {
    var nextSupport = support;
    var nextGender = gender;
    var nextVerification = verificationStatus;
    final nextVillage = TextEditingController(text: village.text);
    final nextBooth = TextEditingController(text: boothNumber.text);
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) => Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            12,
            20,
            MediaQuery.viewInsetsOf(context).bottom + 20,
          ),
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: border,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              const SizedBox(height: 18),
              Row(children: [
                const Expanded(
                  child: Text('मतदाता फ़िल्टर',
                      style: TextStyle(
                          color: navy,
                          fontSize: 19,
                          fontWeight: FontWeight.w900)),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.pop(sheetContext);
                    clearFilters();
                  },
                  child: const Text('Reset'),
                ),
              ]),
              const SizedBox(height: 14),
              DropdownButtonFormField<String>(
                initialValue: nextSupport,
                decoration: const InputDecoration(
                    labelText: 'श्रेणी',
                    prefixIcon: Icon(Icons.groups_rounded)),
                items: const [
                  DropdownMenuItem(value: '', child: Text('सभी मतदाता')),
                  DropdownMenuItem(value: 'supporter', child: Text('समर्थक')),
                  DropdownMenuItem(value: 'neutral', child: Text('तटस्थ')),
                  DropdownMenuItem(value: 'opposite', child: Text('विरोधी')),
                  DropdownMenuItem(value: 'undecided', child: Text('अनिर्णीत')),
                ],
                onChanged: (value) =>
                    setSheetState(() => nextSupport = value ?? ''),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: nextGender,
                decoration: const InputDecoration(
                    labelText: 'लिंग', prefixIcon: Icon(Icons.person_outline)),
                items: const [
                  DropdownMenuItem(value: '', child: Text('सभी')),
                  DropdownMenuItem(value: 'male', child: Text('पुरुष')),
                  DropdownMenuItem(value: 'female', child: Text('महिला')),
                  DropdownMenuItem(value: 'other', child: Text('अन्य')),
                ],
                onChanged: (value) =>
                    setSheetState(() => nextGender = value ?? ''),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: nextVillage,
                decoration: InputDecoration(
                  labelText: 'गाँव / क्षेत्र',
                  prefixIcon: const Icon(Icons.location_on_outlined),
                  suffixIcon: IconButton(
                    tooltip: 'Database से गाँव चुनें',
                    icon: const Icon(Icons.list_alt_rounded),
                    onPressed: () async {
                      final option = await pickFilterOption('village', 'गाँव', {
                        if (nextSupport.isNotEmpty) 'supportLevel': nextSupport,
                        if (nextGender.isNotEmpty) 'gender': nextGender,
                        if (nextVerification.isNotEmpty)
                          'verificationStatus': nextVerification,
                      });
                      if (option == null) return;
                      setSheetState(() => nextVillage.text =
                          option.filters['village'] ?? option.label);
                    },
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: nextBooth,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'भाग / बूथ संख्या',
                  prefixIcon: const Icon(Icons.how_to_vote_outlined),
                  suffixIcon: IconButton(
                    tooltip: 'Database से भाग चुनें',
                    icon: const Icon(Icons.list_alt_rounded),
                    onPressed: () async {
                      final option =
                          await pickFilterOption('partNumber', 'भाग / बूथ', {
                        if (nextSupport.isNotEmpty) 'supportLevel': nextSupport,
                        if (nextGender.isNotEmpty) 'gender': nextGender,
                        if (nextVerification.isNotEmpty)
                          'verificationStatus': nextVerification,
                        if (nextVillage.text.trim().isNotEmpty)
                          'village': nextVillage.text.trim(),
                      });
                      if (option == null) return;
                      setSheetState(() => nextBooth.text =
                          option.filters['partNumber'] ?? option.label);
                    },
                  ),
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: nextVerification,
                decoration: const InputDecoration(
                    labelText: 'डेटा स्थिति',
                    prefixIcon: Icon(Icons.fact_check_outlined)),
                items: const [
                  DropdownMenuItem(value: '', child: Text('सभी')),
                  DropdownMenuItem(value: 'verified', child: Text('सत्यापित')),
                  DropdownMenuItem(
                      value: 'needs_review', child: Text('Review आवश्यक')),
                  DropdownMenuItem(value: 'pending', child: Text('लंबित')),
                ],
                onChanged: (value) =>
                    setSheetState(() => nextVerification = value ?? ''),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton.icon(
                  onPressed: () {
                    setState(() {
                      support = nextSupport;
                      gender = nextGender;
                      verificationStatus = nextVerification;
                      village.text = nextVillage.text.trim();
                      boothNumber.text = nextBooth.text.trim();
                      currentPage = 1;
                      refreshVoters();
                    });
                    Navigator.pop(sheetContext);
                  },
                  icon: const Icon(Icons.check_rounded),
                  label: const Text('फ़िल्टर लागू करें'),
                ),
              ),
            ]),
          ),
        ),
      ),
    );
    nextVillage.dispose();
    nextBooth.dispose();
  }

  Widget buildPhoneBookMobile(BuildContext context) => RefreshIndicator(
        onRefresh: () async {
          setState(refreshVoters);
          await votersFuture;
        },
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 110),
          children: [
            _EasyVoterSearchCard(
              controller: search,
              focusNode: searchFocus,
              listening: listening,
              onChanged: searchChanged,
              onSubmitted: (_) => filtersChanged(),
              onClear: () {
                search.clear();
                filtersChanged();
              },
              onMic: toggleVoiceSearch,
              onQuickPick: useQuickSearch,
            ),
            const SizedBox(height: 16),
            _PhoneCategoryStrip(
              selected: support,
              reviewSelected: verificationStatus == 'needs_review',
              onChanged: (value) => setState(() {
                support = value;
                verificationStatus = '';
                currentPage = 1;
                refreshVoters();
              }),
              onReview: () => setState(() {
                support = '';
                verificationStatus = 'needs_review';
                currentPage = 1;
                refreshVoters();
              }),
            ),
            const SizedBox(height: 18),
            Row(children: [
              const Expanded(
                  child: Text('सभी संपर्क',
                      style: TextStyle(
                          color: navy,
                          fontSize: 18,
                          fontWeight: FontWeight.w900))),
              if (api.user?['role'] == 'admin') ...[
                IconButton.outlined(
                  tooltip: 'Location Bulk Fix',
                  onPressed: openLocationCorrection,
                  icon: const Icon(Icons.edit_location_alt_rounded, size: 20),
                ),
                const SizedBox(width: 7),
              ],
              IconButton.outlined(
                tooltip: 'फ़िल्टर',
                onPressed: openPhoneFilters,
                icon: const Icon(Icons.tune_rounded, size: 20),
              ),
              const SizedBox(width: 7),
              IconButton.outlined(
                tooltip: 'नाम क्रम',
                onPressed: () => showModalBottomSheet<void>(
                  context: context,
                  backgroundColor: Colors.white,
                  builder: (_) => SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: _AlphabetFilterBar(
                        selected: nameLetter,
                        onChanged: (letter) {
                          Navigator.pop(context);
                          setState(() {
                            nameLetter = letter;
                            currentPage = 1;
                            refreshVoters();
                          });
                        },
                      ),
                    ),
                  ),
                ),
                icon: const Icon(Icons.sort_by_alpha_rounded, size: 20),
              ),
            ]),
            _ActiveFilterChips(
              items: activeFilterChips,
              onClearAll: clearFilters,
              compact: true,
            ),
            _LocationFilterCard(
              assembly: _filterValue('assembly', assemblyNumber),
              village: _filterValue('village', village),
              gramPanchayat: _filterValue('gramPanchayat', gramPanchayat),
              partNumber: _filterValue('partNumber', boothNumber),
              onPickAssembly: () => openSmartFilter('assembly', 'विधानसभा'),
              onPickVillage: () => openSmartFilter('village', 'गाँव'),
              onPickPanchayat: () =>
                  openSmartFilter('gramPanchayat', 'ग्राम पंचायत'),
              onPickPart: () => openSmartFilter('partNumber', 'भाग / बूथ'),
              onClear: _clearLocationFilters,
              compact: true,
            ),
            _RecentFilterStrip(
              items: recentFilters,
              onTap: _applyRecentFilter,
            ),
            const SizedBox(height: 8),
            FutureBuilder<VoterPageResult>(
              future: votersFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const Padding(
                      padding: EdgeInsets.all(36),
                      child: Center(child: CircularProgressIndicator()));
                }
                if (snapshot.hasError) {
                  return _PhoneMessage(
                    icon: Icons.cloud_off_rounded,
                    title: 'डेटा लोड नहीं हुआ',
                    subtitle: '${snapshot.error}',
                    onRetry: () => setState(refreshVoters),
                  );
                }
                final result = snapshot.data!;
                if (result.items.isEmpty) {
                  return Column(
                    children: [
                      _FilterResultSummary(
                        total: result.total,
                        shown: result.items.length,
                        activeFilters: activeFilterChips.length,
                      ),
                      const SizedBox(height: 10),
                      _PhoneMessage(
                        icon: Icons.person_search_rounded,
                        title: 'कोई मतदाता नहीं मिला',
                        subtitle:
                            'नाम की spelling बदलें या फ़िल्टर हटाकर खोजें।',
                        onRetry: clearFilters,
                      ),
                    ],
                  );
                }
                return Column(
                  children: [
                    _FilterResultSummary(
                      total: result.total,
                      shown: result.items.length,
                      activeFilters: activeFilterChips.length,
                    ),
                    const SizedBox(height: 10),
                    _PhoneContactList(
                      result: result,
                      onChanged: () => setState(refreshVoters),
                      onPageChanged: (page) => setState(() {
                        currentPage = page;
                        refreshVoters();
                      }),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.sizeOf(context).width < 700) {
      return buildPhoneBookMobile(context);
    }
    return AppPage(children: [
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
            if (api.user?['role'] == 'admin')
              OutlinedButton.icon(
                onPressed: openLocationCorrection,
                icon: const Icon(Icons.edit_location_alt_rounded),
                label: Text(compact ? 'Location Fix' : 'Location Bulk Fix'),
              ),
            FilledButton.icon(
              onPressed: () => showDialog(
                  context: context,
                  builder: (_) =>
                      VoterForm(onSaved: () => setState(refreshVoters))),
              icon: const Icon(Icons.add),
              label: Text(compact ? 'नया मतदाता' : 'नया मतदाता जोड़ें'),
            ),
          ]);
        }),
      ),
      LayoutBuilder(builder: (context, constraints) {
        final compact = constraints.maxWidth < 620;
        final searchBox = _EasyVoterSearchField(
          controller: search,
          focusNode: searchFocus,
          listening: listening,
          onChanged: searchChanged,
          onSubmitted: (_) {
            searchDebounce?.cancel();
            filtersChanged();
          },
          onClear: () {
            searchDebounce?.cancel();
            search.clear();
            filtersChanged();
          },
          onMic: toggleVoiceSearch,
          compact: compact,
        );
        final filterButton = OutlinedButton.icon(
          onPressed: () =>
              setState(() => showAdvancedFilters = !showAdvancedFilters),
          icon: Icon(
            showAdvancedFilters ? Icons.filter_alt_rounded : Icons.tune_rounded,
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
          child: Text('सुन रहा हूँ… नाम, पिता/पति, EPIC या मोबाइल बोलें',
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.w700)),
        ),
      const SizedBox(height: 8),
      _SearchHelpStrip(onPick: useQuickSearch),
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
                  refreshVoters();
                }),
      ),
      _ActiveFilterChips(
        items: activeFilterChips,
        onClearAll: clearFilters,
      ),
      _LocationFilterCard(
        assembly: _filterValue('assembly', assemblyNumber),
        village: _filterValue('village', village),
        gramPanchayat: _filterValue('gramPanchayat', gramPanchayat),
        partNumber: _filterValue('partNumber', boothNumber),
        onPickAssembly: () => openSmartFilter('assembly', 'विधानसभा'),
        onPickVillage: () => openSmartFilter('village', 'गाँव'),
        onPickPanchayat: () => openSmartFilter('gramPanchayat', 'ग्राम पंचायत'),
        onPickPart: () => openSmartFilter('partNumber', 'भाग / बूथ'),
        onClear: _clearLocationFilters,
      ),
      _RecentFilterStrip(
        items: recentFilters,
        onTap: _applyRecentFilter,
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
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text(
              'Type करें या field के list icon से database options scroll/search करके चुनें।',
              style: TextStyle(
                  color: muted, fontSize: 12, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 10),
            Wrap(spacing: 10, runSpacing: 10, children: [
              _SearchFilter(
                  controller: assemblyNumber,
                  label: 'विधानसभा संख्या',
                  icon: Icons.account_balance_outlined,
                  onChanged: (_) => filtersChanged(),
                  onPick: () => openSmartFilter('assembly', 'विधानसभा')),
              _SearchFilter(
                  controller: boothNumber,
                  label: 'भाग / बूथ संख्या',
                  icon: Icons.how_to_vote_outlined,
                  onChanged: (_) => filtersChanged(),
                  onPick: () => openSmartFilter('partNumber', 'भाग / बूथ')),
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
                  onChanged: (_) => filtersChanged(),
                  onPick: () => openSmartFilter('village', 'गाँव')),
              _SearchFilter(
                  controller: gramPanchayat,
                  label: 'ग्राम पंचायत',
                  icon: Icons.holiday_village_outlined,
                  onChanged: (_) => filtersChanged(),
                  onPick: () =>
                      openSmartFilter('gramPanchayat', 'ग्राम पंचायत')),
              _SearchFilter(
                  controller: tehsil,
                  label: 'तहसील',
                  icon: Icons.location_city_outlined,
                  onChanged: (_) => filtersChanged(),
                  onPick: () => openSmartFilter('tehsil', 'तहसील')),
              _SearchFilter(
                  controller: municipality,
                  label: 'नगर पालिका',
                  icon: Icons.apartment_outlined,
                  onChanged: (_) => filtersChanged(),
                  onPick: () => openSmartFilter('municipality', 'नगर पालिका')),
              _SearchFilter(
                  controller: location,
                  label: 'पता / स्थान',
                  icon: Icons.location_on_outlined,
                  onChanged: (_) => filtersChanged()),
              _SearchFilter(
                  controller: caste,
                  label: 'जाति',
                  icon: Icons.groups_2_outlined,
                  onChanged: (_) => filtersChanged(),
                  onPick: () => openSmartFilter('caste', 'जाति')),
              _SearchFilter(
                  controller: organizationPost,
                  label: 'राजनीतिक पद',
                  icon: Icons.badge_outlined,
                  onChanged: (_) => filtersChanged(),
                  onPick: () =>
                      openSmartFilter('organizationPost', 'संगठन पद')),
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
                  refreshVoters();
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
                  refreshVoters();
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
                  refreshVoters();
                }),
              ),
            ]),
          ]),
        ),
      ],
      FutureBuilder<Map<String, dynamic>>(
        future: dashboardFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(30),
                child: CircularProgressIndicator(),
              ),
            );
          }
          if (snapshot.hasError) {
            return Padding(
              padding: const EdgeInsets.all(24),
              child: Text('${snapshot.error}',
                  style: const TextStyle(color: Colors.red)),
            );
          }
          final d = snapshot.data ?? const <String, dynamic>{};
          return LayoutBuilder(builder: (context, constraints) {
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
          });
        },
      ),
      _AlphabetFilterBar(
        selected: nameLetter,
        onChanged: (letter) => setState(() {
          nameLetter = letter;
          currentPage = 1;
          selectedIds.clear();
          refreshVoters();
        }),
      ),
      FutureBuilder<VoterPageResult>(
        future: votersFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(30),
                child: CircularProgressIndicator(),
              ),
            );
          }
          if (snapshot.hasError) {
            return Padding(
              padding: const EdgeInsets.all(24),
              child: Text('${snapshot.error}',
                  style: const TextStyle(color: Colors.red)),
            );
          }
          final result = snapshot.data!;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _FilterResultSummary(
                total: result.total,
                shown: result.items.length,
                activeFilters: activeFilterChips.length,
              ),
              const SizedBox(height: 10),
              VoterTable(
                items: result.items
                    .map((e) => Map<String, dynamic>.from(e))
                    .toList(),
                refresh: () => setState(refreshVoters),
                onDeleteAll: deleteAll,
                total: result.total,
                page: result.page,
                pages: result.pages,
                onPageChanged: (page) => setState(() {
                  currentPage = page;
                  refreshVoters();
                }),
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
            ],
          );
        },
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
              label:
                  Text(selectedIds.isEmpty ? 'फ़िल्टर Excel' : 'चयनित Excel')),
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
}

class _ActiveFilterData {
  const _ActiveFilterData({
    required this.label,
    required this.value,
    required this.onClear,
  });

  final String label;
  final String value;
  final VoidCallback onClear;
}

class _RecentFilter {
  const _RecentFilter({
    required this.field,
    required this.title,
    required this.label,
    required this.filters,
  });

  final String field;
  final String title;
  final String label;
  final Map<String, String> filters;
}

class _ActiveFilterChips extends StatelessWidget {
  const _ActiveFilterChips({
    required this.items,
    required this.onClearAll,
    this.compact = false,
  });

  final List<_ActiveFilterData> items;
  final VoidCallback onClearAll;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: EdgeInsets.only(top: compact ? 8 : 10, bottom: compact ? 2 : 0),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xfff8fbff),
          borderRadius: BorderRadius.circular(compact ? 18 : 20),
          border: Border.all(color: border),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Icon(Icons.filter_alt_rounded, color: blue, size: 18),
            const SizedBox(width: 7),
            Text('${items.length} active filters',
                style: const TextStyle(
                    color: navy, fontWeight: FontWeight.w900, fontSize: 13)),
            const Spacer(),
            TextButton(
              onPressed: onClearAll,
              child: const Text('Reset all'),
            ),
          ]),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: items
                .map((item) => InputChip(
                      avatar: const Icon(Icons.check_circle_rounded,
                          color: green, size: 17),
                      label: Text('${item.label}: ${item.value}'),
                      onDeleted: item.onClear,
                      labelStyle: const TextStyle(
                          color: navy, fontWeight: FontWeight.w800),
                      backgroundColor: Colors.white,
                      side: const BorderSide(color: border),
                    ))
                .toList(),
          ),
        ]),
      ),
    );
  }
}

class _LocationFilterCard extends StatelessWidget {
  const _LocationFilterCard({
    required this.assembly,
    required this.village,
    required this.gramPanchayat,
    required this.partNumber,
    required this.onPickAssembly,
    required this.onPickVillage,
    required this.onPickPanchayat,
    required this.onPickPart,
    required this.onClear,
    this.compact = false,
  });

  final String assembly;
  final String village;
  final String gramPanchayat;
  final String partNumber;
  final VoidCallback onPickAssembly;
  final VoidCallback onPickVillage;
  final VoidCallback onPickPanchayat;
  final VoidCallback onPickPart;
  final VoidCallback onClear;
  final bool compact;

  bool get hasAny =>
      assembly.trim().isNotEmpty ||
      village.trim().isNotEmpty ||
      gramPanchayat.trim().isNotEmpty ||
      partNumber.trim().isNotEmpty;

  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.only(top: compact ? 8 : 10),
        child: Container(
          width: double.infinity,
          padding: EdgeInsets.all(compact ? 12 : 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(compact ? 18 : 22),
            border: Border.all(
                color: hasAny ? blue.withValues(alpha: .28) : border),
            boxShadow: const [
              BoxShadow(
                color: Color(0x0c071b4b),
                blurRadius: 18,
                offset: Offset(0, 8),
              ),
            ],
          ),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: softBlue,
                  borderRadius: BorderRadius.circular(13),
                ),
                child: const Icon(Icons.map_rounded, color: blue, size: 20),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('गाँव + पंचायत + भाग',
                          style: TextStyle(
                              color: navy,
                              fontSize: 15,
                              fontWeight: FontWeight.w900)),
                      SizedBox(height: 2),
                      Text(
                          'गाँव अकेला unique नहीं — पूरी location key से filter करें',
                          style: TextStyle(color: muted, fontSize: 11)),
                    ]),
              ),
              if (hasAny)
                IconButton(
                  tooltip: 'Location filter हटाएँ',
                  onPressed: onClear,
                  icon: const Icon(Icons.close_rounded, color: muted),
                ),
            ]),
            const SizedBox(height: 11),
            LayoutBuilder(builder: (context, constraints) {
              final chipWidth = constraints.maxWidth < 380
                  ? (constraints.maxWidth - 8) / 2
                  : compact
                      ? 150.0
                      : 168.0;
              return Wrap(spacing: 8, runSpacing: 8, children: [
                _LocationPickChip(
                    width: chipWidth,
                    label: 'विधानसभा',
                    value: assembly,
                    icon: Icons.account_balance_rounded,
                    onTap: onPickAssembly),
                _LocationPickChip(
                    width: chipWidth,
                    label: 'गाँव',
                    value: village,
                    icon: Icons.home_work_rounded,
                    onTap: onPickVillage),
                _LocationPickChip(
                    width: chipWidth,
                    label: 'पंचायत',
                    value: gramPanchayat,
                    icon: Icons.holiday_village_rounded,
                    onTap: onPickPanchayat),
                _LocationPickChip(
                    width: chipWidth,
                    label: 'भाग',
                    value: partNumber,
                    icon: Icons.how_to_vote_rounded,
                    onTap: onPickPart),
              ]);
            }),
          ]),
        ),
      );
}

class _LocationPickChip extends StatelessWidget {
  const _LocationPickChip({
    required this.width,
    required this.label,
    required this.value,
    required this.icon,
    required this.onTap,
  });

  final double width;
  final String label;
  final String value;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final selected = value.trim().isNotEmpty;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: width,
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 9),
        decoration: BoxDecoration(
          color: selected ? softBlue : const Color(0xfff7f9ff),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
              color: selected ? blue.withValues(alpha: .35) : border),
        ),
        child: Row(children: [
          Icon(icon, color: selected ? blue : muted, size: 18),
          const SizedBox(width: 7),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(label, style: const TextStyle(color: muted, fontSize: 9.5)),
              const SizedBox(height: 2),
              Text(selected ? value : 'चुनें',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      color: selected ? navy : muted,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w900)),
            ]),
          ),
          const Icon(Icons.keyboard_arrow_down_rounded, color: muted, size: 18),
        ]),
      ),
    );
  }
}

class _RecentFilterStrip extends StatelessWidget {
  const _RecentFilterStrip({required this.items, required this.onTap});

  final List<_RecentFilter> items;
  final ValueChanged<_RecentFilter> onTap;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Recent filters',
            style: TextStyle(
                color: navy, fontWeight: FontWeight.w900, fontSize: 13)),
        const SizedBox(height: 7),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: items
                .map((item) => Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ActionChip(
                        avatar: const Icon(Icons.history_rounded, size: 17),
                        label: Text('${item.title}: ${item.label}'),
                        onPressed: () => onTap(item),
                      ),
                    ))
                .toList(),
          ),
        ),
      ]),
    );
  }
}

class _FilterResultSummary extends StatelessWidget {
  const _FilterResultSummary({
    required this.total,
    required this.shown,
    required this.activeFilters,
  });

  final int total;
  final int shown;
  final int activeFilters;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          color: const Color(0xffeef6ff),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: blue.withValues(alpha: .16)),
        ),
        child: Row(children: [
          const Icon(Icons.people_alt_rounded, color: blue, size: 20),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              activeFilters == 0
                  ? '$total मतदाता मिले'
                  : '$total मतदाता मिले • $activeFilters filter active',
              style: const TextStyle(color: navy, fontWeight: FontWeight.w900),
            ),
          ),
          Text('इस पेज: $shown',
              style:
                  const TextStyle(color: muted, fontWeight: FontWeight.w800)),
        ]),
      );
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
            'नाम, पिता/पति का नाम, EPIC, मोबाइल या घर संख्या लिखकर तुरंत खोजें',
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
          const Wrap(
            spacing: 7,
            runSpacing: 7,
            children: [
              _SearchHintChip(Icons.person_search_rounded, 'मतदाता नाम'),
              _SearchHintChip(Icons.family_restroom_rounded, 'पिता/पति नाम'),
              _SearchHintChip(Icons.badge_outlined, 'EPIC'),
              _SearchHintChip(Icons.home_rounded, 'घर संख्या'),
              _SearchHintChip(Icons.phone_rounded, 'मोबाइल'),
            ],
          ),
          const SizedBox(height: 10),
          const Text(
            'Tip: “रामलाल मोहन” जैसे नाम + पिता/पति नाम साथ लिखने पर भी search चलेगा।',
            style: TextStyle(color: muted, fontSize: 12),
          ),
        ]),
      );
}

class _EasyVoterSearchCard extends StatelessWidget {
  const _EasyVoterSearchCard({
    required this.controller,
    required this.focusNode,
    required this.listening,
    required this.onChanged,
    required this.onSubmitted,
    required this.onClear,
    required this.onMic,
    required this.onQuickPick,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final bool listening;
  final ValueChanged<String> onChanged;
  final ValueChanged<String> onSubmitted;
  final VoidCallback onClear;
  final VoidCallback onMic;
  final ValueChanged<String> onQuickPick;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: border),
          boxShadow: const [
            BoxShadow(
              color: Color(0x0f071b4b),
              blurRadius: 18,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Row(children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: softBlue,
              child: Icon(Icons.manage_search_rounded, color: blue, size: 20),
            ),
            SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('आसान खोज',
                      style: TextStyle(
                          color: navy,
                          fontSize: 16,
                          fontWeight: FontWeight.w900)),
                  SizedBox(height: 2),
                  Text('नाम, पिता/पति, EPIC, मोबाइल या घर संख्या लिखें',
                      style: TextStyle(color: muted, fontSize: 12)),
                ],
              ),
            ),
          ]),
          const SizedBox(height: 12),
          _EasyVoterSearchField(
            controller: controller,
            focusNode: focusNode,
            listening: listening,
            onChanged: onChanged,
            onSubmitted: onSubmitted,
            onClear: onClear,
            onMic: onMic,
            compact: true,
          ),
          if (listening) ...[
            const SizedBox(height: 8),
            const Text('सुन रहा हूँ… नाम, पिता/पति, EPIC या मोबाइल बोलें',
                style: TextStyle(
                    color: Colors.red,
                    fontSize: 12,
                    fontWeight: FontWeight.w800)),
          ],
          const SizedBox(height: 11),
          _SearchHelpStrip(compact: true, onPick: onQuickPick),
        ]),
      );
}

class _EasyVoterSearchField extends StatelessWidget {
  const _EasyVoterSearchField({
    required this.controller,
    required this.focusNode,
    required this.listening,
    required this.onChanged,
    required this.onSubmitted,
    required this.onClear,
    required this.onMic,
    this.compact = false,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final bool listening;
  final ValueChanged<String> onChanged;
  final ValueChanged<String> onSubmitted;
  final VoidCallback onClear;
  final VoidCallback onMic;
  final bool compact;

  @override
  Widget build(BuildContext context) => TextField(
        controller: controller,
        focusNode: focusNode,
        onChanged: onChanged,
        textInputAction: TextInputAction.search,
        onSubmitted: onSubmitted,
        style: const TextStyle(fontWeight: FontWeight.w800, color: navy),
        decoration: InputDecoration(
          hintText: compact
              ? 'नाम, पिता/पति, EPIC, मोबाइल...'
              : 'नाम, पिता/पति, EPIC, मोबाइल, घर, गाँव या पंचायत खोजें...',
          hintStyle: const TextStyle(color: muted, fontWeight: FontWeight.w600),
          prefixIcon: const Icon(Icons.search_rounded, color: blue),
          suffixIcon: Row(mainAxisSize: MainAxisSize.min, children: [
            if (controller.text.isNotEmpty)
              IconButton(
                tooltip: 'खोज साफ करें',
                onPressed: onClear,
                icon: const Icon(Icons.close_rounded),
              ),
            IconButton(
              tooltip: listening ? 'सुनना बंद करें' : 'बोलकर खोजें',
              onPressed: onMic,
              icon: Icon(
                listening ? Icons.mic_rounded : Icons.mic_none_rounded,
                color: listening ? Colors.red : blue,
              ),
            ),
          ]),
          filled: true,
          fillColor: const Color(0xfff7f9ff),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: blue, width: 1.4),
          ),
        ),
      );
}

class _SearchHelpStrip extends StatelessWidget {
  const _SearchHelpStrip({this.compact = false, this.onPick});
  final bool compact;
  final ValueChanged<String>? onPick;

  @override
  Widget build(BuildContext context) => Wrap(
        spacing: 7,
        runSpacing: 7,
        children: [
          _SearchHintChip(Icons.person_search_rounded, 'नाम', onTap: onPick),
          _SearchHintChip(Icons.family_restroom_rounded, 'पिता/पति',
              onTap: onPick),
          _SearchHintChip(Icons.badge_outlined, 'EPIC', onTap: onPick),
          _SearchHintChip(Icons.home_rounded, 'घर', onTap: onPick),
          _SearchHintChip(Icons.phone_rounded, 'मोबाइल', onTap: onPick),
          if (!compact)
            _SearchHintChip(Icons.lightbulb_outline_rounded, 'जैसे: राम मोहन',
                onTap: onPick),
        ],
      );
}

class _SearchHintChip extends StatelessWidget {
  const _SearchHintChip(this.icon, this.label, {this.onTap});
  final IconData icon;
  final String label;
  final ValueChanged<String>? onTap;

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap == null ? null : () => onTap!(label),
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xfff6f8fc),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: border),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, color: blue, size: 14),
            const SizedBox(width: 5),
            Text(label,
                style: const TextStyle(
                    color: navy, fontSize: 12, fontWeight: FontWeight.w800)),
          ]),
        ),
      );
}

class _QuickSearchDialog extends StatefulWidget {
  const _QuickSearchDialog({required this.mode});
  final String mode;

  @override
  State<_QuickSearchDialog> createState() => _QuickSearchDialogState();
}

class _QuickSearchDialogState extends State<_QuickSearchDialog> {
  final controller = TextEditingController();

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  String get hint => switch (widget.mode) {
        'पिता/पति' => 'पिता या पति का नाम लिखें...',
        'EPIC' => 'EPIC नंबर लिखें...',
        'घर' => 'घर संख्या लिखें...',
        'मोबाइल' => 'मोबाइल नंबर लिखें...',
        _ => 'मतदाता का नाम लिखें...',
      };

  IconData get icon => switch (widget.mode) {
        'पिता/पति' => Icons.family_restroom_rounded,
        'EPIC' => Icons.badge_outlined,
        'घर' => Icons.home_rounded,
        'मोबाइल' => Icons.phone_rounded,
        _ => Icons.person_search_rounded,
      };

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: Row(children: [
          CircleAvatar(
            backgroundColor: softBlue,
            child: Icon(icon, color: blue),
          ),
          const SizedBox(width: 10),
          Expanded(child: Text('${widget.mode} से खोजें')),
        ]),
        content: TextField(
          controller: controller,
          autofocus: true,
          textInputAction: TextInputAction.search,
          onSubmitted: (value) => Navigator.pop(context, value),
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: Icon(icon),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          FilledButton.icon(
            onPressed: () => Navigator.pop(context, controller.text),
            icon: const Icon(Icons.search_rounded),
            label: const Text('Search'),
          ),
        ],
      );
}

class _PhoneCategoryStrip extends StatelessWidget {
  const _PhoneCategoryStrip({
    required this.selected,
    required this.reviewSelected,
    required this.onChanged,
    required this.onReview,
  });

  final String selected;
  final bool reviewSelected;
  final ValueChanged<String> onChanged;
  final VoidCallback onReview;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(children: [
          _PhoneCategory(
            label: 'सभी',
            icon: Icons.contacts_rounded,
            color: blue,
            selected: selected.isEmpty && !reviewSelected,
            onTap: () => onChanged(''),
          ),
          _PhoneCategory(
            label: 'समर्थक',
            icon: Icons.thumb_up_rounded,
            color: green,
            selected: selected == 'supporter',
            onTap: () => onChanged('supporter'),
          ),
          _PhoneCategory(
            label: 'तटस्थ',
            icon: Icons.people_alt_rounded,
            color: orange,
            selected: selected == 'neutral',
            onTap: () => onChanged('neutral'),
          ),
          _PhoneCategory(
            label: 'विरोधी',
            icon: Icons.trending_down_rounded,
            color: rose,
            selected: selected == 'opposite',
            onTap: () => onChanged('opposite'),
          ),
          _PhoneCategory(
            label: 'Review',
            icon: Icons.fact_check_rounded,
            color: purple,
            selected: reviewSelected,
            onTap: onReview,
          ),
        ]),
      );
}

class _PhoneCategory extends StatelessWidget {
  const _PhoneCategory({
    required this.label,
    required this.icon,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(right: 16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
            child: Column(children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: selected ? color : color.withValues(alpha: .11),
                  shape: BoxShape.circle,
                  boxShadow: selected
                      ? [
                          BoxShadow(
                              color: color.withValues(alpha: .22),
                              blurRadius: 12)
                        ]
                      : null,
                ),
                child: Icon(icon, color: selected ? Colors.white : color),
              ),
              const SizedBox(height: 6),
              Text(label,
                  style: TextStyle(
                      color: selected ? navy : muted,
                      fontSize: 11,
                      fontWeight:
                          selected ? FontWeight.w900 : FontWeight.w700)),
            ]),
          ),
        ),
      );
}

class _PhoneContactList extends StatelessWidget {
  const _PhoneContactList({
    required this.result,
    required this.onChanged,
    required this.onPageChanged,
  });

  final VoterPageResult result;
  final VoidCallback onChanged;
  final ValueChanged<int> onPageChanged;

  @override
  Widget build(BuildContext context) {
    final contacts = result.items
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Text('${result.total} मतदाता मिले',
            style: const TextStyle(color: muted, fontSize: 12)),
      ),
      ...contacts.map((voter) => _PhoneContactTile(
            voter: voter,
            onChanged: onChanged,
          )),
      if (result.pages > 1)
        Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            IconButton.outlined(
              onPressed:
                  result.page > 1 ? () => onPageChanged(result.page - 1) : null,
              icon: const Icon(Icons.chevron_left_rounded),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Text('${result.page} / ${result.pages}',
                  style: const TextStyle(
                      color: navy, fontWeight: FontWeight.w900)),
            ),
            IconButton.outlined(
              onPressed: result.page < result.pages
                  ? () => onPageChanged(result.page + 1)
                  : null,
              icon: const Icon(Icons.chevron_right_rounded),
            ),
          ]),
        ),
    ]);
  }
}

class _PhoneContactTile extends StatelessWidget {
  const _PhoneContactTile({required this.voter, required this.onChanged});

  final Map<String, dynamic> voter;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final mobile = '${voter['mobile'] ?? ''}'.trim();
    final village = '${voter['village'] ?? ''}'.trim();
    final ward = voter['ward'] is Map ? '${voter['ward']['number'] ?? ''}' : '';
    final place = [
      if (ward.isNotEmpty) 'वार्ड $ward',
      if (village.isNotEmpty) village,
    ].join(' · ');
    return Material(
      color: Colors.white,
      child: InkWell(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => VoterDetailPage(voter: voter, onChanged: onChanged),
          ),
        ),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: Color(0xffedf0f5))),
          ),
          child: Row(children: [
            _VoterPhoto(photo: voter['photo'], radius: 25),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${voter['name'] ?? '-'}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: navy,
                            fontSize: 15,
                            fontWeight: FontWeight.w900)),
                    const SizedBox(height: 3),
                    Text(
                        mobile.isEmpty
                            ? 'EPIC: ${voter['voterId'] ?? '-'}'
                            : mobile,
                        style: const TextStyle(color: muted, fontSize: 12)),
                    if (place.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(place,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: muted, fontSize: 11)),
                    ],
                    const SizedBox(height: 6),
                    SupportChip(
                        value: '${voter['supportLevel'] ?? 'undecided'}'),
                  ]),
            ),
            IconButton(
              tooltip: 'कॉल करें',
              onPressed:
                  mobile.isEmpty ? null : () => callNumber(context, mobile),
              style: IconButton.styleFrom(
                backgroundColor: const Color(0xffeaf8f0),
                foregroundColor: green,
              ),
              icon: const Icon(Icons.call_rounded, size: 20),
            ),
          ]),
        ),
      ),
    );
  }
}

class _PhoneMessage extends StatelessWidget {
  const _PhoneMessage({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onRetry,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 18),
        child: Column(children: [
          Icon(icon, size: 48, color: blue),
          const SizedBox(height: 12),
          Text(title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: navy, fontSize: 16, fontWeight: FontWeight.w900)),
          const SizedBox(height: 5),
          Text(subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(color: muted, fontSize: 12)),
          const SizedBox(height: 14),
          OutlinedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('फिर कोशिश करें'),
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

class _AlphabetFilterBar extends StatelessWidget {
  const _AlphabetFilterBar({required this.selected, required this.onChanged});

  final String selected;
  final ValueChanged<String> onChanged;

  static const english = <String>[
    'A',
    'B',
    'C',
    'D',
    'E',
    'F',
    'G',
    'H',
    'I',
    'J',
    'K',
    'L',
    'M',
    'N',
    'O',
    'P',
    'Q',
    'R',
    'S',
    'T',
    'U',
    'V',
    'W',
    'X',
    'Y',
    'Z',
  ];

  static const hindi = <String>[
    'अ',
    'आ',
    'इ',
    'ई',
    'उ',
    'ऊ',
    'ए',
    'ऐ',
    'ओ',
    'औ',
    'क',
    'ख',
    'ग',
    'घ',
    'च',
    'छ',
    'ज',
    'झ',
    'ट',
    'ठ',
    'ड',
    'ढ',
    'ण',
    'त',
    'थ',
    'द',
    'ध',
    'न',
    'प',
    'फ',
    'ब',
    'भ',
    'म',
    'य',
    'र',
    'ल',
    'व',
    'श',
    'ष',
    'स',
    'ह',
  ];

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: border),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Icon(Icons.sort_by_alpha_rounded, color: blue, size: 20),
            const SizedBox(width: 8),
            const Expanded(
              child: Text('Name starts with',
                  style: TextStyle(color: navy, fontWeight: FontWeight.w900)),
            ),
            if (selected.isNotEmpty)
              TextButton(
                  onPressed: () => onChanged(''), child: const Text('All')),
          ]),
          const SizedBox(height: 6),
          _LetterScroller(
            letters: const ['', ...english, ...hindi],
            selected: selected,
            onChanged: onChanged,
          ),
        ]),
      );
}

class _LetterScroller extends StatelessWidget {
  const _LetterScroller({
    required this.letters,
    required this.selected,
    required this.onChanged,
  });

  final List<String> letters;
  final String selected;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: letters
              .map((letter) => Padding(
                    padding: const EdgeInsets.only(right: 5),
                    child: ChoiceChip(
                      label: Text(letter.isEmpty ? 'All' : letter),
                      selected: selected == letter,
                      visualDensity: VisualDensity.compact,
                      onSelected: (_) =>
                          onChanged(selected == letter ? '' : letter),
                    ),
                  ))
              .toList(),
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
      required this.onChanged,
      this.onPick});
  final TextEditingController controller;
  final String label;
  final IconData icon;
  final ValueChanged<String> onChanged;
  final VoidCallback? onPick;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 220,
        child: TextField(
          controller: controller,
          onChanged: onChanged,
          decoration: InputDecoration(
            labelText: label,
            prefixIcon: Icon(icon, size: 20),
            suffixIcon: Row(mainAxisSize: MainAxisSize.min, children: [
              if (onPick != null)
                IconButton(
                  tooltip: 'List से चुनें',
                  onPressed: onPick,
                  icon: const Icon(Icons.list_alt_rounded, size: 18),
                ),
              if (controller.text.isNotEmpty)
                IconButton(
                  tooltip: 'साफ करें',
                  onPressed: () {
                    controller.clear();
                    onChanged('');
                  },
                  icon: const Icon(Icons.close, size: 18),
                ),
            ]),
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

class _LocationCorrectionDialog extends StatefulWidget {
  const _LocationCorrectionDialog();

  @override
  State<_LocationCorrectionDialog> createState() =>
      _LocationCorrectionDialogState();
}

class _LocationCorrectionDialogState extends State<_LocationCorrectionDialog> {
  final smartQuery = TextEditingController();
  final sourceAssemblyNumber = TextEditingController();
  final sourceAssemblyName = TextEditingController();
  final sourceGramPanchayat = TextEditingController();
  final sourceVillage = TextEditingController();
  final sourcePartNumber = TextEditingController();

  final newAssemblyNumber = TextEditingController();
  final newAssemblyName = TextEditingController();
  final newGramPanchayat = TextEditingController();
  final newVillage = TextEditingController();
  final newPartNumber = TextEditingController();
  final newTehsil = TextEditingController();

  bool loading = false;
  bool advancedMode = false;
  Timer? previewDebounce;
  int? matched;
  List<Map<String, dynamic>> sample = const [];
  String? error;

  Map<String, String> get source => {
        if (!advancedMode) 'smartQuery': smartQuery.text.trim(),
        'assemblyNumber': sourceAssemblyNumber.text.trim(),
        'assemblyName': sourceAssemblyName.text.trim(),
        'gramPanchayat': sourceGramPanchayat.text.trim(),
        'village': sourceVillage.text.trim(),
        'partNumber': sourcePartNumber.text.trim(),
      }..removeWhere((_, value) => value.isEmpty);

  Map<String, String> get updates => {
        'assemblyNumber': newAssemblyNumber.text.trim(),
        'assemblyName': newAssemblyName.text.trim(),
        'gramPanchayat': newGramPanchayat.text.trim(),
        'village': newVillage.text.trim(),
        'partNumber': newPartNumber.text.trim(),
        'tehsil': newTehsil.text.trim(),
      }..removeWhere((_, value) => value.isEmpty);

  bool get validSource => advancedMode
      ? sourceVillage.text.trim().isNotEmpty && source.length >= 2
      : smartQuery.text.trim().length >= 2 || source.length >= 2;

  void schedulePreview() {
    previewDebounce?.cancel();
    if (!validSource) return;
    previewDebounce = Timer(const Duration(milliseconds: 650), () {
      if (mounted) preview(silent: true);
    });
  }

  Future<void> chooseSourceFromDatabase() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final res = await api.getQuery('/api/members/location-groups', {
        'limit': '300',
      });
      final items = List<Map<String, dynamic>>.from(
        (res['items'] as List? ?? const []).map(
          (item) => Map<String, dynamic>.from(item),
        ),
      );
      if (!mounted) return;
      final selected = await showDialog<Map<String, dynamic>>(
        context: context,
        builder: (_) => _LocationGroupPicker(items: items),
      );
      if (selected == null) return;
      final key = Map<String, dynamic>.from(selected['key'] as Map? ?? {});
      setState(() {
        advancedMode = true;
        sourceAssemblyNumber.text = '${key['assemblyNumber'] ?? ''}';
        sourceAssemblyName.text = '${key['assemblyName'] ?? ''}';
        sourceGramPanchayat.text = '${key['gramPanchayat'] ?? ''}';
        sourceVillage.text = '${key['village'] ?? ''}';
        sourcePartNumber.text = '${key['partNumber'] ?? ''}';
        newAssemblyNumber.text = sourceAssemblyNumber.text;
        newAssemblyName.text = sourceAssemblyName.text;
        newGramPanchayat.text = sourceGramPanchayat.text;
        newVillage.text = sourceVillage.text;
        newPartNumber.text = sourcePartNumber.text;
        matched = null;
      });
    } catch (e) {
      setState(() => error = '$e'.replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> preview({bool silent = false}) async {
    if (!validSource) {
      if (!silent) {
        setState(() => error = advancedMode
            ? 'गाँव अकेला unique नहीं है। Source में गाँव + विधानसभा/पंचायत/भाग भरें।'
            : 'पुरानी जानकारी search में कम से कम 2 अक्षर लिखें।');
      }
      return;
    }
    setState(() {
      loading = true;
      error = null;
      matched = null;
      sample = const [];
    });
    try {
      final res = await api.post('/api/members/bulk-location-correction', {
        'dryRun': true,
        'source': source,
        'updates': updates,
      });
      setState(() {
        matched = res['matched'] as int? ?? 0;
        sample = List<Map<String, dynamic>>.from(
          (res['sample'] as List? ?? const []).map(
            (item) => Map<String, dynamic>.from(item),
          ),
        );
      });
    } catch (e) {
      setState(() => error = '$e'.replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> apply() async {
    if ((matched ?? 0) < 1) return;
    if (updates.isEmpty) {
      setState(() => error = 'Correct values में कम से कम एक field भरें।');
      return;
    }
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Bulk update confirm करें'),
        content: Text(
            '$matched voters update होंगे। यह गाँव को अकेला नहीं, पूरी location key से match करेगा।'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Update')),
        ],
      ),
    );
    if (confirm != true) return;
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final res = await api.post('/api/members/bulk-location-correction', {
        'dryRun': false,
        'source': source,
        'updates': updates,
      });
      if (!mounted) return;
      Navigator.pop(context, true);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(res['noChange'] == true
              ? 'कोई नया बदलाव नहीं मिला।'
              : '${res['updated'] ?? 0} voters location corrected')));
    } catch (e) {
      setState(() => error = '$e'.replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  void dispose() {
    for (final controller in [
      smartQuery,
      sourceAssemblyNumber,
      sourceAssemblyName,
      sourceGramPanchayat,
      sourceVillage,
      sourcePartNumber,
      newAssemblyNumber,
      newAssemblyName,
      newGramPanchayat,
      newVillage,
      newPartNumber,
      newTehsil,
    ]) {
      controller.dispose();
    }
    previewDebounce?.cancel();
    super.dispose();
  }

  Widget field(TextEditingController controller, String label, IconData icon) =>
      SizedBox(
        width: 250,
        child: TextField(
          controller: controller,
          onChanged: (_) => setState(() {
            matched = null;
            if (!advancedMode) schedulePreview();
          }),
          decoration: InputDecoration(labelText: label, prefixIcon: Icon(icon)),
        ),
      );

  Widget sectionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Widget child,
    Color color = blue,
  }) =>
      Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: border),
          boxShadow: const [
            BoxShadow(
                color: Color(0x0c071b4b), blurRadius: 16, offset: Offset(0, 8)),
          ],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: color.withValues(alpha: .10),
                borderRadius: BorderRadius.circular(15),
              ),
              child: Icon(icon, color: color),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: const TextStyle(
                            color: navy,
                            fontSize: 17,
                            fontWeight: FontWeight.w900)),
                    const SizedBox(height: 2),
                    Text(subtitle,
                        style: const TextStyle(
                            color: muted,
                            fontSize: 12,
                            fontWeight: FontWeight.w700)),
                  ]),
            ),
          ]),
          const SizedBox(height: 13),
          child,
        ]),
      );

  int get correctionStep {
    if (matched != null) return 3;
    if (updates.isNotEmpty && validSource) return 2;
    if (source.isNotEmpty) return 1;
    return 0;
  }

  Widget stepBadge(int number, String title) {
    final active = correctionStep >= number - 1;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: active ? softBlue : const Color(0xfff7f9ff),
        borderRadius: BorderRadius.circular(14),
        border:
            Border.all(color: active ? blue.withValues(alpha: .30) : border),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        CircleAvatar(
          radius: 13,
          backgroundColor: active ? blue : const Color(0xffe7edf7),
          child: Text('$number',
              style: TextStyle(
                  color: active ? Colors.white : muted,
                  fontSize: 11,
                  fontWeight: FontWeight.w900)),
        ),
        const SizedBox(width: 7),
        Text(title,
            style: TextStyle(
                color: active ? navy : muted,
                fontWeight: FontWeight.w900,
                fontSize: 12)),
      ]),
    );
  }

  Widget stepHeader(int number, String title, String subtitle, IconData icon) =>
      Padding(
        padding: const EdgeInsets.only(top: 18, bottom: 10),
        child: Row(children: [
          CircleAvatar(
            backgroundColor: softBlue,
            child: Icon(icon, color: blue, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('$number. $title',
                  style: const TextStyle(
                      color: navy, fontSize: 16, fontWeight: FontWeight.w900)),
              const SizedBox(height: 2),
              Text(subtitle,
                  style: const TextStyle(
                      color: muted, fontSize: 12, fontWeight: FontWeight.w700)),
            ]),
          ),
        ]),
      );

  Widget duplicateWarning() {
    final onlyVillage =
        sourceVillage.text.trim().isNotEmpty && source.length < 2;
    if (!onlyVillage) return const SizedBox.shrink();
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xfffff7ed),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: orange.withValues(alpha: .35)),
      ),
      child: const Row(children: [
        Icon(Icons.warning_amber_rounded, color: orange),
        SizedBox(width: 10),
        Expanded(
          child: Text(
            'Safe rule: गाँव या गलत OCR text अकेला unique नहीं है। विधानसभा / पंचायत / भाग में से कम से कम एक और value चुनें।',
            style: TextStyle(color: navy, fontWeight: FontWeight.w800),
          ),
        ),
      ]),
    );
  }

  Widget comparisonTable() {
    const labels = {
      'assemblyNumber': 'विधानसभा संख्या',
      'assemblyName': 'विधानसभा नाम',
      'gramPanchayat': 'ग्राम पंचायत',
      'village': 'गाँव',
      'partNumber': 'भाग / बूथ',
      'tehsil': 'तहसील',
    };
    String oldValue(String key) => source[key] ?? '-';
    String newValue(String key) => updates[key] ?? oldValue(key);
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Old vs New comparison',
            style: TextStyle(color: navy, fontWeight: FontWeight.w900)),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            headingRowHeight: 34,
            dataRowMinHeight: 38,
            dataRowMaxHeight: 46,
            columns: const [
              DataColumn(label: Text('Field')),
              DataColumn(label: Text('Old')),
              DataColumn(label: Text('New')),
            ],
            rows: labels.entries
                .map((entry) => DataRow(cells: [
                      DataCell(Text(entry.value)),
                      DataCell(Text(oldValue(entry.key))),
                      DataCell(Text(newValue(entry.key),
                          style: TextStyle(
                              color: newValue(entry.key) == oldValue(entry.key)
                                  ? muted
                                  : green,
                              fontWeight: FontWeight.w900))),
                    ]))
                .toList(),
          ),
        ),
      ]),
    );
  }

  List<Widget> currentLocationSummary() {
    if (sample.isEmpty) return const [];
    String values(String key) {
      final set = sample
          .map((voter) => '${voter[key] ?? ''}'.trim())
          .where((value) => value.isNotEmpty)
          .toSet()
          .take(4)
          .toList();
      return set.isEmpty ? 'खाली' : set.join(', ');
    }

    return [
      const SizedBox(height: 10),
      const Divider(),
      const Text('अभी database में values',
          style: TextStyle(color: navy, fontWeight: FontWeight.w900)),
      const SizedBox(height: 8),
      Wrap(spacing: 8, runSpacing: 8, children: [
        Chip(label: Text('पंचायत: ${values('gramPanchayat')}')),
        Chip(label: Text('गाँव: ${values('village')}')),
        Chip(label: Text('भाग: ${values('partNumber')}')),
        Chip(label: Text('तहसील: ${values('tehsil')}')),
      ]),
    ];
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        contentPadding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
        actionsPadding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
        titlePadding: const EdgeInsets.fromLTRB(18, 16, 8, 0),
        title: Row(children: [
          const CircleAvatar(
            backgroundColor: softBlue,
            child: Icon(Icons.edit_location_alt_rounded, color: blue),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Bulk Location Fix',
                  style: TextStyle(color: navy, fontWeight: FontWeight.w900)),
              SizedBox(height: 2),
              Text('गलत/अधूरी location को safely सुधारें',
                  style: TextStyle(color: muted, fontSize: 12)),
            ]),
          ),
          IconButton(
            onPressed: loading ? null : () => Navigator.pop(context, false),
            icon: const Icon(Icons.close_rounded),
          ),
        ]),
        content: SizedBox(
          width: 760,
          child: SingleChildScrollView(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(child: stepBadge(1, 'Search')),
                const SizedBox(width: 6),
                Expanded(child: stepBadge(2, 'Correct')),
                const SizedBox(width: 6),
                Expanded(child: stepBadge(3, 'Preview')),
              ]),
              const SizedBox(height: 12),
              sectionCard(
                icon: Icons.search_rounded,
                title: advancedMode
                    ? 'Safe Key से पुरानी location'
                    : 'Smart Fix: पुरानी info खोजें',
                subtitle: advancedMode
                    ? 'जब exact विधानसभा + पंचायत + गाँव + भाग पता हो।'
                    : 'जैसे sahara bheeta / Hier / भीटा 47 लिखें।',
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SegmentedButton<bool>(
                        segments: const [
                          ButtonSegment(
                              value: false,
                              icon: Icon(Icons.auto_fix_high_rounded),
                              label: Text('Smart')),
                          ButtonSegment(
                              value: true,
                              icon: Icon(Icons.vpn_key_rounded),
                              label: Text('Advanced')),
                        ],
                        selected: {advancedMode},
                        onSelectionChanged: (value) => setState(() {
                          advancedMode = value.first;
                          matched = null;
                          sample = const [];
                          error = null;
                        }),
                      ),
                      const SizedBox(height: 12),
                      if (!advancedMode) ...[
                        TextField(
                          controller: smartQuery,
                          onChanged: (_) => setState(() {
                            matched = null;
                            sample = const [];
                            schedulePreview();
                          }),
                          decoration: InputDecoration(
                            prefixIcon: const Icon(Icons.search_rounded),
                            labelText: 'Old/wrong info',
                            hintText: 'sahara bheeta / Hier / भीटा 47',
                            helperText:
                                '2 अक्षर लिखते ही affected voters preview होगा',
                            suffixIcon: smartQuery.text.isEmpty
                                ? null
                                : IconButton(
                                    onPressed: () => setState(() {
                                      smartQuery.clear();
                                      matched = null;
                                      sample = const [];
                                    }),
                                    icon: const Icon(Icons.close_rounded),
                                  ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.all(11),
                          decoration: BoxDecoration(
                            color: const Color(0xfffff7ed),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                                color: orange.withValues(alpha: .25)),
                          ),
                          child: const Row(children: [
                            Icon(Icons.info_outline_rounded, color: orange),
                            SizedBox(width: 9),
                            Expanded(
                              child: Text(
                                'गाँव अकेला unique नहीं होता। ज्यादा result आए तो पंचायत/भाग भी search में लिखें।',
                                style: TextStyle(
                                    color: navy,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 12),
                              ),
                            ),
                          ]),
                        ),
                      ] else ...[
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: FilledButton.icon(
                            onPressed:
                                loading ? null : chooseSourceFromDatabase,
                            icon: const Icon(Icons.dataset_rounded),
                            label: const Text('Database से location चुनें'),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Wrap(spacing: 10, runSpacing: 10, children: [
                          field(sourceAssemblyNumber, 'विधानसभा संख्या',
                              Icons.account_balance_outlined),
                          field(sourceAssemblyName, 'विधानसभा नाम',
                              Icons.account_balance_rounded),
                          field(sourceGramPanchayat, 'ग्राम पंचायत',
                              Icons.holiday_village_outlined),
                          field(sourceVillage, 'गाँव / गलत OCR text *',
                              Icons.location_city_rounded),
                          field(sourcePartNumber, 'भाग / बूथ',
                              Icons.how_to_vote_rounded),
                        ]),
                      ],
                    ]),
              ),
              sectionCard(
                icon: Icons.edit_location_alt_rounded,
                title: 'सही जानकारी भरें',
                subtitle:
                    'सिर्फ वही field भरें जो बदलनी/जोड़नी है; बाकी खाली छोड़ें।',
                color: green,
                child: Wrap(spacing: 10, runSpacing: 10, children: [
                  field(newGramPanchayat, 'नई ग्राम पंचायत',
                      Icons.holiday_village_outlined),
                  field(newVillage, 'नया गाँव', Icons.location_city_rounded),
                  field(newPartNumber, 'नया भाग / बूथ',
                      Icons.how_to_vote_rounded),
                  field(newTehsil, 'नई तहसील / ब्लॉक', Icons.apartment_rounded),
                  field(newAssemblyNumber, 'नई विधानसभा संख्या',
                      Icons.account_balance_outlined),
                  field(newAssemblyName, 'नई विधानसभा नाम',
                      Icons.account_balance_rounded),
                ]),
              ),
              comparisonTable(),
              const SizedBox(height: 14),
              if (error != null)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xfffff1f2),
                    borderRadius: BorderRadius.circular(14),
                    border:
                        Border.all(color: Colors.red.withValues(alpha: .20)),
                  ),
                  child: Text(error!,
                      style: const TextStyle(
                          color: Colors.red, fontWeight: FontWeight.w800)),
                ),
              sectionCard(
                icon: Icons.visibility_rounded,
                title: 'Preview affected voters',
                subtitle: 'Apply से पहले count और sample जरूर confirm करें।',
                color: purple,
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (matched != null) ...[
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xfff7f9ff),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: border),
                          ),
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('$matched voters match हुए',
                                    style: const TextStyle(
                                        color: navy,
                                        fontSize: 16,
                                        fontWeight: FontWeight.w900)),
                                const SizedBox(height: 6),
                                ...sample.take(5).map((voter) => Text(
                                    '• ${voter['name'] ?? '-'} · EPIC ${voter['voterId'] ?? '-'} · घर ${voter['houseNumber'] ?? '-'}',
                                    style: const TextStyle(
                                        color: muted, fontSize: 12))),
                                ...currentLocationSummary(),
                              ]),
                        ),
                      ] else ...[
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xfff7f9ff),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: border),
                          ),
                          child: const Text(
                            'Preview दबाने पर affected voter count और sample यहाँ दिखेंगे।',
                            style: TextStyle(
                                color: muted, fontWeight: FontWeight.w700),
                          ),
                        ),
                      ],
                    ]),
              ),
            ]),
          ),
        ),
        actions: [
          TextButton(
              onPressed: loading ? null : () => Navigator.pop(context, false),
              child: const Text('Close')),
          OutlinedButton.icon(
            onPressed: loading ? null : preview,
            icon: loading
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.visibility_outlined),
            label: const Text('Preview'),
          ),
          FilledButton.icon(
            onPressed:
                loading || matched == null || matched == 0 ? null : apply,
            icon: const Icon(Icons.done_all_rounded),
            label: const Text('Apply correction'),
          ),
        ],
      );
}

class _LocationGroupPicker extends StatefulWidget {
  const _LocationGroupPicker({required this.items});
  final List<Map<String, dynamic>> items;

  @override
  State<_LocationGroupPicker> createState() => _LocationGroupPickerState();
}

class _LocationGroupPickerState extends State<_LocationGroupPicker> {
  String q = '';

  @override
  Widget build(BuildContext context) {
    final query = q.toLowerCase();
    final items = widget.items.where((item) {
      final label = '${item['label'] ?? ''}'.toLowerCase();
      return query.isEmpty || label.contains(query);
    }).toList();
    return AlertDialog(
      title: const Text('Source location चुनें'),
      content: SizedBox(
        width: 620,
        height: 560,
        child: Column(children: [
          TextField(
            onChanged: (value) => setState(() => q = value),
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search_rounded),
              hintText: 'गाँव, पंचायत, विधानसभा या भाग खोजें...',
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: items.isEmpty
                ? const Center(child: Text('कोई location group नहीं मिला'))
                : ListView.separated(
                    itemCount: items.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (_, index) {
                      final item = items[index];
                      final count = item['count'] ?? 0;
                      return InkWell(
                        onTap: () => Navigator.pop(context, item),
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: border),
                          ),
                          child: Row(children: [
                            const CircleAvatar(
                              backgroundColor: softBlue,
                              child:
                                  Icon(Icons.location_on_rounded, color: blue),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('${item['label'] ?? '-'}',
                                        style: const TextStyle(
                                            color: navy,
                                            fontWeight: FontWeight.w900)),
                                    const SizedBox(height: 3),
                                    Text('$count voters',
                                        style: const TextStyle(
                                            color: muted, fontSize: 12)),
                                  ]),
                            ),
                            const Icon(Icons.chevron_right_rounded,
                                color: muted),
                          ]),
                        ),
                      );
                    },
                  ),
          ),
        ]),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close')),
      ],
    );
  }
}

class _PrintOptionsDialog extends StatefulWidget {
  const _PrintOptionsDialog({required this.selectedCount});
  final int selectedCount;

  @override
  State<_PrintOptionsDialog> createState() => _PrintOptionsDialogState();
}

class _PrintOptionsDialogState extends State<_PrintOptionsDialog> {
  static const availableFields = <String, String>{
    'name': 'Name',
    'voterId': 'EPIC',
    'mobile': 'Mobile',
    'altMobile': 'Alt mobile',
    'guardianName': 'Father / Husband',
    'relationType': 'Relation',
    'age': 'Age',
    'gender': 'Gender',
    'houseNumber': 'House No.',
    'address': 'Address',
    'village': 'Village',
    'gramPanchayat': 'Gram Panchayat',
    'tehsil': 'Tehsil',
    'municipality': 'Municipality',
    'caste': 'Caste',
    'subCaste': 'Sub caste',
    'occupation': 'Occupation',
    'education': 'Education',
    'organizationPost': 'Org Post',
    'supportLevel': 'Support',
    'assembly': 'Assembly',
    'partNumber': 'Part / Booth',
    'section': 'Section',
    'booth': 'Booth',
    'ward': 'Ward',
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
    'identity': 'Identity',
    'contact': 'Contact',
    'location': 'Location',
    'profile': 'Profile',
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
  String fieldCategory = 'identity';

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: Text(widget.selectedCount > 0
            ? 'Print ${widget.selectedCount} selected voters'
            : 'Print filtered voters'),
        content: SizedBox(
          width: 650,
          child: SingleChildScrollView(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Printed details',
                  style: TextStyle(fontWeight: FontWeight.w900, color: navy)),
              const SizedBox(height: 8),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: fieldCategoryLabels.entries
                      .map((entry) => Padding(
                            padding: const EdgeInsets.only(right: 7),
                            child: ChoiceChip(
                              label: Text(entry.value),
                              selected: fieldCategory == entry.key,
                              visualDensity: VisualDensity.compact,
                              onSelected: (_) =>
                                  setState(() => fieldCategory = entry.key),
                            ),
                          ))
                      .toList(),
                ),
              ),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xfff7f9fd),
                  border: Border.all(color: border),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: (fieldCategories[fieldCategory] ?? const <String>[])
                      .map((field) => FilterChip(
                            label: Text(availableFields[field] ?? field),
                            selected: selectedFields.contains(field),
                            visualDensity: VisualDensity.compact,
                            onSelected: (selected) => setState(() {
                              if (selected) {
                                selectedFields.add(field);
                              } else {
                                selectedFields.remove(field);
                              }
                            }),
                          ))
                      .toList(),
                ),
              ),
              const SizedBox(height: 8),
              Text('${selectedFields.length} fields selected',
                  style: const TextStyle(color: muted, fontSize: 12)),
              const SizedBox(height: 8),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: selectedFields
                      .take(6)
                      .map((field) => Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: InputChip(
                              label: Text(availableFields[field] ?? field),
                              visualDensity: VisualDensity.compact,
                              onDeleted: () =>
                                  setState(() => selectedFields.remove(field)),
                            ),
                          ))
                      .toList(),
                ),
              ),
              const Divider(height: 28),
              Wrap(spacing: 12, runSpacing: 12, children: [
                SizedBox(
                  width: 150,
                  child: DropdownButtonFormField<int>(
                    initialValue: columns,
                    decoration: const InputDecoration(labelText: 'Cards / row'),
                    items: const [
                      DropdownMenuItem(value: 1, child: Text('1 card')),
                      DropdownMenuItem(value: 2, child: Text('2 cards')),
                      DropdownMenuItem(value: 3, child: Text('3 cards')),
                    ],
                    onChanged: (value) => setState(() => columns = value ?? 2),
                  ),
                ),
                SizedBox(
                  width: 140,
                  child: DropdownButtonFormField<String>(
                    initialValue: paperSize,
                    decoration: const InputDecoration(labelText: 'Paper'),
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
                    decoration: const InputDecoration(labelText: 'Direction'),
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
                  label: const Text('Photo'),
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
              child: const Text('Cancel')),
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
            label: const Text('Print'),
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
                  subtitle:
                      'नाम, पिता/पति का नाम, EPIC, मोबाइल या घर संख्या से खोजें',
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
    final guardian = '${member['guardianName'] ?? ''}'.trim();
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
                        Text(
                            guardian.isEmpty
                                ? 'पिता/पति: उपलब्ध नहीं'
                                : 'पिता/पति: $guardian',
                            style: const TextStyle(
                                color: navy,
                                fontSize: 12,
                                fontWeight: FontWeight.w800)),
                        const SizedBox(height: 4),
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
                          if (mobile.isNotEmpty)
                            _InfoPill(Icons.phone_rounded, mobile),
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
  Widget build(BuildContext context) {
    final mobile = '${voter['mobile'] ?? ''}'.trim();
    final place = [
      '${voter['village'] ?? ''}'.trim(),
      '${voter['gramPanchayat'] ?? ''}'.trim(),
    ].where((value) => value.isNotEmpty).join(', ');
    return Scaffold(
      backgroundColor: const Color(0xfff7f8fb),
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: navy,
        elevation: 0,
        title: const Text('मतदाता प्रोफाइल',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
        centerTitle: true,
        actions: [
          PopupMenuButton<String>(
            onSelected: (action) {
              if (action == 'print') {
                printApiPdf(context,
                    path: '/api/export/members/${voter['_id']}.pdf',
                    jobName: 'मतदाता प्रोफाइल');
              } else if (action == 'edit') {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        VoterEditPage(voter: voter, onSaved: onChanged),
                  ),
                );
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'edit', child: Text('संपादित करें')),
              PopupMenuItem(
                  value: 'print', child: Text('प्रोफाइल प्रिंट करें')),
            ],
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 36),
        children: [
          Center(
            child: ClipOval(
              child: _VoterPhoto(photo: voter['photo'], radius: 55),
            ),
          ),
          const SizedBox(height: 12),
          Text('${voter['name'] ?? '-'}',
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: navy, fontSize: 23, fontWeight: FontWeight.w900)),
          const SizedBox(height: 7),
          Center(
            child:
                SupportChip(value: '${voter['supportLevel'] ?? 'undecided'}'),
          ),
          const SizedBox(height: 20),
          Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
            _ProfileAction(
              icon: Icons.call_rounded,
              label: 'Call',
              color: green,
              onTap: () => callNumber(context, mobile),
            ),
            _ProfileAction(
              icon: Icons.chat_rounded,
              label: 'WhatsApp',
              color: const Color(0xff25d366),
              onTap: () => openWhatsApp(context, mobile,
                  message: 'नमस्ते ${voter['name'] ?? ''}'),
            ),
            _ProfileAction(
              icon: Icons.edit_rounded,
              label: 'Edit',
              color: blue,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      VoterEditPage(voter: voter, onSaved: onChanged),
                ),
              ),
            ),
            _ProfileAction(
              icon: Icons.print_rounded,
              label: 'Print',
              color: purple,
              onTap: () => printApiPdf(context,
                  path: '/api/export/members/${voter['_id']}.pdf',
                  jobName: 'मतदाता प्रोफाइल'),
            ),
          ]),
          const SizedBox(height: 22),
          _ProfileCard(children: [
            _ProfileInfoRow(
                icon: Icons.phone_rounded,
                title: mobile.isEmpty ? 'मोबाइल उपलब्ध नहीं' : mobile,
                subtitle: 'मोबाइल नंबर'),
            _ProfileInfoRow(
                icon: Icons.badge_outlined,
                title: '${voter['voterId'] ?? '-'}',
                subtitle: 'EPIC नंबर'),
            _ProfileInfoRow(
                icon: Icons.location_on_rounded,
                title: place.isEmpty ? '${voter['address'] ?? '-'}' : place,
                subtitle: 'पता / क्षेत्र'),
            _ProfileInfoRow(
                icon: Icons.cake_outlined,
                title:
                    '${voter['age'] ?? '-'} वर्ष · ${voter['gender'] ?? '-'}',
                subtitle: 'उम्र / लिंग'),
            _ProfileInfoRow(
                icon: Icons.family_restroom_rounded,
                title: '${voter['guardianName'] ?? '-'}',
                subtitle: 'पिता / पति का नाम',
                last: true),
          ]),
          const SizedBox(height: 18),
          _ProfileSection(
              title: 'पूरी जानकारी', child: DetailList(voter: voter)),
          const SizedBox(height: 12),
          _ProfileSection(
            title: 'परिवार',
            child: FamilyMembers(voter: voter, onChanged: onChanged),
          ),
          const SizedBox(height: 12),
          _ProfileSection(
            title: 'नोट्स और संपर्क',
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${voter['notes'] ?? 'कोई टिप्पणी नहीं'}',
                  style: const TextStyle(color: muted)),
              const SizedBox(height: 12),
              VoterContactActions(voter: voter),
            ]),
          ),
        ],
      ),
    );
  }
}

class _ProfileAction extends StatelessWidget {
  const _ProfileAction({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Column(children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color.withValues(alpha: .10),
                border: Border.all(color: color.withValues(alpha: .20)),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(height: 6),
            Text(label,
                style: const TextStyle(
                    color: navy, fontSize: 11, fontWeight: FontWeight.w700)),
          ]),
        ),
      );
}

class _ProfileCard extends StatelessWidget {
  const _ProfileCard({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: border),
        ),
        child: Column(children: children),
      );
}

class _ProfileInfoRow extends StatelessWidget {
  const _ProfileInfoRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.last = false,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  final bool last;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          border: last
              ? null
              : const Border(bottom: BorderSide(color: Color(0xffedf0f5))),
        ),
        child: Row(children: [
          Icon(icon, color: muted, size: 21),
          const SizedBox(width: 14),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title,
                  style: const TextStyle(
                      color: navy, fontSize: 14, fontWeight: FontWeight.w800)),
              const SizedBox(height: 2),
              Text(subtitle,
                  style: const TextStyle(color: muted, fontSize: 11)),
            ]),
          ),
        ]),
      );
}

class _ProfileSection extends StatelessWidget {
  const _ProfileSection({required this.title, required this.child});
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: border),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title,
              style: const TextStyle(
                  color: navy, fontSize: 16, fontWeight: FontWeight.w900)),
          const SizedBox(height: 10),
          child,
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
  String gender = '';
  PlatformFile? selectedPhoto;
  bool saving = false;
  String? formError;

  @override
  void initState() {
    super.initState();
    for (final f in [
      'name',
      'guardianName',
      'age',
      'dob',
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
    gender = '${widget.voter?['gender'] ?? ''}';
  }

  Future<void> save() async {
    if (saving) return;
    if (ctrls['name']!.text.trim().isEmpty) {
      showError('मतदाता का नाम जरूरी है।');
      return;
    }
    if (ctrls['voterId']!.text.trim().isEmpty) {
      showError('EPIC / मतदाता आईडी जरूरी है।');
      return;
    }
    setState(() {
      saving = true;
      formError = null;
    });
    final body = <String, dynamic>{
      for (final e in ctrls.entries) e.key: e.value.text.trim(),
      'gender': gender,
      'supportLevel': support,
    };
    try {
      if (selectedPhoto != null) {
        await api.uploadFile(
          widget.voter == null
              ? '/api/members'
              : '/api/members/${widget.voter!['_id']}',
          method: widget.voter == null ? 'POST' : 'PUT',
          filename: selectedPhoto!.name,
          fileField: 'photo',
          filePath: pickedFilePath(selectedPhoto!),
          bytes: pickedFileBytes(selectedPhoto!),
          fields: body.map((key, value) => MapEntry(key, '$value')),
        );
      } else if (widget.voter == null) {
        await api.post('/api/members', body);
      } else {
        await api.put('/api/members/${widget.voter!['_id']}', body);
      }
      widget.onSaved();
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('मतदाता सफलतापूर्वक सहेजा गया')),
      );
    } catch (e) {
      showError('$e'.replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  Future<void> pickPhoto() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      withData: true,
      withReadStream: false,
    );
    if (result == null || !mounted) return;
    final file = result.files.single;
    if (file.size > 10 * 1024 * 1024) {
      showError('Photo 10 MB से छोटी होनी चाहिए।');
      return;
    }
    setState(() => selectedPhoto = file);
  }

  void showError(String message) {
    if (mounted) setState(() => formError = message);
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  void dispose() {
    for (final controller in ctrls.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Widget photoPicker() {
    final bytes = selectedPhoto?.bytes;
    return Center(
      child: InkWell(
        onTap: saving ? null : pickPhoto,
        borderRadius: BorderRadius.circular(70),
        child: Column(children: [
          Stack(clipBehavior: Clip.none, children: [
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xffeef2f8),
                border: Border.all(color: Colors.white, width: 4),
                boxShadow: const [
                  BoxShadow(
                      color: Color(0x17071b4b),
                      blurRadius: 18,
                      offset: Offset(0, 8)),
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child: bytes != null
                  ? Image.memory(bytes, fit: BoxFit.cover)
                  : widget.voter?['photo'] != null
                      ? _VoterPhoto(photo: widget.voter?['photo'], radius: 48)
                      : const Icon(Icons.camera_alt_rounded,
                          color: muted, size: 34),
            ),
            Positioned(
              right: -2,
              bottom: 2,
              child: Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: blue,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 3),
                ),
                child: const Icon(Icons.add_a_photo_rounded,
                    color: Colors.white, size: 15),
              ),
            ),
          ]),
          const SizedBox(height: 8),
          Text(
            selectedPhoto == null
                ? 'फोटो जोड़ें'
                : '${selectedPhoto!.name} · बदलने के लिए tap करें',
            textAlign: TextAlign.center,
            style: const TextStyle(
                color: muted, fontSize: 12, fontWeight: FontWeight.w700),
          ),
        ]),
      ),
    );
  }

  Widget formField(String key,
          {IconData? icon,
          TextInputType? keyboardType,
          bool required = false}) =>
      TextField(
        controller: ctrls[key],
        keyboardType: keyboardType,
        decoration: InputDecoration(
          labelText: '${voterFieldLabel(key)}${required ? ' *' : ''}',
          prefixIcon: icon == null ? null : Icon(icon),
        ),
      );

  Widget genderOption(String value, String label, IconData icon) => Expanded(
        child: InkWell(
          onTap: () => setState(() => gender = value),
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: gender == value ? softBlue : Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: gender == value ? blue : border),
            ),
            child: Column(children: [
              Icon(icon, color: gender == value ? blue : muted),
              const SizedBox(height: 4),
              Text(label,
                  style: TextStyle(
                      color: gender == value ? blue : navy,
                      fontSize: 12,
                      fontWeight: FontWeight.w800)),
            ]),
          ),
        ),
      );

  List<Widget> formChildren() => [
        photoPicker(),
        const SizedBox(height: 18),
        if (formError != null) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xfffff1f3),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: rose.withValues(alpha: .25)),
            ),
            child: Text(formError!,
                style: const TextStyle(
                    color: navy, fontSize: 12, fontWeight: FontWeight.w800)),
          ),
          const SizedBox(height: 12),
        ],
        formField('name', icon: Icons.person_outline, required: true),
        const SizedBox(height: 12),
        formField('guardianName', icon: Icons.family_restroom_outlined),
        const SizedBox(height: 12),
        formField('houseNumber', icon: Icons.home_outlined),
        const SizedBox(height: 12),
        const Text('लिंग',
            style: TextStyle(color: navy, fontWeight: FontWeight.w900)),
        const SizedBox(height: 8),
        Row(children: [
          genderOption('male', 'पुरुष', Icons.male_rounded),
          const SizedBox(width: 9),
          genderOption('female', 'महिला', Icons.female_rounded),
          const SizedBox(width: 9),
          genderOption('other', 'अन्य', Icons.person_outline_rounded),
        ]),
        const SizedBox(height: 12),
        formField('age',
            icon: Icons.cake_outlined,
            keyboardType: TextInputType.number,
            required: true),
        const SizedBox(height: 12),
        formField('dob', icon: Icons.calendar_today_outlined),
        const SizedBox(height: 12),
        formField('mobile',
            icon: Icons.phone_outlined, keyboardType: TextInputType.phone),
        const SizedBox(height: 12),
        formField('altMobile',
            icon: Icons.phone_android_outlined,
            keyboardType: TextInputType.phone),
        const SizedBox(height: 12),
        formField('voterId', icon: Icons.badge_outlined, required: true),
        const SizedBox(height: 12),
        formField('address', icon: Icons.location_on_outlined),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          initialValue: support,
          decoration: const InputDecoration(
              labelText: 'समर्थन स्तर', prefixIcon: Icon(Icons.how_to_vote)),
          items: const [
            DropdownMenuItem(value: 'supporter', child: Text('समर्थक मतदाता')),
            DropdownMenuItem(value: 'opposite', child: Text('विरोधी मतदाता')),
            DropdownMenuItem(value: 'neutral', child: Text('तटस्थ')),
            DropdownMenuItem(value: 'undecided', child: Text('अनिर्णीत')),
          ],
          onChanged: (v) => setState(() => support = v ?? 'undecided'),
        ),
        const SizedBox(height: 12),
        ExpansionTile(
          tilePadding: EdgeInsets.zero,
          title: const Text('अधिक जानकारी',
              style: TextStyle(color: navy, fontWeight: FontWeight.w900)),
          children: [
            formField('occupation', icon: Icons.work_outline),
            const SizedBox(height: 12),
            formField('education', icon: Icons.school_outlined),
            const SizedBox(height: 12),
            formField('notes', icon: Icons.notes_outlined),
            const SizedBox(height: 12),
            formField('ward', icon: Icons.location_city_outlined),
            const SizedBox(height: 12),
            formField('booth', icon: Icons.how_to_vote_outlined),
          ],
        ),
      ];

  @override
  Widget build(BuildContext context) {
    final mobile = MediaQuery.sizeOf(context).width < 700;
    final title =
        widget.voter == null ? 'नया संपर्क जोड़ें' : 'संपर्क संपादित करें';
    final subtitle =
        widget.voter == null ? 'नया मतदाता जोड़ें' : 'मतदाता अपडेट करें';
    final form = ListView(
      padding: EdgeInsets.fromLTRB(16, mobile ? 12 : 18, 16, 22),
      shrinkWrap: !mobile,
      children: formChildren(),
    );
    if (mobile) {
      return Dialog.fullscreen(
        child: Scaffold(
          backgroundColor: const Color(0xfff7f8fb),
          appBar: AppBar(
            backgroundColor: Colors.white,
            foregroundColor: navy,
            elevation: 0,
            leading: IconButton(
              onPressed: saving ? null : () => Navigator.pop(context),
              icon: const Icon(Icons.arrow_back_rounded),
            ),
            title:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title,
                  style: const TextStyle(
                      fontSize: 17, fontWeight: FontWeight.w900)),
              Text(subtitle,
                  style: const TextStyle(color: muted, fontSize: 11)),
            ]),
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 10),
                child: FilledButton.icon(
                  onPressed: saving ? null : save,
                  icon: saving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.save_rounded, size: 18),
                  label: const Text('सहेजें'),
                ),
              )
            ],
          ),
          body: form,
        ),
      );
    }
    return AlertDialog(
      title: Text(title),
      content: SizedBox(width: 520, height: 680, child: form),
      actions: [
        TextButton(
            onPressed: saving ? null : () => Navigator.pop(context),
            child: const Text('रद्द करें')),
        FilledButton.icon(
            onPressed: saving ? null : save,
            icon: saving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.save),
            label: Text(saving ? 'सहेज रहे हैं...' : 'सहेजें')),
      ],
    );
  }
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
