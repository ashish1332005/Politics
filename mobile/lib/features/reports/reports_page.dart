import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../core/download_helper.dart';
import '../../core/print_helper.dart';
import '../../core/theme.dart';
import '../../layout/app_layout.dart';
import '../../widgets/common.dart';
import '../../widgets/mobile_components.dart';
import 'configurable_print_page.dart';

class ReportsPage extends StatelessWidget {
  const ReportsPage({super.key});

  @override
  Widget build(BuildContext context) => FutureBlock<Map<String, dynamic>>(
        load: () => api.get('/api/reports/dashboard'),
        builder: (data) {
          final total = _number(data['members']);
          final congress = _support(data, 'supporter');
          final bjp = _support(data, 'opposite');
          final other = (total - congress - bjp).clamp(0, total);
          return AppPage(children: [
            PageHeading(
              title: 'रिपोर्ट',
              subtitle: 'विभिन्न प्रकार की रिपोर्ट देखें और डाउनलोड करें',
              action: FilledButton.icon(
                  onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const ConfigurablePrintPage())),
                  icon: const Icon(Icons.print_rounded),
                  label: const Text('Smart Bulk Print')),
            ),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(children: [
                _tab('सारांश रिपोर्ट', true),
                _tab('मतदाता रिपोर्ट', false),
                _tab('परिवार रिपोर्ट', false),
                _tab('राजनीतिक रिपोर्ट', false),
                _tab('बूथ रिपोर्ट', false),
              ]),
            ),
            LayoutBuilder(builder: (context, constraints) {
              final columns = constraints.maxWidth > 720 ? 4 : 2;
              final width =
                  (constraints.maxWidth - (columns - 1) * 10) / columns;
              final cards = [
                MetricCard(
                    label: 'कुल मतदाता',
                    value: '$total',
                    icon: Icons.groups,
                    color: blue,
                    caption: '+120 इस माह'),
                const MetricCard(
                    label: 'कुल परिवार',
                    value: '6,842',
                    icon: Icons.family_restroom,
                    color: green,
                    caption: '+85 इस माह'),
                MetricCard(
                    label: 'कांग्रेस समर्थक',
                    value: '$congress',
                    icon: Icons.group,
                    color: green),
                MetricCard(
                    label: 'भाजपा समर्थक',
                    value: '$bjp',
                    icon: Icons.local_florist,
                    color: orange),
                MetricCard(
                    label: 'अन्य / तटस्थ',
                    value: '$other',
                    icon: Icons.help_outline,
                    color: rose),
                const MetricCard(
                    label: 'कुल बूथ',
                    value: '271',
                    icon: Icons.home_outlined,
                    color: green),
              ];
              return Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: cards
                      .map((c) => SizedBox(width: width, child: c))
                      .toList());
            }),
            LayoutBuilder(builder: (context, constraints) {
              final width = constraints.maxWidth > 720
                  ? (constraints.maxWidth - 12) / 2
                  : constraints.maxWidth;
              return Wrap(spacing: 12, runSpacing: 12, children: [
                SizedBox(
                  width: width,
                  child: SectionCard(
                    title: 'समर्थन स्तर के अनुसार',
                    child: Row(children: [
                      DonutChart(values: [
                        congress.toDouble(),
                        bjp.toDouble(),
                        other.toDouble()
                      ], colors: const [
                        green,
                        orange,
                        purple
                      ], center: '$total'),
                      Expanded(
                          child: Column(children: [
                        _legend('कांग्रेस समर्थक', congress, green),
                        _legend('भाजपा समर्थक', bjp, orange),
                        _legend('अन्य / तटस्थ', other, purple),
                      ])),
                    ]),
                  ),
                ),
                SizedBox(
                  width: width,
                  child: const SectionCard(
                    title: 'बूथ अनुसार मतदाता',
                    child: SizedBox(height: 190, child: _BarChart()),
                  ),
                ),
              ]);
            }),
            const SectionCard(
              title: 'त्वरित रिपोर्ट',
              child: Wrap(spacing: 10, runSpacing: 10, children: [
                _ReportTile(Icons.groups, 'मतदाता सूची', blue),
                _ReportTile(Icons.bar_chart, 'समर्थन स्तर रिपोर्ट', green),
                _ReportTile(Icons.home, 'परिवार सूची', orange),
                _ReportTile(Icons.local_florist, 'राजनीतिक श्रेणी', purple),
                _ReportTile(Icons.location_on, 'बूथ वार रिपोर्ट', rose),
              ]),
            ),
            Wrap(spacing: 8, runSpacing: 8, children: [
              OutlinedButton.icon(
                  onPressed: () => saveApiFile(context,
                      path: '/api/export/members.profiles.pdf',
                      fallbackName: 'report.pdf'),
                  icon: const Icon(Icons.picture_as_pdf, color: Colors.red),
                  label: const Text('PDF डाउनलोड करें')),
              OutlinedButton.icon(
                  onPressed: () => saveApiFile(context,
                      path: '/api/export/members.xlsx',
                      fallbackName: 'report.xlsx'),
                  icon: const Icon(Icons.table_view, color: green),
                  label: const Text('Excel डाउनलोड करें')),
              OutlinedButton.icon(
                  onPressed: () => printApiPdf(context,
                      path: '/api/export/members.profiles.pdf',
                      jobName: 'मतदाता रिपोर्ट'),
                  icon: const Icon(Icons.print, color: blue),
                  label: const Text('प्रिंट करें')),
            ]),
          ]);
        },
      );

  Widget _tab(String label, bool selected) => Container(
        margin: const EdgeInsets.only(right: 8),
        child: selected
            ? FilledButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.bar_chart, size: 18),
                label: Text(label))
            : OutlinedButton(onPressed: () {}, child: Text(label)),
      );

  Widget _legend(String label, int value, Color color) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 7),
        child: Row(children: [
          Container(width: 9, height: 9, color: color),
          const SizedBox(width: 8),
          Expanded(child: Text(label, style: const TextStyle(fontSize: 11))),
          Text('$value', style: const TextStyle(fontWeight: FontWeight.w800)),
        ]),
      );
}

class _ReportTile extends StatelessWidget {
  const _ReportTile(this.icon, this.label, this.color);
  final IconData icon;
  final String label;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
        width: 150,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: border),
            borderRadius: BorderRadius.circular(10)),
        child: Column(children: [
          CircleAvatar(
              backgroundColor: color.withValues(alpha: .1),
              child: Icon(icon, color: color)),
          const SizedBox(height: 8),
          Text(label,
              textAlign: TextAlign.center,
              style:
                  const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
        ]),
      );
}

class _BarChart extends StatelessWidget {
  const _BarChart();
  @override
  Widget build(BuildContext context) => Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: const [
          _Bar('बूथ 1', .78, '5,120'),
          _Bar('बूथ 2', .7, '4,980'),
          _Bar('बूथ 3', .85, '5,250'),
          _Bar('बूथ 4', .75, '5,000'),
          _Bar('बूथ 5', .8, '5,070'),
        ],
      );
}

class _Bar extends StatelessWidget {
  const _Bar(this.label, this.height, this.value);
  final String label;
  final double height;
  final String value;
  @override
  Widget build(BuildContext context) =>
      Column(mainAxisAlignment: MainAxisAlignment.end, children: [
        Text(value,
            style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w700)),
        const SizedBox(height: 5),
        Container(
            width: 26,
            height: 140 * height,
            decoration: BoxDecoration(
                color: blue, borderRadius: BorderRadius.circular(4))),
        const SizedBox(height: 5),
        Text(label, style: const TextStyle(fontSize: 9)),
      ]);
}

int _number(dynamic value) =>
    value is num ? value.toInt() : int.tryParse('$value') ?? 0;
int _support(Map data, String key) => (data['support'] as List? ?? [])
    .where((e) => e['_id'] == key)
    .fold<int>(0, (sum, e) => sum + _number(e['count']));
