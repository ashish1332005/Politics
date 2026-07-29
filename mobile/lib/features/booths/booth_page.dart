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
  @override
  Widget build(BuildContext context) => FutureBlock<List<dynamic>>(
        load: () => api.list('/api/booths'),
        builder: (items) => AppPage(children: [
          PremiumFeatureHero(
            title: 'बूथ प्रबंधन',
            subtitle: 'बूथ की जानकारी, ward mapping और address एक जगह संभालें।',
            icon: Icons.how_to_vote_rounded,
            badges: const ['Ward linked', 'Organized', 'Secure'],
            action: FilledButton.icon(
              onPressed: () => _openForm(),
              icon: const Icon(Icons.add_rounded),
              label: const Text('नया बूथ'),
            ),
          ),
          PremiumSectionTitle(
            title: 'सभी बूथ (${items.length})',
            subtitle: 'संपादित करने के लिए card पर tap करें',
            icon: Icons.location_city_rounded,
          ),
          if (items.isEmpty)
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
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: border),
              ),
              child: Column(
                children: items.map((raw) {
                  final booth = Map<String, dynamic>.from(raw as Map);
                  final ward =
                      booth['ward'] is Map ? booth['ward'] as Map : const {};
                  return InkWell(
                    onTap: () => _openForm(booth),
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: const BoxDecoration(
                        border: Border(
                            bottom: BorderSide(color: Color(0xffedf0f5))),
                      ),
                      child: Row(children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: const BoxDecoration(
                              shape: BoxShape.circle, color: softBlue),
                          child: const Icon(Icons.how_to_vote_rounded,
                              color: blue),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                    'बूथ ${booth['number'] ?? '-'} · ${booth['name'] ?? '-'}',
                                    style: const TextStyle(
                                        color: navy,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w900)),
                                const SizedBox(height: 3),
                                Text(
                                    [
                                      if ('${ward['number'] ?? ''}'.isNotEmpty)
                                        'वार्ड ${ward['number']}',
                                      '${booth['area'] ?? ''}',
                                      '${booth['address'] ?? ''}',
                                    ]
                                        .where(
                                            (value) => value.trim().isNotEmpty)
                                        .join(' · '),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                        color: muted, fontSize: 11)),
                              ]),
                        ),
                        const Icon(Icons.edit_rounded, color: blue, size: 20),
                      ]),
                    ),
                  );
                }).toList(),
              ),
            ),
        ]),
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
        title: Text(booth == null ? 'नया बूथ जोड़ें' : 'बूथ संपादित करें'),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(
                controller: number,
                decoration: const InputDecoration(labelText: 'बूथ संख्या *')),
            const SizedBox(height: 10),
            TextField(
                controller: name,
                decoration: const InputDecoration(labelText: 'बूथ नाम *')),
            const SizedBox(height: 10),
            TextField(
                controller: ward,
                decoration:
                    const InputDecoration(labelText: 'वार्ड संख्या / नाम *')),
            const SizedBox(height: 10),
            TextField(
                controller: area,
                decoration: const InputDecoration(labelText: 'क्षेत्र')),
            const SizedBox(height: 10),
            TextField(
                controller: address,
                maxLines: 2,
                decoration: const InputDecoration(labelText: 'पता')),
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
