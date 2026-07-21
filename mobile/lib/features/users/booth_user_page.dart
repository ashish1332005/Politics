import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/api_client.dart';
import '../../core/theme.dart';
import '../../layout/app_layout.dart';
import '../../widgets/common.dart';
import '../../widgets/mobile_components.dart';

class BoothUserPage extends StatefulWidget {
  const BoothUserPage({super.key});

  @override
  State<BoothUserPage> createState() => _BoothUserPageState();
}

class _BoothUserPageState extends State<BoothUserPage> {
  final boothSearch = TextEditingController();
  final voterSearch = TextEditingController();
  String? selectedBoothId;
  String letter = '';
  int refreshKey = 0;

  void refresh() => setState(() => refreshKey++);

  @override
  void dispose() {
    boothSearch.dispose();
    voterSearch.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FutureBlock<List<dynamic>>(
        key: ValueKey('booth-users-$refreshKey'),
        load: () => api.list('/api/booths'),
        builder: (boothsRaw) => FutureBlock<List<dynamic>>(
          load: () => api.list('/api/auth/users'),
          builder: (usersRaw) {
            final booths = boothsRaw
                .whereType<Map>()
                .map((item) => Map<String, dynamic>.from(item))
                .toList();
            final heads = usersRaw
                .whereType<Map>()
                .where((item) => item['role'] == 'booth')
                .map((item) => Map<String, dynamic>.from(item))
                .toList();
            if (selectedBoothId == null && booths.isNotEmpty) {
              selectedBoothId = '${booths.first['_id']}';
            }
            final selectedBooth =
                booths.cast<Map<String, dynamic>?>().firstWhere(
                      (booth) => '${booth?['_id']}' == selectedBoothId,
                      orElse: () => booths.isEmpty ? null : booths.first,
                    );
            final totalVoters = heads.fold<int>(
                0, (sum, user) => sum + _stat(user, 'boothVoterCount'));
            return AppPage(children: [
              PremiumFeatureHero(
                title: 'बूथ मैनेजर',
                subtitle:
                    'बूथ खोजें, मतदाता देखें और सही मैनेजर को सुरक्षित access दें।',
                icon: Icons.manage_accounts_rounded,
                badges: const ['भूमिका आधारित', 'बूथ अनुसार', 'सुरक्षित'],
                action: FilledButton.icon(
                  onPressed: booths.isEmpty
                      ? null
                      : () => _openManagerForm(
                            booths: booths,
                            boothId: selectedBoothId,
                          ),
                  icon: const Icon(Icons.person_add_alt_1_rounded),
                  label: const Text('नया मैनेजर'),
                ),
              ),
              _SummaryStrip(
                booths: booths.length,
                heads: heads.length,
                activeHeads: heads.where((u) => u['active'] != false).length,
                voters: totalVoters,
              ),
              LayoutBuilder(builder: (context, constraints) {
                final wide = constraints.maxWidth >= 980;
                final finder = _BoothFinder(
                  booths: booths,
                  heads: heads,
                  selectedBoothId: selectedBoothId,
                  controller: boothSearch,
                  onChanged: () => setState(() {}),
                  onSelect: (id) => setState(() {
                    selectedBoothId = id;
                    voterSearch.clear();
                    letter = '';
                  }),
                );
                final workspace = _BoothWorkspace(
                  booth: selectedBooth,
                  booths: booths,
                  heads: heads
                      .where((user) =>
                          _idOf(user['assignedBooth']) == selectedBoothId)
                      .toList(),
                  voterSearch: voterSearch,
                  letter: letter,
                  onLetter: (value) => setState(() => letter = value),
                  onVoterSearch: () => setState(() {}),
                  onRefresh: refresh,
                  onAddManager: (candidate) => _openManagerForm(
                    booths: booths,
                    boothId: selectedBoothId,
                    candidate: candidate,
                  ),
                  onManualAdd: () => _openManagerForm(
                    booths: booths,
                    boothId: selectedBoothId,
                  ),
                );
                if (!wide) {
                  return Column(children: [
                    finder,
                    const SizedBox(height: 12),
                    workspace,
                  ]);
                }
                return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(width: 330, child: finder),
                      const SizedBox(width: 14),
                      Expanded(child: workspace),
                    ]);
              }),
            ]);
          },
        ),
      );

  void _openManagerForm({
    required List<Map<String, dynamic>> booths,
    String? boothId,
    Map<String, dynamic>? candidate,
    Map<String, dynamic>? user,
  }) {
    showDialog(
      context: context,
      builder: (_) => BoothUserForm(
        user: user,
        booths: booths,
        initialBoothId: boothId,
        candidate: candidate,
        onSaved: refresh,
      ),
    );
  }
}

class _SummaryStrip extends StatelessWidget {
  const _SummaryStrip({
    required this.booths,
    required this.heads,
    required this.activeHeads,
    required this.voters,
  });

  final int booths;
  final int heads;
  final int activeHeads;
  final int voters;

  @override
  Widget build(BuildContext context) =>
      Wrap(spacing: 10, runSpacing: 10, children: [
        _TinyMetric('बूथ', booths, Icons.home_work_rounded, blue),
        _TinyMetric('मैनेजर', heads, Icons.supervisor_account_rounded, green),
        _TinyMetric('सक्रिय', activeHeads, Icons.verified_user_rounded, orange),
        _TinyMetric('जुड़े मतदाता', voters, Icons.how_to_vote_rounded, navy),
      ]);
}

class _TinyMetric extends StatelessWidget {
  const _TinyMetric(this.label, this.value, this.icon, this.color);

  final String label;
  final int value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        width: 168,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: border),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(width: 9),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: muted, fontSize: 12)),
              Text('$value',
                  style: const TextStyle(
                      color: navy, fontSize: 20, fontWeight: FontWeight.w900)),
            ]),
          ),
        ]),
      );
}

class _BoothFinder extends StatelessWidget {
  const _BoothFinder({
    required this.booths,
    required this.heads,
    required this.selectedBoothId,
    required this.controller,
    required this.onChanged,
    required this.onSelect,
  });

  final List<Map<String, dynamic>> booths;
  final List<Map<String, dynamic>> heads;
  final String? selectedBoothId;
  final TextEditingController controller;
  final VoidCallback onChanged;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    final query = controller.text.trim().toLowerCase();
    final filtered = booths.where((booth) {
      final text =
          '${booth['number'] ?? ''} ${booth['name'] ?? ''} ${booth['area'] ?? ''} ${booth['ward']?['number'] ?? ''}'
              .toLowerCase();
      return query.isEmpty || text.contains(query);
    }).toList();
    return _Surface(
      title: 'बूथ खोजें',
      action: Text('${filtered.length}/${booths.length}',
          style: const TextStyle(color: muted, fontWeight: FontWeight.w800)),
      child: Column(children: [
        TextField(
          controller: controller,
          onChanged: (_) => onChanged(),
          decoration: InputDecoration(
            isDense: true,
            prefixIcon: const Icon(Icons.search_rounded),
            suffixIcon: controller.text.isEmpty
                ? null
                : IconButton(
                    onPressed: () {
                      controller.clear();
                      onChanged();
                    },
                    icon: const Icon(Icons.close_rounded),
                  ),
            hintText: 'बूथ संख्या, नाम, वार्ड या क्षेत्र...',
          ),
        ),
        const SizedBox(height: 10),
        ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 560),
          child: ListView.separated(
            shrinkWrap: true,
            itemCount: filtered.length,
            separatorBuilder: (_, __) => const SizedBox(height: 6),
            itemBuilder: (_, index) {
              final booth = filtered[index];
              final id = '${booth['_id']}';
              final selected = id == selectedBoothId;
              final boothHeads =
                  heads.where((u) => _idOf(u['assignedBooth']) == id).length;
              final voters = heads
                  .where((u) => _idOf(u['assignedBooth']) == id)
                  .fold<int>(
                      0, (sum, user) => sum + _stat(user, 'boothVoterCount'));
              return InkWell(
                onTap: () => onSelect(id),
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
                  decoration: BoxDecoration(
                    color: selected ? const Color(0xffedf4ff) : Colors.white,
                    border: Border.all(color: selected ? blue : border),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(children: [
                    SizedBox(
                      width: 50,
                      child: Text('#${booth['number'] ?? '-'}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              color: selected ? blue : navy,
                              fontWeight: FontWeight.w900)),
                    ),
                    Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('${booth['name'] ?? 'बिना नाम का बूथ'}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    color: navy, fontWeight: FontWeight.w800)),
                            Text(
                                'Ward ${booth['ward']?['number'] ?? '-'} · $boothHeads manager · $voters voters',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    color: muted, fontSize: 12)),
                          ]),
                    ),
                    Icon(Icons.chevron_right_rounded,
                        color: selected ? blue : muted),
                  ]),
                ),
              );
            },
          ),
        ),
      ]),
    );
  }
}

class _BoothWorkspace extends StatelessWidget {
  const _BoothWorkspace({
    required this.booth,
    required this.booths,
    required this.heads,
    required this.voterSearch,
    required this.letter,
    required this.onLetter,
    required this.onVoterSearch,
    required this.onRefresh,
    required this.onAddManager,
    required this.onManualAdd,
  });

  final Map<String, dynamic>? booth;
  final List<Map<String, dynamic>> booths;
  final List<Map<String, dynamic>> heads;
  final TextEditingController voterSearch;
  final String letter;
  final ValueChanged<String> onLetter;
  final VoidCallback onVoterSearch;
  final VoidCallback onRefresh;
  final ValueChanged<Map<String, dynamic>> onAddManager;
  final VoidCallback onManualAdd;

  @override
  Widget build(BuildContext context) {
    if (booth == null) {
      return const _Surface(
        title: 'बूथ चुनें',
        child: ListTile(
          leading: Icon(Icons.info_outline_rounded),
          title: Text('कोई बूथ नहीं चुना गया'),
        ),
      );
    }
    final boothId = '${booth!['_id']}';
    return Column(children: [
      _Surface(
        title: 'बूथ ${booth!['number'] ?? '-'}',
        action: FilledButton.icon(
          onPressed: onManualAdd,
          icon: const Icon(Icons.person_add_alt_1_rounded),
          label: const Text('मैनेजर जोड़ें'),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('${booth!['name'] ?? '-'}',
              style: const TextStyle(
                  color: navy, fontSize: 18, fontWeight: FontWeight.w900)),
          const SizedBox(height: 4),
          Wrap(spacing: 8, runSpacing: 8, children: [
            _Pill(
                Icons.map_rounded, 'Ward ${booth!['ward']?['number'] ?? '-'}'),
            _Pill(Icons.location_on_outlined,
                '${booth!['area'] ?? booth!['address'] ?? 'No area'}'),
            _Pill(Icons.supervisor_account_rounded, '${heads.length} manager'),
          ]),
          const SizedBox(height: 12),
          _HeadGrid(
            heads: heads,
            booths: booths,
            boothId: boothId,
            onChanged: onRefresh,
          ),
        ]),
      ),
      const SizedBox(height: 12),
      _Surface(
        title: 'इस बूथ के मतदाता',
        action: SizedBox(
          width: 250,
          child: TextField(
            controller: voterSearch,
            onChanged: (_) => onVoterSearch(),
            decoration: InputDecoration(
              isDense: true,
              prefixIcon: const Icon(Icons.search_rounded),
              hintText: 'नाम, मोबाइल या EPIC खोजें...',
              suffixIcon: voterSearch.text.isEmpty
                  ? null
                  : IconButton(
                      onPressed: () {
                        voterSearch.clear();
                        onVoterSearch();
                      },
                      icon: const Icon(Icons.close_rounded),
                    ),
            ),
          ),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _AlphabetBar(selected: letter, onSelected: onLetter),
          const SizedBox(height: 10),
          _BoothVoterList(
            boothId: boothId,
            query: voterSearch.text.trim(),
            letter: letter,
            onMakeManager: onAddManager,
          ),
        ]),
      ),
    ]);
  }
}

class _HeadGrid extends StatelessWidget {
  const _HeadGrid({
    required this.heads,
    required this.booths,
    required this.boothId,
    required this.onChanged,
  });

  final List<Map<String, dynamic>> heads;
  final List<Map<String, dynamic>> booths;
  final String boothId;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    if (heads.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xfff7f9fd),
          border: Border.all(color: border),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Text(
            'अभी मैनेजर नहीं है। नीचे से मतदाता चुनें या नया जोड़ें।'),
      );
    }
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: heads
          .map((user) => SizedBox(
                width: 320,
                child: _ManagerCard(
                  user: user,
                  booths: booths,
                  boothId: boothId,
                  onChanged: onChanged,
                ),
              ))
          .toList(),
    );
  }
}

class _ManagerCard extends StatelessWidget {
  const _ManagerCard({
    required this.user,
    required this.booths,
    required this.boothId,
    required this.onChanged,
  });

  final Map<String, dynamic> user;
  final List<Map<String, dynamic>> booths;
  final String boothId;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final active = user['active'] != false;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: active ? const Color(0xffcdebd8) : border),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: active ? const Color(0xffe9f8ef) : Colors.red[50],
            foregroundColor: active ? green : Colors.red,
            child: Icon(active ? Icons.person_rounded : Icons.person_off),
          ),
          const SizedBox(width: 9),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${user['name'] ?? '-'}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      color: navy, fontWeight: FontWeight.w900)),
              Text('${user['email'] ?? '-'}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: muted, fontSize: 12)),
            ]),
          ),
          Switch(
            value: active,
            onChanged: (value) async {
              await api
                  .put('/api/auth/users/${user['_id']}', {'active': value});
              onChanged();
            },
          ),
        ]),
        const SizedBox(height: 10),
        Wrap(spacing: 6, runSpacing: 6, children: [
          _Pill(Icons.call_outlined, '${user['phone'] ?? '-'}'),
          _Pill(Icons.person_add_alt_rounded,
              'Created ${_stat(user, 'votersCreated')}'),
          _Pill(Icons.edit_note_rounded,
              'Updated ${_stat(user, 'votersUpdated')}'),
          _Pill(Icons.how_to_vote_rounded,
              'Voters ${_stat(user, 'boothVoterCount')}'),
        ]),
        const Divider(height: 18),
        Row(mainAxisAlignment: MainAxisAlignment.end, children: [
          IconButton(
            tooltip: 'Work detail',
            onPressed: () => showDialog(
              context: context,
              builder: (_) => BoothHeadWorkDialog(user: user),
            ),
            icon: const Icon(Icons.analytics_outlined),
          ),
          IconButton(
            tooltip: 'Edit access',
            onPressed: () => showDialog(
              context: context,
              builder: (_) => BoothUserForm(
                user: user,
                booths: booths,
                initialBoothId: boothId,
                onSaved: onChanged,
              ),
            ),
            icon: const Icon(Icons.tune_rounded),
          ),
          IconButton(
            tooltip: 'Reset password',
            onPressed: () => showDialog(
              context: context,
              builder: (_) => ResetPasswordDialog(userId: '${user['_id']}'),
            ),
            icon: const Icon(Icons.password_rounded),
          ),
        ]),
      ]),
    );
  }
}

class _BoothVoterList extends StatelessWidget {
  const _BoothVoterList({
    required this.boothId,
    required this.query,
    required this.letter,
    required this.onMakeManager,
  });

  final String boothId;
  final String query;
  final String letter;
  final ValueChanged<Map<String, dynamic>> onMakeManager;

  @override
  Widget build(BuildContext context) => FutureBlock<Map<String, dynamic>>(
        key: ValueKey('$boothId-$query-$letter'),
        load: () => api.getQuery('/api/members', {
          'booth': boothId,
          'q': query,
          'letter': letter,
          if (letter.isNotEmpty) 'qMode': 'name',
          'paged': 'true',
          'page': '1',
          'limit': '60',
        }),
        builder: (data) {
          final voters = List<Map<String, dynamic>>.from(
            (data['items'] as List? ?? [])
                .map((item) => Map<String, dynamic>.from(item)),
          );
          final total = _number(data['total']);
          if (voters.isEmpty) {
            return const ListTile(
              leading: Icon(Icons.search_off_rounded),
              title: Text('कोई मतदाता नहीं मिला'),
            );
          }
          return Column(children: [
            Align(
              alignment: Alignment.centerLeft,
              child: Text('$total में से ${voters.length} दिख रहे हैं',
                  style: const TextStyle(color: muted, fontSize: 12)),
            ),
            const SizedBox(height: 6),
            ...voters.map((voter) => _VoterManagerRow(
                  voter: voter,
                  onMakeManager: () => onMakeManager(voter),
                )),
          ]);
        },
      );
}

class _VoterManagerRow extends StatelessWidget {
  const _VoterManagerRow({required this.voter, required this.onMakeManager});

  final Map<String, dynamic> voter;
  final VoidCallback onMakeManager;

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: border),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(children: [
          CircleAvatar(
            radius: 17,
            backgroundColor: const Color(0xffedf4ff),
            child: Text(_initials('${voter['name'] ?? ''}'),
                style:
                    const TextStyle(color: blue, fontWeight: FontWeight.w900)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${voter['name'] ?? '-'} ${voter['surname'] ?? ''}'.trim(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      color: navy, fontWeight: FontWeight.w900)),
              Text(
                  'EPIC ${voter['voterId'] ?? '-'} · ${voter['mobile'] ?? '-'} · House ${voter['houseNumber'] ?? '-'}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: muted, fontSize: 12)),
            ]),
          ),
          const SizedBox(width: 8),
          OutlinedButton.icon(
            onPressed: onMakeManager,
            icon: const Icon(Icons.admin_panel_settings_outlined, size: 18),
            label: const Text('मैनेजर बनाएं'),
          ),
        ]),
      );
}

class _AlphabetBar extends StatelessWidget {
  const _AlphabetBar({required this.selected, required this.onSelected});

  final String selected;
  final ValueChanged<String> onSelected;

  static const letters = [
    '',
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
    'अ',
    'आ',
    'इ',
    'क',
    'ख',
    'ग',
    'च',
    'ज',
    'ट',
    'ड',
    'त',
    'द',
    'न',
    'प',
    'ब',
    'म',
    'य',
    'र',
    'ल',
    'व',
    'स',
    'ह',
  ];

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: letters
              .map((item) => Padding(
                    padding: const EdgeInsets.only(right: 5),
                    child: ChoiceChip(
                      label: Text(item.isEmpty ? 'All' : item),
                      selected: selected == item,
                      onSelected: (_) => onSelected(item),
                      visualDensity: VisualDensity.compact,
                    ),
                  ))
              .toList(),
        ),
      );
}

class _Pill extends StatelessWidget {
  const _Pill(this.icon, this.label);
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          color: const Color(0xfff6f8fc),
          border: Border.all(color: border),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 13, color: muted),
          const SizedBox(width: 4),
          Text(label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  color: muted, fontSize: 11, fontWeight: FontWeight.w800)),
        ]),
      );
}

class _Surface extends StatelessWidget {
  const _Surface({required this.title, required this.child, this.action});

  final String title;
  final Widget child;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: border),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(
              child: Text(title,
                  style: const TextStyle(
                      color: navy, fontSize: 16, fontWeight: FontWeight.w900)),
            ),
            if (action != null) action!,
          ]),
          const SizedBox(height: 12),
          child,
        ]),
      );
}

class BoothUserForm extends StatefulWidget {
  const BoothUserForm({
    super.key,
    this.user,
    required this.booths,
    this.initialBoothId,
    this.candidate,
    required this.onSaved,
  });

  final Map<String, dynamic>? user;
  final List<Map<String, dynamic>> booths;
  final String? initialBoothId;
  final Map<String, dynamic>? candidate;
  final VoidCallback onSaved;

  @override
  State<BoothUserForm> createState() => _BoothUserFormState();
}

class _BoothUserFormState extends State<BoothUserForm> {
  late final name = TextEditingController(
      text: widget.user?['name'] ??
          [widget.candidate?['name'], widget.candidate?['surname']]
              .where((part) => '${part ?? ''}'.trim().isNotEmpty)
              .join(' '));
  late final email = TextEditingController(
      text: widget.user?['email'] ?? _candidateEmail(widget.candidate));
  late final phone = TextEditingController(
      text: widget.user?['phone'] ?? '${widget.candidate?['mobile'] ?? ''}');
  final password = TextEditingController();
  final assignedBoothSearch = TextEditingController();
  late String? boothId =
      widget.initialBoothId ?? _idOf(widget.user?['assignedBooth']);
  bool active = true;
  bool canPrint = false;
  bool canExport = false;
  bool canViewMobile = false;
  bool showPassword = false;
  bool saving = false;
  String error = '';

  @override
  void initState() {
    super.initState();
    final permissions = widget.user?['permissions'] as Map?;
    active = widget.user?['active'] != false;
    canPrint = permissions?['canPrintProfiles'] == true;
    canExport = permissions?['canExportData'] == true;
    canViewMobile = permissions?['canViewFullMobile'] == true;
  }

  @override
  void dispose() {
    name.dispose();
    email.dispose();
    phone.dispose();
    password.dispose();
    assignedBoothSearch.dispose();
    super.dispose();
  }

  Future<void> save() async {
    if (boothId == null || boothId!.isEmpty) {
      setState(() => error = 'इस मैनेजर के लिए बूथ चुनना जरूरी है।');
      return;
    }
    if (name.text.trim().isEmpty || email.text.trim().isEmpty) {
      setState(() => error = 'नाम और लॉगिन ईमेल भरना जरूरी है।');
      return;
    }
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email.text.trim())) {
      setState(() => error = 'सही लॉगिन ईमेल लिखें।');
      return;
    }
    if (widget.user == null && password.text.length < 6) {
      setState(() => error = 'पासवर्ड कम-से-कम 6 अक्षर का होना चाहिए।');
      return;
    }
    setState(() {
      saving = true;
      error = '';
    });
    try {
      final body = <String, dynamic>{
        'name': name.text.trim(),
        'email': email.text.trim(),
        'phone': phone.text.trim(),
        'role': 'booth',
        'assignedBooth': boothId,
        'active': active,
        'permissions': {
          'canPrintProfiles': canPrint,
          'canExportData': canExport,
          'canViewFullMobile': canViewMobile,
        },
      };
      if (password.text.isNotEmpty) body['password'] = password.text;
      if (widget.user == null) {
        await api.post('/api/auth/users', body);
      } else {
        await api.put('/api/auth/users/${widget.user!['_id']}', body);
      }
      widget.onSaved();
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(widget.user == null
              ? 'बूथ मैनेजर सफलतापूर्वक बनाया गया।'
              : 'मैनेजर की जानकारी अपडेट हो गई।'),
          behavior: SnackBarBehavior.floating,
        ));
      }
    } catch (e) {
      setState(() => error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isNew = widget.user == null;
    final query = assignedBoothSearch.text.trim().toLowerCase();
    final filteredBooths = widget.booths.where((booth) {
      if (query.isEmpty || '${booth['_id']}' == boothId) return true;
      final ward = booth['ward'] is Map ? booth['ward'] as Map : const {};
      return '${booth['number'] ?? ''} ${booth['name'] ?? ''} '
              '${booth['area'] ?? ''} ${ward['number'] ?? ''}'
          .toLowerCase()
          .contains(query);
    }).toList();

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 20),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 700, maxHeight: 780),
        child: Column(children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                  colors: [Color(0xff0b45c6), Color(0xff1672f8)]),
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Row(children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: .16),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: const Icon(Icons.manage_accounts_rounded,
                    color: Colors.white),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isNew
                            ? 'नया बूथ मैनेजर बनाएं'
                            : 'मैनेजर की जानकारी बदलें',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 19,
                            fontWeight: FontWeight.w900),
                      ),
                      const SizedBox(height: 3),
                      const Text(
                        'लॉगिन बनाएं, बूथ चुनें और जरूरी अनुमति तय करें।',
                        style: TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                    ]),
              ),
              IconButton(
                tooltip: 'बंद करें',
                onPressed: saving ? null : () => Navigator.pop(context),
                icon: const Icon(Icons.close_rounded, color: Colors.white),
              ),
            ]),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(children: [
                _ManagerFormSection(
                  step: '1',
                  title: 'मैनेजर और लॉगिन',
                  subtitle: 'मैनेजर की पहचान और ऐप में लॉगिन की जानकारी।',
                  child: Column(children: [
                    TextField(
                      controller: name,
                      enabled: !saving,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: 'मैनेजर का पूरा नाम *',
                        prefixIcon: Icon(Icons.person_outline_rounded),
                      ),
                    ),
                    const SizedBox(height: 11),
                    TextField(
                      controller: phone,
                      enabled: !saving,
                      keyboardType: TextInputType.phone,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: 'मोबाइल नंबर',
                        prefixIcon: Icon(Icons.phone_outlined),
                      ),
                    ),
                    const SizedBox(height: 11),
                    TextField(
                      controller: email,
                      enabled: !saving,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      autocorrect: false,
                      decoration: const InputDecoration(
                        labelText: 'लॉगिन ईमेल *',
                        prefixIcon: Icon(Icons.alternate_email_rounded),
                        helperText: 'मैनेजर इसी ईमेल से ऐप में लॉगिन करेगा',
                      ),
                    ),
                    const SizedBox(height: 11),
                    TextField(
                      controller: password,
                      enabled: !saving,
                      obscureText: !showPassword,
                      decoration: InputDecoration(
                        labelText:
                            isNew ? 'पासवर्ड *' : 'नया पासवर्ड (वैकल्पिक)',
                        prefixIcon: const Icon(Icons.lock_outline_rounded),
                        helperText: isNew
                            ? 'कम-से-कम 6 अक्षर रखें'
                            : 'खाली छोड़ने पर पुराना पासवर्ड रहेगा',
                        suffixIcon: IconButton(
                          onPressed: () =>
                              setState(() => showPassword = !showPassword),
                          icon: Icon(showPassword
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined),
                        ),
                      ),
                    ),
                  ]),
                ),
                const SizedBox(height: 12),
                _ManagerFormSection(
                  step: '2',
                  title: 'बूथ चुनें',
                  subtitle: 'मैनेजर केवल चुने हुए बूथ का डेटा संभालेगा।',
                  child: Column(children: [
                    TextField(
                      controller: assignedBoothSearch,
                      enabled: !saving,
                      onChanged: (_) => setState(() {}),
                      decoration: InputDecoration(
                        labelText: 'बूथ खोजें',
                        hintText: 'संख्या, नाम, वार्ड या क्षेत्र',
                        prefixIcon: const Icon(Icons.search_rounded),
                        suffixIcon: query.isEmpty
                            ? null
                            : IconButton(
                                onPressed: () {
                                  assignedBoothSearch.clear();
                                  setState(() {});
                                },
                                icon: const Icon(Icons.close_rounded),
                              ),
                      ),
                    ),
                    const SizedBox(height: 11),
                    DropdownButtonFormField<String>(
                      initialValue: boothId,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'बूथ *',
                        prefixIcon: Icon(Icons.how_to_vote_rounded),
                      ),
                      items: filteredBooths.map((booth) {
                        final ward = booth['ward'] is Map
                            ? booth['ward'] as Map
                            : const {};
                        return DropdownMenuItem<String>(
                          value: '${booth['_id']}',
                          child: Text(
                            'बूथ ${booth['number'] ?? '-'} · ${booth['name'] ?? '-'} · वार्ड ${ward['number'] ?? '-'}',
                            overflow: TextOverflow.ellipsis,
                          ),
                        );
                      }).toList(),
                      onChanged: saving
                          ? null
                          : (value) => setState(() => boothId = value),
                    ),
                    if (filteredBooths.isEmpty)
                      const Padding(
                        padding: EdgeInsets.only(top: 9),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text('खोज से कोई बूथ नहीं मिला।',
                              style: TextStyle(color: rose, fontSize: 12)),
                        ),
                      ),
                  ]),
                ),
                const SizedBox(height: 12),
                _ManagerFormSection(
                  step: '3',
                  title: 'पहुँच और अनुमति',
                  subtitle: 'सुरक्षा के लिए केवल जरूरी अनुमति चालू करें।',
                  child: Column(children: [
                    _PermissionSwitch(
                      icon: Icons.login_rounded,
                      title: 'लॉगिन सक्रिय रखें',
                      subtitle: 'बंद होने पर मैनेजर लॉगिन नहीं कर पाएगा',
                      value: active,
                      onChanged: saving
                          ? null
                          : (value) => setState(() => active = value),
                    ),
                    _PermissionSwitch(
                      icon: Icons.phone_android_rounded,
                      title: 'पूरा मोबाइल नंबर देखें',
                      subtitle: 'मतदाताओं के पूरे नंबर दिखाई देंगे',
                      value: canViewMobile,
                      onChanged: saving
                          ? null
                          : (value) => setState(() => canViewMobile = value),
                    ),
                    _PermissionSwitch(
                      icon: Icons.print_outlined,
                      title: 'मतदाता प्रोफ़ाइल प्रिंट करें',
                      subtitle: 'मैनेजर मतदाता प्रोफ़ाइल PDF बना सकेगा',
                      value: canPrint,
                      onChanged: saving
                          ? null
                          : (value) => setState(() => canPrint = value),
                    ),
                    _PermissionSwitch(
                      icon: Icons.file_download_outlined,
                      title: 'मतदाता डेटा एक्सपोर्ट करें',
                      subtitle: 'Excel/CSV एक्सपोर्ट की अनुमति मिलेगी',
                      value: canExport,
                      onChanged: saving
                          ? null
                          : (value) => setState(() => canExport = value),
                    ),
                  ]),
                ),
                if (error.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xffffeeee),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(children: [
                      const Icon(Icons.error_outline_rounded,
                          color: Color(0xffb42318)),
                      const SizedBox(width: 9),
                      Expanded(
                        child: Text(error,
                            style: const TextStyle(
                                color: Color(0xffb42318),
                                fontWeight: FontWeight.w700)),
                      ),
                    ]),
                  ),
                ],
              ]),
            ),
          ),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: const BoxDecoration(
              color: Color(0xfff8faff),
              border: Border(top: BorderSide(color: border)),
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
            ),
            child: Row(children: [
              TextButton(
                onPressed: saving ? null : () => Navigator.pop(context),
                child: const Text('रद्द करें'),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: SizedBox(
                  height: 50,
                  child: FilledButton.icon(
                    onPressed: saving ? null : save,
                    icon: saving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.check_circle_rounded),
                    label: Text(saving
                        ? 'सहेजा जा रहा है...'
                        : isNew
                            ? 'मैनेजर बनाएं'
                            : 'बदलाव सहेजें'),
                  ),
                ),
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}

class _ManagerFormSection extends StatelessWidget {
  const _ManagerFormSection({
    required this.step,
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final String step;
  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xfff8faff),
          border: Border.all(color: border),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            CircleAvatar(
              radius: 16,
              backgroundColor: blue,
              child: Text(step,
                  style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w900)),
            ),
            const SizedBox(width: 9),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: const TextStyle(
                            color: navy, fontWeight: FontWeight.w900)),
                    Text(subtitle,
                        style: const TextStyle(color: muted, fontSize: 11)),
                  ]),
            ),
          ]),
          const SizedBox(height: 13),
          child,
        ]),
      );
}

class _PermissionSwitch extends StatelessWidget {
  const _PermissionSwitch({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: value ? const Color(0xffbed3ff) : border),
          borderRadius: BorderRadius.circular(12),
        ),
        child: SwitchListTile.adaptive(
          contentPadding: const EdgeInsets.symmetric(horizontal: 11),
          secondary: Icon(icon, color: value ? blue : muted),
          title: Text(title,
              style: const TextStyle(
                  color: navy, fontSize: 13, fontWeight: FontWeight.w800)),
          subtitle: Text(subtitle,
              style: const TextStyle(color: muted, fontSize: 10)),
          value: value,
          onChanged: onChanged,
        ),
      );
}

class BoothHeadWorkDialog extends StatelessWidget {
  const BoothHeadWorkDialog({super.key, required this.user});

  final Map<String, dynamic> user;

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: Text('${user['name'] ?? 'Manager'} work'),
        content: SizedBox(
          width: 560,
          child: FutureBlock<Map<String, dynamic>>(
            load: () => api.get('/api/auth/users/${user['_id']}/work-summary'),
            builder: (data) {
              final stats = Map<String, dynamic>.from(data['stats'] as Map);
              final activities = data['recentActivities'] as List? ?? const [];
              return SingleChildScrollView(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Wrap(spacing: 10, runSpacing: 10, children: [
                    _SmallStat('Created', _number(stats['votersCreated'])),
                    _SmallStat('Updated', _number(stats['votersUpdated'])),
                    _SmallStat('Deleted', _number(stats['votersDeleted'])),
                    _SmallStat('Activity', _number(stats['totalActivities'])),
                    _SmallStat(
                        'Booth voters', _number(stats['boothVoterCount'])),
                  ]),
                  const Divider(height: 28),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text('Recent activity',
                        style: Theme.of(context).textTheme.titleMedium),
                  ),
                  const SizedBox(height: 8),
                  if (activities.isEmpty)
                    const ListTile(title: Text('No activity recorded yet.'))
                  else
                    ...activities.take(20).map((a) {
                      final row = Map<String, dynamic>.from(a as Map);
                      return ListTile(
                        dense: true,
                        leading: const Icon(Icons.history_rounded),
                        title: Text('${row['action'] ?? '-'}'),
                        subtitle: Text(_formatDate(row['createdAt'])),
                      );
                    }),
                ]),
              );
            },
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close')),
        ],
      );
}

class _SmallStat extends StatelessWidget {
  const _SmallStat(this.label, this.value);
  final String label;
  final int value;

  @override
  Widget build(BuildContext context) => Container(
        width: 150,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(color: border),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: const TextStyle(color: muted, fontSize: 12)),
          const SizedBox(height: 6),
          Text('$value',
              style:
                  const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
        ]),
      );
}

class ResetPasswordDialog extends StatefulWidget {
  const ResetPasswordDialog({super.key, required this.userId});
  final String userId;

  @override
  State<ResetPasswordDialog> createState() => _ResetPasswordDialogState();
}

class _ResetPasswordDialogState extends State<ResetPasswordDialog> {
  final password = TextEditingController();
  String error = '';

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('Reset password'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(
              controller: password,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'New password')),
          if (error.isNotEmpty)
            Text(error, style: const TextStyle(color: Colors.red)),
        ]),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              if (password.text.length < 6) {
                setState(
                    () => error = 'Password must be at least 6 characters.');
                return;
              }
              await api.put('/api/auth/users/${widget.userId}',
                  {'password': password.text});
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('Reset'),
          ),
        ],
      );
}

String? _idOf(dynamic value) {
  if (value == null) return null;
  if (value is Map) return '${value['_id'] ?? ''}';
  return '$value';
}

int _stat(Map<String, dynamic> user, String key) =>
    _number((user['workStats'] as Map?)?[key]);

int _number(dynamic value) =>
    value is num ? value.toInt() : int.tryParse('$value') ?? 0;

String _formatDate(dynamic raw) {
  final date = DateTime.tryParse('${raw ?? ''}');
  if (date == null) return '-';
  return DateFormat('dd MMM yyyy, hh:mm a').format(date.toLocal());
}

String _initials(String value) {
  final text = value.trim();
  if (text.isEmpty) return '?';
  return text.characters.first.toUpperCase();
}

String _candidateEmail(Map<String, dynamic>? candidate) {
  if (candidate == null) return '';
  final voterId = '${candidate['voterId'] ?? ''}'.trim().toLowerCase();
  if (voterId.isNotEmpty) return '$voterId@booth.local';
  final mobile = '${candidate['mobile'] ?? ''}'.replaceAll(RegExp(r'\D'), '');
  if (mobile.isNotEmpty) return '$mobile@booth.local';
  return '';
}
