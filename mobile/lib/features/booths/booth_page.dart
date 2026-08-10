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
                title:
                    'Ã Â¤Â¬Ã Â¥â€šÃ Â¤Â¥ Ã Â¤ÂªÃ Â¥ÂÃ Â¤Â°Ã Â¤Â¬Ã Â¤â€šÃ Â¤Â§Ã Â¤Â¨',
                subtitle:
                    'Ã Â¤Â¬Ã Â¥â€šÃ Â¤Â¥ Ã Â¤â€¢Ã Â¥â‚¬ Ã Â¤Å“Ã Â¤Â¾Ã Â¤Â¨Ã Â¤â€¢Ã Â¤Â¾Ã Â¤Â°Ã Â¥â‚¬, ward mapping Ã Â¤â€Ã Â¤Â° address Ã Â¤ÂÃ Â¤â€¢ Ã Â¤Å“Ã Â¤â€”Ã Â¤Â¹ Ã Â¤Â¸Ã Â¤â€šÃ Â¤Â­Ã Â¤Â¾Ã Â¤Â²Ã Â¥â€¡Ã Â¤â€šÃ Â¥Â¤',
                icon: Icons.how_to_vote_rounded,
                badges: const ['Ward linked', 'Organized', 'Secure'],
                action: FilledButton.icon(
                  onPressed: () => _openForm(),
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Ã Â¤Â¨Ã Â¤Â¯Ã Â¤Â¾ Ã Â¤Â¬Ã Â¥â€šÃ Â¤Â¥'),
                ),
              ),
              Wrap(spacing: 10, runSpacing: 10, children: [
                _BoothMetric('Ã Â¤â€¢Ã Â¥ÂÃ Â¤Â² Ã Â¤Â¬Ã Â¥â€šÃ Â¤Â¥',
                    booths.length, Icons.how_to_vote_rounded, blue),
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
                  hintText:
                      'Ã Â¤Â¬Ã Â¥â€šÃ Â¤Â¥ Ã Â¤Â¨Ã Â¤â€šÃ Â¤Â¬Ã Â¤Â°, Ã Â¤Â¨Ã Â¤Â¾Ã Â¤Â®, Ã Â¤ÂµÃ Â¤Â¾Ã Â¤Â°Ã Â¥ÂÃ Â¤Â¡ Ã Â¤Â¯Ã Â¤Â¾ Ã Â¤â€¢Ã Â¥ÂÃ Â¤Â·Ã Â¥â€¡Ã Â¤Â¤Ã Â¥ÂÃ Â¤Â° Ã Â¤â€“Ã Â¥â€¹Ã Â¤Å“Ã Â¥â€¡Ã Â¤â€š...',
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: search.text.isEmpty
                      ? null
                      : IconButton(
                          tooltip:
                              'Search Ã Â¤Â¸Ã Â¤Â¾Ã Â¤Â« Ã Â¤â€¢Ã Â¤Â°Ã Â¥â€¡Ã Â¤â€š',
                          onPressed: () {
                            search.clear();
                            setState(() {});
                          },
                          icon: const Icon(Icons.close_rounded),
                        ),
                ),
              ),
              PremiumSectionTitle(
                title:
                    'Ã Â¤Â¸Ã Â¤Â­Ã Â¥â‚¬ Ã Â¤Â¬Ã Â¥â€šÃ Â¤Â¥ (${filtered.length}/${booths.length})',
                subtitle:
                    'Ã Â¤Â¸Ã Â¤â€šÃ Â¤ÂªÃ Â¤Â¾Ã Â¤Â¦Ã Â¤Â¿Ã Â¤Â¤ Ã Â¤â€¢Ã Â¤Â°Ã Â¤Â¨Ã Â¥â€¡ Ã Â¤â€¢Ã Â¥â€¡ Ã Â¤Â²Ã Â¤Â¿Ã Â¤Â card Ã Â¤ÂªÃ Â¤Â° tap Ã Â¤â€¢Ã Â¤Â°Ã Â¥â€¡Ã Â¤â€š',
                icon: Icons.location_city_rounded,
              ),
              if (booths.isEmpty)
                PremiumEmptyState(
                  icon: Icons.how_to_vote_outlined,
                  title:
                      'Ã Â¤â€¦Ã Â¤Â­Ã Â¥â‚¬ Ã Â¤â€¢Ã Â¥â€¹Ã Â¤Ë† Ã Â¤Â¬Ã Â¥â€šÃ Â¤Â¥ Ã Â¤Â¨Ã Â¤Â¹Ã Â¥â‚¬Ã Â¤â€š Ã Â¤Â¹Ã Â¥Ë†',
                  subtitle:
                      'Ã Â¤ÂªÃ Â¤Â¹Ã Â¤Â²Ã Â¤Â¾ Ã Â¤Â¬Ã Â¥â€šÃ Â¤Â¥ Ã Â¤Å“Ã Â¥â€¹Ã Â¤Â¡Ã Â¤Â¼Ã Â¤â€¢Ã Â¤Â° Ã Â¤ÂªÃ Â¥ÂÃ Â¤Â°Ã Â¤Â¬Ã Â¤â€šÃ Â¤Â§Ã Â¤Â¨ Ã Â¤Â¶Ã Â¥ÂÃ Â¤Â°Ã Â¥â€š Ã Â¤â€¢Ã Â¤Â°Ã Â¥â€¡Ã Â¤â€š',
                  action: FilledButton.icon(
                    onPressed: () => _openForm(),
                    icon: const Icon(Icons.add_rounded),
                    label: const Text(
                        'Ã Â¤Â¬Ã Â¥â€šÃ Â¤Â¥ Ã Â¤Å“Ã Â¥â€¹Ã Â¤Â¡Ã Â¤Â¼Ã Â¥â€¡Ã Â¤â€š'),
                  ),
                )
              else if (query.isEmpty)
                _BoothHierarchyDirectory(booths: booths, onOpen: _openForm)
              else
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: filtered.asMap().entries.map((entry) {
                    final booth = entry.value;
                    final boothIndex = entry.key;
                    final groupLabel = _boothGroupLabel(booth);
                    final showGroup = boothIndex == 0 ||
                        _boothGroupLabel(filtered[boothIndex - 1]) !=
                            groupLabel;
                    final ward =
                        booth['ward'] is Map ? booth['ward'] as Map : const {};
                    final assigned = managers
                        .where((user) =>
                            _assignedBoothId(user) == '${booth['_id']}')
                        .toList();
                    final active =
                        assigned.where((u) => u['active'] != false).length;
                    final rawBoothName = '${booth['name'] ?? ''}'.trim();
                    final boothName =
                        rawBoothName.isEmpty || rawBoothName == '-'
                            ? ('${booth['area'] ?? booth['address'] ?? ''}'
                                    .trim()
                                    .isEmpty
                                ? 'Booth ${booth['number'] ?? '-'}'
                                : '${booth['area'] ?? booth['address']}')
                            : rawBoothName;
                    final voters = assigned.fold<int>(
                        0,
                        (sum, user) =>
                            sum + _boothStat(user, 'boothVoterCount'));
                    return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (showGroup) _BoothGroupHeader(label: groupLabel),
                          InkWell(
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
                                            borderRadius:
                                                BorderRadius.circular(18)),
                                        child: const Icon(
                                            Icons.how_to_vote_rounded,
                                            color: blue),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                  'Ã Â¤Â¬Ã Â¥â€šÃ Â¤Â¥ ${booth['number'] ?? '-'}',
                                                  style: const TextStyle(
                                                      color: navy,
                                                      fontSize: 17,
                                                      fontWeight:
                                                          FontWeight.w900)),
                                              Text(boothName,
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: const TextStyle(
                                                      color: muted,
                                                      fontWeight:
                                                          FontWeight.w700)),
                                            ]),
                                      ),
                                      Chip(
                                        avatar: Icon(
                                            assigned.isEmpty
                                                ? Icons.warning_amber_rounded
                                                : Icons.verified_rounded,
                                            color: assigned.isEmpty
                                                ? orange
                                                : green,
                                            size: 16),
                                        label: Text(assigned.isEmpty
                                            ? 'Manager Ã Â¤Â¨Ã Â¤Â¹Ã Â¥â‚¬Ã Â¤â€š'
                                            : '$active active'),
                                      ),
                                    ]),
                                    const SizedBox(height: 12),
                                    Text(
                                      [
                                        if ('${ward['number'] ?? ''}'
                                            .isNotEmpty)
                                          'Ã Â¤ÂµÃ Â¤Â¾Ã Â¤Â°Ã Â¥ÂÃ Â¤Â¡ ${ward['number']}',
                                        '${booth['area'] ?? ''}',
                                        '${booth['address'] ?? ''}',
                                      ]
                                          .where((value) =>
                                              value.trim().isNotEmpty)
                                          .join(' Ã‚Â· '),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                          color: muted, fontSize: 12),
                                    ),
                                    const SizedBox(height: 12),
                                    Wrap(spacing: 8, runSpacing: 8, children: [
                                      _BoothPill(
                                          Icons.supervisor_account_rounded,
                                          '${assigned.length} manager'),
                                      _BoothPill(Icons.groups_rounded,
                                          '$voters voters'),
                                      _BoothPill(Icons.edit_rounded, 'Edit'),
                                      if (api.user?['role'] == 'admin')
                                        OutlinedButton.icon(
                                          onPressed: () => _deleteBooth(booth),
                                          icon: const Icon(
                                              Icons.delete_outline_rounded,
                                              size: 16,
                                              color: Colors.red),
                                          label: const Text('Delete',
                                              style:
                                                  TextStyle(color: Colors.red)),
                                          style: OutlinedButton.styleFrom(
                                              visualDensity:
                                                  VisualDensity.compact,
                                              side: const BorderSide(
                                                  color: Color(0x33ef4444)),
                                              shape: RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(
                                                          20))),
                                        ),
                                    ]),
                                  ]),
                            ),
                          ),
                        ]);
                  }).toList(),
                ),
            ]);
          },
        ),
      );

  Future<void> _deleteBooth(Map<String, dynamic> booth) async {
    final id = '${booth['_id'] ?? ''}';
    if (id.isEmpty) return;
    final label = '${booth['name'] ?? ''}'.trim().isNotEmpty
        ? '${booth['name']}'
        : 'Booth ${booth['number'] ?? '-'}';
    final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
              title: const Text('Delete booth?'),
              content: Text(
                  'Delete "$label"? Assigned managers and voters will no longer be linked to this booth.'),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(dialogContext, false),
                    child: const Text('Cancel')),
                FilledButton(
                    style: FilledButton.styleFrom(backgroundColor: Colors.red),
                    onPressed: () => Navigator.pop(dialogContext, true),
                    child: const Text('Delete')),
              ],
            ));
    if (confirmed != true || !mounted) return;
    try {
      await api.delete('/api/booths/$id');
      if (mounted) {
        setState(() {});
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Booth deleted')));
      }
    } catch (error) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(error.toString().replaceFirst('Exception: ', ''))));
    }
  }

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
            child: Text(
                booth == null
                    ? 'Ã Â¤Â¨Ã Â¤Â¯Ã Â¤Â¾ Ã Â¤Â¬Ã Â¥â€šÃ Â¤Â¥ Ã Â¤Å“Ã Â¥â€¹Ã Â¤Â¡Ã Â¤Â¼Ã Â¥â€¡Ã Â¤â€š'
                    : 'Ã Â¤Â¬Ã Â¥â€šÃ Â¤Â¥ Ã Â¤Â¸Ã Â¤â€šÃ Â¤ÂªÃ Â¤Â¾Ã Â¤Â¦Ã Â¤Â¿Ã Â¤Â¤ Ã Â¤â€¢Ã Â¤Â°Ã Â¥â€¡Ã Â¤â€š',
                style: const TextStyle(fontWeight: FontWeight.w900)),
          ),
        ]),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(
                controller: number,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                    labelText:
                        'Ã Â¤Â¬Ã Â¥â€šÃ Â¤Â¥ Ã Â¤Â¸Ã Â¤â€šÃ Â¤â€“Ã Â¥ÂÃ Â¤Â¯Ã Â¤Â¾ *',
                    prefixIcon: Icon(Icons.confirmation_number_rounded),
                    helperText: 'Ã Â¤Å“Ã Â¥Ë†Ã Â¤Â¸Ã Â¥â€¡ 79, 80, 81')),
            const SizedBox(height: 10),
            TextField(
                controller: name,
                decoration: const InputDecoration(
                    labelText:
                        'Ã Â¤â€¦Ã Â¤Â¨Ã Â¥ÂÃ Â¤Â­Ã Â¤Â¾Ã Â¤â€” / Ã Â¤â€”Ã Â¤Â¾Ã Â¤ÂÃ Â¤Âµ Ã Â¤Â¨Ã Â¤Â¾Ã Â¤Â® *',
                    prefixIcon: Icon(Icons.home_work_rounded),
                    helperText:
                        'PDF Ã Â¤Â®Ã Â¥â€¡Ã Â¤â€š Ã Â¤â€ Ã Â¤Â¯Ã Â¤Â¾ Ã Â¤â€¦Ã Â¤Â¨Ã Â¥ÂÃ Â¤Â­Ã Â¤Â¾Ã Â¤â€” Ã Â¤Â¯Ã Â¤Â¾ Ã Â¤â€”Ã Â¤Â¾Ã Â¤ÂÃ Â¤Âµ Ã Â¤Â¨Ã Â¤Â¾Ã Â¤Â®')),
            const SizedBox(height: 10),
            TextField(
                controller: ward,
                decoration: const InputDecoration(
                    labelText:
                        'Ã Â¤ÂµÃ Â¤Â¾Ã Â¤Â°Ã Â¥ÂÃ Â¤Â¡ Ã Â¤Â¸Ã Â¤â€šÃ Â¤â€“Ã Â¥ÂÃ Â¤Â¯Ã Â¤Â¾ / Ã Â¤Â¨Ã Â¤Â¾Ã Â¤Â® *',
                    prefixIcon: Icon(Icons.map_rounded))),
            const SizedBox(height: 10),
            TextField(
                controller: area,
                decoration: const InputDecoration(
                    labelText:
                        'Ã Â¤â€”Ã Â¤Â¾Ã Â¤ÂÃ Â¤Âµ / Ã Â¤â€¢Ã Â¥ÂÃ Â¤Â·Ã Â¥â€¡Ã Â¤Â¤Ã Â¥ÂÃ Â¤Â°',
                    prefixIcon: Icon(Icons.location_city_rounded))),
            const SizedBox(height: 10),
            TextField(
                controller: address,
                maxLines: 2,
                decoration: const InputDecoration(
                    labelText: 'Ã Â¤ÂªÃ Â¥â€šÃ Â¤Â°Ã Â¤Â¾ Ã Â¤ÂªÃ Â¤Â¤Ã Â¤Â¾',
                    prefixIcon: Icon(Icons.location_on_rounded))),
          ]),
        ),
        actions: [
          if (booth != null)
            TextButton.icon(
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              onPressed: () async {
                final ok = await showDialog<bool>(
                  context: context,
                  builder: (dialogContext) => AlertDialog(
                    title: const Text(
                        'Ã Â¤Â¬Ã Â¥â€šÃ Â¤Â¥ Ã Â¤Â¹Ã Â¤Å¸Ã Â¤Â¾Ã Â¤ÂÃ Â¤Â?'),
                    content: const Text(
                        'Ã Â¤â€¡Ã Â¤Â¸ Ã Â¤Â¬Ã Â¥â€šÃ Â¤Â¥ Ã Â¤â€¢Ã Â¥â‚¬ mapping Ã Â¤Â¹Ã Â¤Å¸ Ã Â¤Å“Ã Â¤Â¾Ã Â¤ÂÃ Â¤â€”Ã Â¥â‚¬Ã Â¥Â¤ Ã Â¤Å“Ã Â¥ÂÃ Â¤Â¡Ã Â¤Â¼Ã Â¥â€¡ voters Ã Â¤â€¢Ã Â¥â€¹ Ã Â¤ÂªÃ Â¤Â¹Ã Â¤Â²Ã Â¥â€¡ Ã Â¤Â¦Ã Â¥â€šÃ Â¤Â¸Ã Â¤Â°Ã Â¥â€¡ Ã Â¤Â¬Ã Â¥â€šÃ Â¤Â¥ Ã Â¤Â®Ã Â¥â€¡Ã Â¤â€š assign Ã Â¤â€¢Ã Â¤Â°Ã Â¥â€¡Ã Â¤â€šÃ Â¥Â¤'),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(dialogContext, false),
                          child: const Text(
                              'Ã Â¤Â°Ã Â¤Â¦Ã Â¥ÂÃ Â¤Â¦ Ã Â¤â€¢Ã Â¤Â°Ã Â¥â€¡Ã Â¤â€š')),
                      FilledButton(
                        style:
                            FilledButton.styleFrom(backgroundColor: Colors.red),
                        onPressed: () => Navigator.pop(dialogContext, true),
                        child: const Text('Ã Â¤Â¹Ã Â¤Å¸Ã Â¤Â¾Ã Â¤ÂÃ Â¤Â'),
                      ),
                    ],
                  ),
                );
                if (ok != true) return;
                try {
                  await api.delete('/api/booths/${booth['_id']}');
                  if (context.mounted) Navigator.pop(context, true);
                } catch (error) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                          content: Text(error
                              .toString()
                              .replaceFirst('Exception: ', ''))),
                    );
                  }
                }
              },
              icon: const Icon(Icons.delete_outline_rounded),
              label: const Text(
                  'Ã Â¤Â¬Ã Â¥â€šÃ Â¤Â¥ Ã Â¤Â¹Ã Â¤Å¸Ã Â¤Â¾Ã Â¤ÂÃ Â¤Â'),
            ),
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text(
                  'Ã Â¤Â°Ã Â¤Â¦Ã Â¥ÂÃ Â¤Â¦ Ã Â¤â€¢Ã Â¤Â°Ã Â¥â€¡Ã Â¤â€š')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Ã Â¤Â¸Ã Â¤Â¹Ã Â¥â€¡Ã Â¤Å“Ã Â¥â€¡Ã Â¤â€š')),
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

class _BoothHierarchyDirectory extends StatefulWidget {
  const _BoothHierarchyDirectory({required this.booths, required this.onOpen});
  final List<Map<String, dynamic>> booths;
  final Future<void> Function([Map<String, dynamic>? booth]) onOpen;
  @override
  State<_BoothHierarchyDirectory> createState() =>
      _BoothHierarchyDirectoryState();
}

class _BoothHierarchyDirectoryState extends State<_BoothHierarchyDirectory> {
  String? assembly;
  String? village;
  String _assemblyOf(Map<String, dynamic> booth) {
    final ward = booth['ward'] is Map ? booth['ward'] as Map : const {};
    return (ward['name'] ?? ward['number'] ?? 'Unmapped assembly')
        .toString()
        .trim();
  }

  List<String> _locations(Map<String, dynamic> booth) {
    final raw = List<String>.from(
        (booth['locationNames'] as List? ?? const []).map((v) => v.toString()));
    final values = raw
        .map((value) {
          final parts = value.split(',').map((e) => e.trim()).toList();
          return parts.isEmpty ? value.trim() : parts.last;
        })
        .where((value) => value.isNotEmpty)
        .toList();
    if (values.isEmpty && (booth['area'] ?? '').toString().trim().isNotEmpty) {
      values.add(booth['area'].toString());
    }
    if (values.isEmpty) values.add('Unmapped village');
    return values.toSet().toList();
  }

  List<String> _sectionsForVillage(Map<String, dynamic> booth, String village) {
    final raw = List<String>.from(
        (booth['locationNames'] as List? ?? const []).map((v) => v.toString()));
    return raw.where((value) {
      final parts = value.split(',').map((e) => e.trim()).toList();
      return (parts.isEmpty ? value.trim() : parts.last) == village;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    if (assembly == null)
      return _level('Choose assembly / ward', Icons.account_balance_rounded,
          _assemblies(), (value) => setState(() => assembly = value));
    final assemblyBooths =
        widget.booths.where((b) => _assemblyOf(b) == assembly).toList();
    if (village == null) {
      final villages = <String>{};
      for (final booth in assemblyBooths) villages.addAll(_locations(booth));
      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _back('Assembly: ' + assembly!, () => setState(() => assembly = null)),
        _level('Choose village / section', Icons.location_city_rounded,
            villages.toList(), (value) => setState(() => village = value))
      ]);
    }
    final matches =
        assemblyBooths.where((b) => _locations(b).contains(village)).toList();
    final sections = <String, Map<String, dynamic>>{};
    for (final booth in matches) {
      for (final section in _sectionsForVillage(booth, village!)) {
        sections.putIfAbsent(section, () => booth);
      }
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _back('Assembly: ' + assembly! + ' Â· ????: ' + village!,
          () => setState(() => village = null)),
      _level(
        'Choose section',
        Icons.view_list_rounded,
        sections.keys.toList(),
        (section) => widget.onOpen(sections[section]),
      ),
      if (sections.isEmpty)
        const Padding(
            padding: EdgeInsets.all(18),
            child: Text('No section found for this village.'))
    ]);
  }

  List<String> _assemblies() => widget.booths.map(_assemblyOf).toSet().toList();
  Widget _back(String label, VoidCallback onTap) => Align(
      alignment: Alignment.centerLeft,
      child: TextButton.icon(
          onPressed: onTap,
          icon: const Icon(Icons.arrow_back_rounded),
          label: Text(label)));
  Widget _level(String title, IconData icon, List<String> values,
          ValueChanged<String> onTap) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(title,
                style: const TextStyle(
                    color: navy, fontSize: 16, fontWeight: FontWeight.w900))),
        ...values.map((value) => Card(
            margin: const EdgeInsets.only(bottom: 10),
            child: ListTile(
                leading: Icon(icon, color: blue),
                title: Text(value,
                    style: const TextStyle(
                        color: navy, fontWeight: FontWeight.w800)),
                trailing: const Icon(Icons.chevron_right_rounded, color: blue),
                onTap: () => onTap(value))))
      ]);
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

String _boothGroupLabel(Map<String, dynamic> booth) {
  final ward = booth['ward'] is Map ? booth['ward'] as Map : const {};
  final assembly = '${ward['name'] ?? ward['number'] ?? ''}'.trim();
  final village = '${booth['area'] ?? booth['address'] ?? ''}'.trim();
  return [if (assembly.isNotEmpty) assembly, if (village.isNotEmpty) village]
      .join(' ? ');
}

class _BoothGroupHeader extends StatelessWidget {
  const _BoothGroupHeader({required this.label});
  final String label;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 8, bottom: 2),
        child: Row(children: [
          const Icon(Icons.folder_rounded, color: blue, size: 20),
          const SizedBox(width: 8),
          Expanded(
              child: Text(label.isEmpty ? 'Unmapped location' : label,
                  style: const TextStyle(
                      color: navy, fontSize: 15, fontWeight: FontWeight.w900))),
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
