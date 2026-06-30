import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/api_client.dart';
import '../../core/theme.dart';
import '../../layout/app_layout.dart';
import '../../widgets/common.dart';

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
              PageHeading(
                title: 'Booth Manager',
                subtitle:
                    'Find a booth, review voters, assign managers, and control access.',
                action: FilledButton.icon(
                  onPressed: booths.isEmpty
                      ? null
                      : () => _openManagerForm(
                            booths: booths,
                            boothId: selectedBoothId,
                          ),
                  icon: const Icon(Icons.person_add_alt_1_rounded),
                  label: const Text('New manager'),
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
        _TinyMetric('Booths', booths, Icons.home_work_rounded, blue),
        _TinyMetric('Managers', heads, Icons.supervisor_account_rounded, green),
        _TinyMetric('Active', activeHeads, Icons.verified_user_rounded, orange),
        _TinyMetric('Mapped voters', voters, Icons.how_to_vote_rounded, navy),
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
      title: 'Find booth',
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
            hintText: 'Booth no, name, ward...',
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
                            Text('${booth['name'] ?? 'Unnamed booth'}',
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
        title: 'Select booth',
        child: ListTile(
          leading: Icon(Icons.info_outline_rounded),
          title: Text('No booth selected'),
        ),
      );
    }
    final boothId = '${booth!['_id']}';
    return Column(children: [
      _Surface(
        title: 'Booth ${booth!['number'] ?? '-'}',
        action: FilledButton.icon(
          onPressed: onManualAdd,
          icon: const Icon(Icons.person_add_alt_1_rounded),
          label: const Text('Add manager'),
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
        title: 'Voters in this booth',
        action: SizedBox(
          width: 250,
          child: TextField(
            controller: voterSearch,
            onChanged: (_) => onVoterSearch(),
            decoration: InputDecoration(
              isDense: true,
              prefixIcon: const Icon(Icons.search_rounded),
              hintText: 'Name, mobile, EPIC...',
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
        child:
            const Text('No manager assigned. Pick a voter below or add one.'),
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
              title: Text('No voters found'),
            );
          }
          return Column(children: [
            Align(
              alignment: Alignment.centerLeft,
              child: Text('Showing ${voters.length} of $total',
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
            label: const Text('Make manager'),
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
  late String? boothId =
      widget.initialBoothId ?? _idOf(widget.user?['assignedBooth']);
  bool active = true;
  bool canPrint = false;
  bool canExport = false;
  bool canViewMobile = false;
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

  Future<void> save() async {
    if (boothId == null || boothId!.isEmpty) {
      setState(() => error = 'Select a booth for this manager.');
      return;
    }
    if (name.text.trim().isEmpty || email.text.trim().isEmpty) {
      setState(() => error = 'Name and email are required.');
      return;
    }
    if (widget.user == null && password.text.length < 6) {
      setState(() => error = 'Password must be at least 6 characters.');
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
      if (mounted) Navigator.pop(context);
    } catch (e) {
      setState(() => error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: Text(widget.user == null
            ? 'Assign booth manager'
            : 'Edit manager access'),
        content: SizedBox(
          width: 620,
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Wrap(spacing: 10, runSpacing: 10, children: [
                SizedBox(
                  width: 290,
                  child: TextField(
                      controller: name,
                      decoration: const InputDecoration(labelText: 'Name')),
                ),
                SizedBox(
                  width: 290,
                  child: TextField(
                      controller: phone,
                      decoration: const InputDecoration(labelText: 'Mobile')),
                ),
                SizedBox(
                  width: 290,
                  child: TextField(
                      controller: email,
                      decoration:
                          const InputDecoration(labelText: 'Login email')),
                ),
                SizedBox(
                  width: 290,
                  child: TextField(
                    controller: password,
                    obscureText: true,
                    decoration: InputDecoration(
                      labelText:
                          widget.user == null ? 'Password' : 'New password',
                    ),
                  ),
                ),
                SizedBox(
                  width: 590,
                  child: DropdownButtonFormField<String>(
                    initialValue: boothId,
                    decoration:
                        const InputDecoration(labelText: 'Assigned booth'),
                    items: widget.booths
                        .map((b) => DropdownMenuItem<String>(
                              value: '${b['_id']}',
                              child: Text(
                                  '${b['number'] ?? '-'} - ${b['name'] ?? '-'}'),
                            ))
                        .toList(),
                    onChanged: (value) => setState(() => boothId = value),
                  ),
                ),
              ]),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xfff7f9fd),
                  border: Border.all(color: border),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(children: [
                  SwitchListTile(
                    dense: true,
                    value: active,
                    onChanged: (value) => setState(() => active = value),
                    title: const Text('Active login'),
                  ),
                  CheckboxListTile(
                    dense: true,
                    value: canViewMobile,
                    onChanged: (value) =>
                        setState(() => canViewMobile = value == true),
                    title: const Text('Can view full mobile numbers'),
                  ),
                  CheckboxListTile(
                    dense: true,
                    value: canPrint,
                    onChanged: (value) =>
                        setState(() => canPrint = value == true),
                    title: const Text('Can print voter profiles'),
                  ),
                  CheckboxListTile(
                    dense: true,
                    value: canExport,
                    onChanged: (value) =>
                        setState(() => canExport = value == true),
                    title: const Text('Can export voter data'),
                  ),
                ]),
              ),
              if (error.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(error, style: const TextStyle(color: Colors.red)),
                ),
            ]),
          ),
        ),
        actions: [
          TextButton(
              onPressed: saving ? null : () => Navigator.pop(context),
              child: const Text('Cancel')),
          FilledButton.icon(
            onPressed: saving ? null : save,
            icon: const Icon(Icons.save_outlined),
            label: Text(saving ? 'Saving...' : 'Save manager'),
          ),
        ],
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
