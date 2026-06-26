import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../core/theme.dart';
import '../../layout/app_layout.dart';
import '../../widgets/common.dart';
import '../../widgets/mobile_components.dart';
import '../areas/area_directory_page.dart';
import '../families/family_page.dart';
import '../reports/configurable_print_page.dart';
import '../uploads/upload_page.dart';
import '../voters/voter_management_page.dart';

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key, required this.onNavigate});
  final ValueChanged<int> onNavigate;

  @override
  Widget build(BuildContext context) => FutureBlock<Map<String, dynamic>>(
        load: () => api.get('/api/reports/dashboard'),
        builder: (data) {
          final total = _number(data['members']);
          final families = _number(data['families']);
          final booths = _number(data['booths']);
          final review = _group(data, 'verification', 'needs_review') +
              _group(data, 'verification', 'duplicate');
          final congress = _group(data, 'support', 'supporter');
          final opposite = _group(data, 'support', 'opposite');
          final other = (total - congress - opposite).clamp(0, total);
          final villages = List<Map<String, dynamic>>.from(
            (data['villageDistribution'] as List? ?? [])
                .map((e) => Map<String, dynamic>.from(e)),
          );
          final assembly = Map<String, dynamic>.from(data['assembly'] ?? {});
          final assemblyId = Map<String, dynamic>.from(assembly['_id'] ?? {});

          return AppPage(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
            children: [
              AppHeroBanner(
                title: 'नमस्कार, ${api.user?['name'] ?? 'Admin'} 👋',
                subtitle:
                    'आज के जरूरी काम, मतदाता डेटा और संगठन की स्थिति एक साफ dashboard में',
                icon: Icons.dashboard_customize_rounded,
                trailing: Wrap(spacing: 10, runSpacing: 10, children: [
                  VisualSummaryCard(
                    title: 'विधानसभा',
                    value: '${assemblyId['number'] ?? '-'}',
                    subtitle: '${assemblyId['name'] ?? 'चयनित नहीं'}',
                    icon: Icons.account_balance_rounded,
                    color: blue,
                  ),
                  VisualSummaryCard(
                    title: 'आज जोड़े',
                    value: '${_number(data['createdToday'])}',
                    subtitle: 'नए मतदाता',
                    icon: Icons.person_add_alt_1_rounded,
                    color: green,
                  ),
                ]),
                primaryAction: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: blue,
                  ),
                  onPressed: () => onNavigate(1),
                  icon: const Icon(Icons.search_rounded),
                  label: const Text('मतदाता खोजें'),
                ),
                secondaryAction: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white54),
                  ),
                  onPressed: () => Navigator.push(context,
                      MaterialPageRoute(builder: (_) => const UploadPage())),
                  icon: const Icon(Icons.upload_file_rounded),
                  label: const Text('Import'),
                ),
              ),
              _MetricGrid(items: [
                _MetricData('कुल मतदाता', '$total', Icons.groups_rounded, blue,
                    '${_number(data['createdToday'])} आज जोड़े'),
                _MetricData('कुल परिवार', '$families', Icons.home_work_rounded,
                    green, 'परिवार रिकॉर्ड'),
                _MetricData('कुल बूथ', '$booths', Icons.how_to_vote_rounded,
                    orange, 'सक्रिय क्षेत्र'),
                _MetricData(
                    'समीक्षा जरूरी',
                    '$review',
                    Icons.fact_check_rounded,
                    review > 0 ? rose : green,
                    review > 0 ? 'डेटा जाँचें' : 'सब ठीक है'),
              ]),
              const _SectionHeading(
                  title: 'जरूरी काम',
                  subtitle: 'रोज़ इस्तेमाल होने वाले मुख्य विकल्प'),
              _ActionGrid(actions: [
                _ActionData(Icons.search_rounded, 'मतदाता खोजें',
                    'नाम, EPIC, मोबाइल या गाँव से', blue, () => onNavigate(1)),
                _ActionData(
                    Icons.person_add_alt_1_rounded,
                    'नया मतदाता',
                    'नया रिकॉर्ड जोड़ें और सत्यापित करें',
                    green,
                    () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const VoterManagementPage()))),
                _ActionData(
                    Icons.upload_file_rounded,
                    'डेटा इम्पोर्ट',
                    'PDF, Excel या CSV अपलोड करें',
                    orange,
                    () => Navigator.push(context,
                        MaterialPageRoute(builder: (_) => const UploadPage()))),
                _ActionData(
                    Icons.account_balance_rounded,
                    'क्षेत्र एवं गाँव',
                    'विधानसभा से गाँव तक प्रबंधन',
                    purple,
                    () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const AreaDirectoryPage()))),
                _ActionData(
                    Icons.family_restroom_rounded,
                    'परिवार प्रबंधन',
                    'घर और परिवार के सदस्य देखें',
                    green,
                    () => Navigator.push(context,
                        MaterialPageRoute(builder: (_) => const FamilyPage()))),
                _ActionData(
                    Icons.print_rounded,
                    'चयन एवं प्रिंट',
                    'कस्टम फील्ड के साथ bulk print',
                    blue,
                    () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const ConfigurablePrintPage()))),
              ]),
              LayoutBuilder(builder: (context, constraints) {
                final width = constraints.maxWidth >= 900
                    ? (constraints.maxWidth - 12) / 2
                    : constraints.maxWidth;
                return Wrap(spacing: 12, runSpacing: 12, children: [
                  SizedBox(
                      width: width,
                      child: _VillageCard(items: villages, total: total)),
                  SizedBox(
                      width: width,
                      child: _SupportCard(
                          total: total,
                          congress: congress,
                          opposite: opposite,
                          other: other)),
                  SizedBox(
                      width: width,
                      child: _QualityCard(
                          missingMobile: _number(data['missingMobile']),
                          missingHouse: _number(data['missingHouseNumber']),
                          review: review,
                          total: total,
                          onOpen: () => onNavigate(1))),
                  SizedBox(
                      width: width,
                      child: _ActivityCard(
                          items: List.from(data['recentActivity'] ?? []))),
                ]);
              }),
            ],
          );
        },
      );
}

class _MetricData {
  const _MetricData(
      this.label, this.value, this.icon, this.color, this.caption);
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final String caption;
}

class _MetricGrid extends StatelessWidget {
  const _MetricGrid({required this.items});
  final List<_MetricData> items;

  @override
  Widget build(BuildContext context) =>
      LayoutBuilder(builder: (_, constraints) {
        final columns = constraints.maxWidth >= 1000
            ? 4
            : constraints.maxWidth >= 360
                ? 2
                : 1;
        final width = (constraints.maxWidth - (columns - 1) * 12) / columns;
        return Wrap(
            spacing: 12,
            runSpacing: 12,
            children: items
                .map((item) => SizedBox(
                    width: width,
                    child: MetricCard(
                        label: item.label,
                        value: item.value,
                        icon: item.icon,
                        color: item.color,
                        caption: item.caption)))
                .toList());
      });
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading({required this.title, required this.subtitle});
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(
                  color: navy, fontSize: 19, fontWeight: FontWeight.w900)),
          const SizedBox(height: 3),
          Text(subtitle, style: const TextStyle(color: muted, fontSize: 12)),
        ],
      );
}

class _ActionData {
  const _ActionData(
      this.icon, this.title, this.subtitle, this.color, this.onTap);
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;
}

class _ActionGrid extends StatelessWidget {
  const _ActionGrid({required this.actions});
  final List<_ActionData> actions;

  @override
  Widget build(BuildContext context) =>
      LayoutBuilder(builder: (_, constraints) {
        final columns = constraints.maxWidth >= 1050
            ? 3
            : constraints.maxWidth >= 560
                ? 2
                : 1;
        final width = (constraints.maxWidth - (columns - 1) * 12) / columns;
        return Wrap(
            spacing: 12,
            runSpacing: 12,
            children: actions
                .map((action) =>
                    SizedBox(width: width, child: _ActionCard(data: action)))
                .toList());
      });
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({required this.data});
  final _ActionData data;

  @override
  Widget build(BuildContext context) => Material(
        color: Colors.white,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: const BorderSide(color: border)),
        child: InkWell(
          onTap: data.onTap,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(children: [
              Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                      color: data.color.withValues(alpha: .1),
                      borderRadius: BorderRadius.circular(13)),
                  child: Icon(data.icon, color: data.color, size: 25)),
              const SizedBox(width: 13),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text(data.title,
                        style: const TextStyle(
                            color: navy,
                            fontSize: 14,
                            fontWeight: FontWeight.w900)),
                    const SizedBox(height: 3),
                    Text(data.subtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: muted, fontSize: 11)),
                  ])),
              const Icon(Icons.arrow_forward_ios_rounded,
                  color: Color(0xffa8b3ca), size: 15),
            ]),
          ),
        ),
      );
}

class _VillageCard extends StatelessWidget {
  const _VillageCard({required this.items, required this.total});
  final List<Map<String, dynamic>> items;
  final int total;

  @override
  Widget build(BuildContext context) {
    final maxValue = items.fold<int>(0, (max, item) {
      final value = _number(item['count']);
      return value > max ? value : max;
    });
    return SectionCard(
      title: 'प्रमुख गाँव',
      subtitle: 'सबसे ज्यादा मतदाता वाले गाँव',
      icon: Icons.location_city_rounded,
      child: items.isEmpty
          ? const _EmptyState(
              icon: Icons.location_city_outlined,
              text: 'गाँव का डेटा अभी उपलब्ध नहीं है')
          : Column(
              children: items.map((item) {
                final value = _number(item['count']);
                final progress = maxValue == 0 ? 0.0 : value / maxValue;
                final percent = total == 0 ? 0 : (value * 100 / total).round();
                return Padding(
                  padding: const EdgeInsets.only(bottom: 13),
                  child: Column(children: [
                    Row(children: [
                      Expanded(
                          child: Text('${item['_id']}',
                              style: const TextStyle(
                                  fontWeight: FontWeight.w700, color: navy))),
                      Text('$value  ·  $percent%',
                          style: const TextStyle(
                              color: muted,
                              fontSize: 12,
                              fontWeight: FontWeight.w700)),
                    ]),
                    const SizedBox(height: 7),
                    LinearProgressIndicator(
                        value: progress,
                        minHeight: 7,
                        borderRadius: BorderRadius.circular(8),
                        backgroundColor: const Color(0xffedf2fa),
                        color: blue),
                  ]),
                );
              }).toList(),
            ),
    );
  }
}

class _SupportCard extends StatelessWidget {
  const _SupportCard(
      {required this.total,
      required this.congress,
      required this.opposite,
      required this.other});
  final int total;
  final int congress;
  final int opposite;
  final int other;

  @override
  Widget build(BuildContext context) => SectionCard(
        title: 'समर्थन स्थिति',
        subtitle: 'समर्थक / विपक्ष / अनिर्णीत snapshot',
        icon: Icons.pie_chart_rounded,
        child: Row(children: [
          DonutChart(values: [
            congress.toDouble(),
            opposite.toDouble(),
            other.toDouble()
          ], colors: const [
            blue,
            orange,
            purple
          ], center: '$total'),
          const SizedBox(width: 16),
          Expanded(
              child: Column(children: [
            _LegendRow('कांग्रेस समर्थक', congress, blue),
            _LegendRow('विपक्ष समर्थक', opposite, orange),
            _LegendRow('तटस्थ / अनिर्णीत', other, purple),
          ])),
        ]),
      );
}

class _LegendRow extends StatelessWidget {
  const _LegendRow(this.label, this.value, this.color);
  final String label;
  final int value;
  final Color color;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 7),
        child: Row(children: [
          Container(
              width: 9,
              height: 9,
              decoration: BoxDecoration(
                  color: color, borderRadius: BorderRadius.circular(3))),
          const SizedBox(width: 8),
          Expanded(
              child: Text(label,
                  style: const TextStyle(color: muted, fontSize: 12))),
          Text('$value',
              style: const TextStyle(color: navy, fontWeight: FontWeight.w900)),
        ]),
      );
}

class _QualityCard extends StatelessWidget {
  const _QualityCard(
      {required this.missingMobile,
      required this.missingHouse,
      required this.review,
      required this.total,
      required this.onOpen});
  final int missingMobile;
  final int missingHouse;
  final int review;
  final int total;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) => SectionCard(
        title: 'डेटा गुणवत्ता',
        subtitle: 'गलत या missing data जल्दी पकड़ें',
        icon: Icons.health_and_safety_rounded,
        action:
            TextButton(onPressed: onOpen, child: const Text('रिकॉर्ड देखें')),
        child: Column(children: [
          _QualityRow(Icons.phone_rounded, 'मोबाइल नंबर नहीं है', missingMobile,
              total, rose),
          _QualityRow(Icons.home_rounded, 'घर संख्या नहीं है', missingHouse,
              total, orange),
          _QualityRow(Icons.fact_check_rounded, 'मैनुअल समीक्षा जरूरी', review,
              total, purple),
        ]),
      );
}

class _QualityRow extends StatelessWidget {
  const _QualityRow(this.icon, this.label, this.value, this.total, this.color);
  final IconData icon;
  final String label;
  final int value;
  final int total;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final ratio = total == 0 ? 0.0 : (value / total).clamp(0.0, 1.0);
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(children: [
        Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
                color: color.withValues(alpha: .09),
                borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: color, size: 20)),
        const SizedBox(width: 11),
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(
                child: Text(label,
                    style: const TextStyle(
                        color: navy,
                        fontSize: 12,
                        fontWeight: FontWeight.w700))),
            Text('$value',
                style: TextStyle(color: color, fontWeight: FontWeight.w900)),
          ]),
          const SizedBox(height: 6),
          LinearProgressIndicator(
              value: ratio,
              minHeight: 5,
              borderRadius: BorderRadius.circular(5),
              backgroundColor: const Color(0xffedf2fa),
              color: color),
        ])),
      ]),
    );
  }
}

class _ActivityCard extends StatelessWidget {
  const _ActivityCard({required this.items});
  final List items;

  @override
  Widget build(BuildContext context) => SectionCard(
        title: 'हाल की गतिविधि',
        subtitle: 'नए changes और import updates',
        icon: Icons.history_rounded,
        child: items.isEmpty
            ? const _EmptyState(
                icon: Icons.history_rounded,
                text: 'अभी कोई गतिविधि दर्ज नहीं है')
            : Column(
                children: items.take(5).map((raw) {
                  final item = Map<String, dynamic>.from(raw);
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(children: [
                      const CircleAvatar(
                          radius: 19,
                          backgroundColor: Color(0xffeaf8f0),
                          child: Icon(Icons.check_rounded,
                              color: green, size: 20)),
                      const SizedBox(width: 11),
                      Expanded(
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                            Text('${item['action'] ?? 'रिकॉर्ड अपडेट हुआ'}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    color: navy,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800)),
                            const SizedBox(height: 2),
                            Text(_formatDate(item['createdAt']),
                                style: const TextStyle(
                                    color: muted, fontSize: 11)),
                          ])),
                    ]),
                  );
                }).toList(),
              ),
      );
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 30),
        child: Center(
            child: Column(children: [
          Icon(icon, color: const Color(0xff9ba9c1), size: 34),
          const SizedBox(height: 9),
          Text(text,
              textAlign: TextAlign.center,
              style: const TextStyle(color: muted)),
        ])),
      );
}

int _number(dynamic value) =>
    value is num ? value.toInt() : int.tryParse('$value') ?? 0;

int _group(Map data, String collection, String key) =>
    (data[collection] as List? ?? [])
        .where((e) => e['_id'] == key)
        .fold<int>(0, (sum, e) => sum + _number(e['count']));

String _formatDate(dynamic value) {
  final date = DateTime.tryParse('$value')?.toLocal();
  if (date == null) return '';
  String two(int number) => number.toString().padLeft(2, '0');
  return '${two(date.day)}/${two(date.month)}/${date.year}  ${two(date.hour)}:${two(date.minute)}';
}
