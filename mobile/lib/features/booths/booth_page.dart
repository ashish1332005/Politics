import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../core/theme.dart';
import '../../layout/app_layout.dart';
import '../../widgets/common.dart';
import '../../widgets/mobile_components.dart';

class BoothPage extends StatefulWidget {
  const BoothPage({super.key});

  @override
  State<BoothPage> createState() => _BoothPageState();
}

class _BoothPageState extends State<BoothPage> {
  final search = TextEditingController();

  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FutureBlock<List<dynamic>>(
        load: () => api.list('/api/booths'),
        builder: (items) => FutureBlock<List<dynamic>>(
          load: () => api.list('/api/auth/users'),
          builder: (usersRaw) {
            final booths = items
                .whereType<Map>()
                .map((item) => Map<String, dynamic>.from(item))
                .toList();
            final managers = usersRaw
                .whereType<Map>()
                .where((user) => user['role'] == 'booth')
                .map((item) => Map<String, dynamic>.from(item))
                .toList();
            final query = search.text.toLowerCase().trim();
            final filtered = booths.where((booth) {
              final ward =
                  booth['ward'] is Map ? booth['ward'] as Map : const {};
              final haystack =
                  '${booth['number'] ?? ''} ${booth['name'] ?? ''} ${booth['area'] ?? ''} ${booth['address'] ?? ''} ${ward['number'] ?? ''}'
                      .toLowerCase();
              return query.isEmpty || haystack.contains(query);
            }).toList();
            final activeManagers =
                managers.where((user) => user['active'] != false).length;
            final voterCount = managers.fold<int>(
                0, (sum, user) => sum + _boothStat(user, 'boothVoterCount'));
            return AppPage(children: [
              PremiumFeatureHero(
                title: 'बूथ प्रबंधन',
                subtitle:
                    'बूथ की जानकारी, ward mapping और address एक जगह संभालें।',
                icon: Icons.how_to_vote_rounded,
                badges: const ['Ward linked', 'Organized', 'Secure'],
                action: FilledButton.icon(
                  onPressed: () => _openForm(),
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('नया बूथ'),
                ),
              ),
              Wrap(spacing: 10, runSpacing: 10, children: [
                _BoothMetric(
                    'कुल बूथ', booths.length, Icons.how_to_vote_rounded, blue),
                _BoothMetric('Active manager', activeManagers,
                    Icons.verified_user_rounded, green),
                _BoothMetric(
                    'Mapped voters', voterCount, Icons.groups_rounded, purple),
              ]),
              const SizedBox(height: 4),
              TextField(
                controller: search,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  hintText: 'बूथ नंबर, नाम, वार्ड या क्षेत्र खोजें...',
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: search.text.isEmpty
                      ? null
                      : IconButton(
                          tooltip: 'Search साफ करें',
                          onPressed: () {
                            search.clear();
                            setState(() {});
                          },
                          icon: const Icon(Icons.close_rounded),
                        ),
                ),
              ),
              PremiumSectionTitle(
                title: 'सभी बूथ (${filtered.length}/${booths.length})',
                subtitle: 'संपादित करने के लिए card पर tap करें',
                icon: Icons.location_city_rounded,
              ),
              if (booths.isEmpty)
                PremiumEmptyState(
                  icon: Icons.how_to_vote_outlined,
                  title: 'अभी कोई बूथ नहीं है',
                  subtitle: 'पहला बूथ जोड़कर प्रबंधन शुरू करें',
                  action: FilledButton.icon(
                    onPressed: () => _openForm(),
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('बूथ जोड़ें'),
                  ),
                )
              else
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: filtered.map((booth) {
                    final ward =
                        booth['ward'] is Map ? booth['ward'] as Map : const {};
                    final assigned = managers
                        .where((user) =>
                            _assignedBoothId(user) == '${booth['_id']}')
                        .toList();
                    final active =
                        assigned.where((u) => u['active'] != false).length;
                    final voters = assigned.fold<int>(
                        0,
                        (sum, user) =>
                            sum + _boothStat(user, 'boothVoterCount'));
                    return InkWell(
                      onTap: () => _openForm(booth),
                      borderRadius: BorderRadius.circular(22),
                      child: Container(
                        width: 360,
                        padding: const EdgeInsets.all(15),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(22),
                          border: Border.all(color: border),
                          boxShadow: const [
                            BoxShadow(
                                color: Color(0x0c071b4b),
                                blurRadius: 16,
                                offset: Offset(0, 8)),
                          ],
                        ),
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(children: [
                                Container(
                                  width: 52,
                                  height: 52,
                                  decoration: BoxDecoration(
                                      color: softBlue,
                                      borderRadius: BorderRadius.circular(18)),
                                  child: const Icon(Icons.how_to_vote_rounded,
                                      color: blue),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text('बूथ ${booth['number'] ?? '-'}',
                                            style: const TextStyle(
                                                color: navy,
                                                fontSize: 17,
                                                fontWeight: FontWeight.w900)),
                                        Text('${booth['name'] ?? '-'}',
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                                color: muted,
                                                fontWeight: FontWeight.w700)),
                                      ]),
                                ),
                                Chip(
                                  avatar: Icon(
                                      assigned.isEmpty
                                          ? Icons.warning_amber_rounded
                                          : Icons.verified_rounded,
                                      color: assigned.isEmpty ? orange : green,
                                      size: 16),
                                  label: Text(assigned.isEmpty
                                      ? 'Manager नहीं'
                                      : '$active active'),
                                ),
                              ]),
                              const SizedBox(height: 12),
                              Text(
                                [
                                  if ('${ward['number'] ?? ''}'.isNotEmpty)
                                    'वार्ड ${ward['number']}',
                                  '${booth['area'] ?? ''}',
                                  '${booth['address'] ?? ''}',
                                ]
                                    .where((value) => value.trim().isNotEmpty)
                                    .join(' · '),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style:
                                    const TextStyle(color: muted, fontSize: 12),
                              ),
                              const SizedBox(height: 12),
                              Wrap(spacing: 8, runSpacing: 8, children: [
                                _BoothPill(Icons.supervisor_account_rounded,
                                    '${assigned.length} manager'),
                                _BoothPill(
                                    Icons.groups_rounded, '$voters voters'),
                                _BoothPill(Icons.edit_rounded, 'Edit'),
                              ]),
                            ]),
                      ),
                    );
                  }).toList(),
                ),
            ]);
          },
        ),
      );

  Future<void> _openForm([Map<String, dynamic>? booth]) async {
    final name = TextEditingController(text: '${booth?['name'] ?? ''}');
    final number = TextEditingController(text: '${booth?['number'] ?? ''}');
    final ward = TextEditingController(
        text: booth?['ward'] is Map ? '${booth!['ward']['number'] ?? ''}' : '');
    final area = TextEditingController(text: '${booth?['area'] ?? ''}');
    final address = TextEditingController(text: '${booth?['address'] ?? ''}');
    final save = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(children: [
          const CircleAvatar(
            backgroundColor: softBlue,
            child: Icon(Icons.how_to_vote_rounded, color: blue),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(booth == null ? 'नया बूथ जोड़ें' : 'बूथ संपादित करें',
                style: const TextStyle(fontWeight: FontWeight.w900)),
          ),
        ]),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(
                controller: number,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                    labelText: 'बूथ / भाग संख्या *',
                    prefixIcon: Icon(Icons.confirmation_number_rounded),
                    helperText: 'जैसे 79, 80, 81')),
            const SizedBox(height: 10),
            TextField(
                controller: name,
                decoration: const InputDecoration(
                    labelText: 'बूथ नाम *',
                    prefixIcon: Icon(Icons.home_work_rounded),
                    helperText: 'स्कूल/भवन/क्षेत्र का नाम')),
            const SizedBox(height: 10),
            TextField(
                controller: ward,
                decoration: const InputDecoration(
                    labelText: 'वार्ड संख्या / नाम *',
                    prefixIcon: Icon(Icons.map_rounded))),
            const SizedBox(height: 10),
            TextField(
                controller: area,
                decoration: const InputDecoration(
                    labelText: 'क्षेत्र / गाँव',
                    prefixIcon: Icon(Icons.location_city_rounded))),
            const SizedBox(height: 10),
            TextField(
                controller: address,
                maxLines: 2,
                decoration: const InputDecoration(
                    labelText: 'पूरा पता',
                    prefixIcon: Icon(Icons.location_on_rounded))),
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
    );
    if (save != true) return;
    try {
      final body = {
        'number': number.text.trim(),
        'name': name.text.trim(),
        'ward': ward.text.trim(),
        'area': area.text.trim(),
        'address': address.text.trim(),
      };
      if (booth == null) {
        await api.post('/api/booths', body);
      } else {
        await api.put('/api/booths/${booth['_id']}', body);
      }
      if (mounted) setState(() {});
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(error.toString().replaceFirst('Exception: ', ''))));
      }
    } finally {
      name.dispose();
      number.dispose();
      ward.dispose();
      area.dispose();
      address.dispose();
    }
  }
}

class _BoothMetric extends StatelessWidget {
  const _BoothMetric(this.label, this.value, this.icon, this.color);
  final String label;
  final int value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        width: 210,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: border),
        ),
        child: Row(children: [
          CircleAvatar(
            backgroundColor: color.withValues(alpha: .10),
            child: Icon(icon, color: color),
          ),
          const SizedBox(width: 10),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('$value',
                style: const TextStyle(
                    color: navy, fontSize: 20, fontWeight: FontWeight.w900)),
            Text(label,
                style: const TextStyle(
                    color: muted, fontSize: 12, fontWeight: FontWeight.w700)),
          ]),
        ]),
      );
}

class _BoothPill extends StatelessWidget {
  const _BoothPill(this.icon, this.label);
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xfff7f9ff),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: border),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, color: blue, size: 14),
          const SizedBox(width: 5),
          Text(label,
              style: const TextStyle(
                  color: navy, fontSize: 11, fontWeight: FontWeight.w800)),
        ]),
      );
}

String _assignedBoothId(Map<String, dynamic> user) {
  final booth = user['assignedBooth'];
  if (booth is Map) return '${booth['_id'] ?? ''}';
  return '${booth ?? ''}';
}

int _boothStat(Map<String, dynamic> user, String key) {
  final value = (user['workStats'] as Map?)?[key];
  return value is num ? value.toInt() : int.tryParse('$value') ?? 0;
}
