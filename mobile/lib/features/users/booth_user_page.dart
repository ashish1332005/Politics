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
  void refresh() => setState(() {});

  @override
  Widget build(BuildContext context) => FutureBlock<List<dynamic>>(
        load: () => api.list('/api/booths'),
        builder: (booths) => FutureBlock<List<dynamic>>(
          load: () => api.list('/api/auth/users'),
          builder: (users) {
            final boothHeads = users
                .where((u) => u is Map && u['role'] == 'booth')
                .map((u) => Map<String, dynamic>.from(u as Map))
                .toList();
            return AppPage(children: [
              PageHeading(
                title: 'Booth Head Control',
                subtitle: 'Create heads booth-wise and track their voter work.',
                action: FilledButton.icon(
                  onPressed: () => showDialog(
                    context: context,
                    builder: (_) =>
                        BoothUserForm(booths: booths, onSaved: refresh),
                  ),
                  icon: const Icon(Icons.person_add_alt_1_rounded),
                  label: const Text('New booth head'),
                ),
              ),
              _Overview(boothHeads: boothHeads),
              for (final booth in booths)
                _BoothHeadSection(
                  booth: Map<String, dynamic>.from(booth as Map),
                  heads: boothHeads
                      .where(
                          (u) => _idOf(u['assignedBooth']) == '${booth['_id']}')
                      .toList(),
                  booths: booths,
                  onChanged: refresh,
                ),
              if (booths.isEmpty)
                const Panel(
                  title: 'No booths found',
                  child: Text('Create booths first, then assign booth heads.'),
                ),
            ]);
          },
        ),
      );
}

class _Overview extends StatelessWidget {
  const _Overview({required this.boothHeads});

  final List<Map<String, dynamic>> boothHeads;

  @override
  Widget build(BuildContext context) {
    final active = boothHeads.where((u) => u['active'] != false).length;
    final created =
        boothHeads.fold<int>(0, (sum, u) => sum + _stat(u, 'votersCreated'));
    final updated =
        boothHeads.fold<int>(0, (sum, u) => sum + _stat(u, 'votersUpdated'));
    final voters =
        boothHeads.fold<int>(0, (sum, u) => sum + _stat(u, 'boothVoterCount'));
    return Wrap(spacing: 12, runSpacing: 12, children: [
      _MetricCard('Heads', '${boothHeads.length}', Icons.groups_rounded, blue),
      _MetricCard('Active', '$active', Icons.verified_user_rounded, green),
      _MetricCard('Created', '$created', Icons.person_add_alt_rounded, orange),
      _MetricCard('Updated', '$updated', Icons.edit_note_rounded, blue),
      _MetricCard('Booth voters', '$voters', Icons.how_to_vote_rounded, navy),
    ]);
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard(this.label, this.value, this.icon, this.color);

  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 180,
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(label,
                  style: const TextStyle(
                      color: muted, fontWeight: FontWeight.w800)),
              const SizedBox(height: 12),
              Row(children: [
                CircleAvatar(
                  backgroundColor: color.withValues(alpha: 0.12),
                  foregroundColor: color,
                  child: Icon(icon),
                ),
                const SizedBox(width: 12),
                Text(value,
                    style: const TextStyle(
                        fontSize: 24, fontWeight: FontWeight.w900)),
              ]),
            ]),
          ),
        ),
      );
}

class _BoothHeadSection extends StatelessWidget {
  const _BoothHeadSection({
    required this.booth,
    required this.heads,
    required this.booths,
    required this.onChanged,
  });

  final Map<String, dynamic> booth;
  final List<Map<String, dynamic>> heads;
  final List<dynamic> booths;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) => Panel(
        title: 'Booth ${booth['number'] ?? '-'} - ${booth['name'] ?? '-'}',
        child: Column(children: [
          Row(children: [
            Expanded(
              child: Text(
                'Ward ${booth['ward']?['number'] ?? '-'} | ${_number(heads.length)} booth head(s)',
                style: const TextStyle(color: muted),
              ),
            ),
            FilledButton.icon(
              onPressed: () => showDialog(
                context: context,
                builder: (_) => BoothUserForm(
                  booths: booths,
                  initialBoothId: '${booth['_id']}',
                  onSaved: onChanged,
                ),
              ),
              icon: const Icon(Icons.person_add_alt_1_rounded),
              label: const Text('Add head'),
            ),
          ]),
          const Divider(height: 24),
          if (heads.isEmpty)
            const ListTile(
              leading: Icon(Icons.info_outline_rounded),
              title: Text('No booth head assigned'),
              subtitle: Text('Add a head from this booth row.'),
            )
          else
            ...heads.map(
              (u) => _BoothHeadTile(
                user: u,
                booths: booths,
                onChanged: onChanged,
              ),
            ),
        ]),
      );
}

class _BoothHeadTile extends StatelessWidget {
  const _BoothHeadTile({
    required this.user,
    required this.booths,
    required this.onChanged,
  });

  final Map<String, dynamic> user;
  final List<dynamic> booths;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final active = user['active'] != false;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: active ? const Color(0xffe9f8ef) : Colors.red[50],
          foregroundColor: active ? green : Colors.red,
          child: Icon(active ? Icons.person_rounded : Icons.person_off),
        ),
        title: Text('${user['name'] ?? '-'}',
            style: const TextStyle(fontWeight: FontWeight.w900)),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Wrap(spacing: 8, runSpacing: 8, children: [
            _Chip(Icons.mail_outline_rounded, '${user['email'] ?? '-'}'),
            _Chip(Icons.phone_outlined, '${user['phone'] ?? '-'}'),
            _Chip(Icons.person_add_alt_rounded,
                'Created ${_stat(user, 'votersCreated')}'),
            _Chip(Icons.edit_note_rounded,
                'Updated ${_stat(user, 'votersUpdated')}'),
            _Chip(Icons.how_to_vote_rounded,
                'Booth voters ${_stat(user, 'boothVoterCount')}'),
          ]),
        ),
        trailing: Wrap(spacing: 4, children: [
          Switch(
            value: active,
            onChanged: (value) async {
              await api
                  .put('/api/auth/users/${user['_id']}', {'active': value});
              onChanged();
            },
          ),
          IconButton(
            tooltip: 'Work detail',
            onPressed: () => showDialog(
              context: context,
              builder: (_) => BoothHeadWorkDialog(user: user),
            ),
            icon: const Icon(Icons.analytics_outlined),
          ),
          IconButton(
            tooltip: 'Edit',
            onPressed: () => showDialog(
              context: context,
              builder: (_) =>
                  BoothUserForm(user: user, booths: booths, onSaved: onChanged),
            ),
            icon: const Icon(Icons.edit_outlined),
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
        isThreeLine: true,
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip(this.icon, this.label);
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration: BoxDecoration(
          color: const Color(0xfff6f8fc),
          border: Border.all(color: border),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 14, color: muted),
          const SizedBox(width: 5),
          Text(label,
              style:
                  const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
        ]),
      );
}

class BoothUserForm extends StatefulWidget {
  const BoothUserForm({
    super.key,
    this.user,
    required this.booths,
    this.initialBoothId,
    required this.onSaved,
  });

  final Map<String, dynamic>? user;
  final List<dynamic> booths;
  final String? initialBoothId;
  final VoidCallback onSaved;

  @override
  State<BoothUserForm> createState() => _BoothUserFormState();
}

class _BoothUserFormState extends State<BoothUserForm> {
  late final name = TextEditingController(text: widget.user?['name'] ?? '');
  late final email = TextEditingController(text: widget.user?['email'] ?? '');
  late final phone = TextEditingController(text: widget.user?['phone'] ?? '');
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
      setState(() => error = 'Select a booth for this head.');
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
        title: Text(widget.user == null ? 'New booth head' : 'Edit booth head'),
        content: SizedBox(
          width: 560,
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextField(
                  controller: name,
                  decoration: const InputDecoration(labelText: 'Name')),
              const SizedBox(height: 10),
              TextField(
                  controller: email,
                  decoration: const InputDecoration(labelText: 'Email')),
              const SizedBox(height: 10),
              TextField(
                  controller: phone,
                  decoration: const InputDecoration(labelText: 'Mobile')),
              const SizedBox(height: 10),
              TextField(
                controller: password,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: widget.user == null ? 'Password' : 'New password',
                ),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                initialValue: boothId,
                decoration: const InputDecoration(labelText: 'Assigned booth'),
                items: widget.booths
                    .map((b) => Map<String, dynamic>.from(b as Map))
                    .map((b) => DropdownMenuItem<String>(
                          value: '${b['_id']}',
                          child: Text(
                              '${b['number'] ?? '-'} - ${b['name'] ?? '-'}'),
                        ))
                    .toList(),
                onChanged: (value) => setState(() => boothId = value),
              ),
              SwitchListTile(
                value: active,
                onChanged: (value) => setState(() => active = value),
                title: const Text('Active account'),
              ),
              CheckboxListTile(
                value: canPrint,
                onChanged: (value) => setState(() => canPrint = value == true),
                title: const Text('Allow profile print'),
              ),
              CheckboxListTile(
                value: canExport,
                onChanged: (value) => setState(() => canExport = value == true),
                title: const Text('Allow data export'),
              ),
              CheckboxListTile(
                value: canViewMobile,
                onChanged: (value) =>
                    setState(() => canViewMobile = value == true),
                title: const Text('Show full mobile numbers'),
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
            label: Text(saving ? 'Saving...' : 'Save'),
          ),
        ],
      );
}

class BoothHeadWorkDialog extends StatelessWidget {
  const BoothHeadWorkDialog({super.key, required this.user});

  final Map<String, dynamic> user;

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: Text('${user['name'] ?? 'Booth head'} work'),
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
                    _SmallStat(
                        'All activity', _number(stats['totalActivities'])),
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
