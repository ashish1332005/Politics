import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../layout/app_layout.dart';
import '../../widgets/mobile_components.dart';
import '../activity/activity_page.dart';
import '../booths/booth_page.dart';
import '../messages/bulk_message_page.dart';
import '../reminders/reminder_dashboard_page.dart';
import '../uploads/import_review_page.dart';
import '../reports/reports_page.dart';
import '../reports/political_dashboard_page.dart';
import '../reports/configurable_print_page.dart';
import '../uploads/smart_excel_import_page.dart';
import '../settings/settings_page.dart';
import '../uploads/upload_page.dart';
import '../users/booth_user_page.dart';

class MorePage extends StatelessWidget {
  const MorePage({super.key, required this.role});
  final String role;

  @override
  Widget build(BuildContext context) {
    final importOptions = <_Option>[
      _Option('PDF / Excel अपलोड', 'Voter list और bulk records import करें',
          Icons.cloud_upload_rounded, orange, const UploadPage()),
      if (role == 'admin')
        _Option('Smart Excel Import', 'Column mapping और update preview',
            Icons.rule_folder_rounded, green, const SmartExcelImportPage()),
      if (role == 'admin')
        _Option(
            'EPIC Review Queue',
            'Missing/duplicate EPIC records merge करें',
            Icons.fact_check_rounded,
            purple,
            const ImportReviewPage()),
    ];
    final workOptions = <_Option>[
      _Option('Advanced Print', 'Selected voters + custom fields print करें',
          Icons.print_rounded, blue, const ConfigurablePrintPage()),
      if (role == 'admin')
        _Option('WhatsApp Campaign', 'QR sender, drafts और paced bulk queue',
            Icons.campaign_rounded, green, const BulkMessagePage()),
      _Option(
          'Follow-up Dashboard',
          'आज, overdue और upcoming reminders',
          Icons.notifications_active_rounded,
          orange,
          const ReminderDashboardPage()),
    ];
    final reportOptions = <_Option>[
      _Option('Political Dashboard', 'Strong/weak booth और undecided analysis',
          Icons.insights_rounded, blue, const PoliticalDashboardPage()),
      _Option('रिपोर्ट', 'सभी reports देखें और download करें',
          Icons.bar_chart_rounded, orange, const ReportsPage()),
      _Option('गतिविधि लॉग', 'Import, update और user activity देखें',
          Icons.history_rounded, const Color(0xff10a9a0), const ActivityPage()),
    ];
    final adminOptions = <_Option>[
      if (role == 'admin')
        _Option('बूथ प्रबंधन', 'बूथ की जानकारी जोड़ें और edit करें',
            Icons.how_to_vote_rounded, blue, const BoothPage()),
      if (role == 'admin')
        _Option('बूथ उपयोगकर्ता', 'Users जोड़ें और booth assign करें',
            Icons.supervisor_account_rounded, green, const BoothUserPage()),
      _Option('सेटिंग्स', 'Backup, sync और app settings',
          Icons.settings_rounded, purple, const SettingsPage()),
    ];

    return AppPage(children: [
      AppHeroBanner(
        title: 'अधिक विकल्प',
        subtitle:
            'कम इस्तेमाल होने वाले features को categories में रखा है ताकि mobile पर जल्दी मिलें',
        icon: Icons.grid_view_rounded,
        primaryAction: FilledButton.icon(
          style: FilledButton.styleFrom(
              backgroundColor: Colors.white, foregroundColor: blue),
          onPressed: () =>
              _open(context, const UploadPage(), 'PDF / Excel अपलोड'),
          icon: const Icon(Icons.upload_file_rounded),
          label: const Text('Import Data'),
        ),
      ),
      _OptionSection(title: 'डेटा Import और Review', options: importOptions),
      _OptionSection(title: 'काम और Communication', options: workOptions),
      _OptionSection(title: 'Reports और Analysis', options: reportOptions),
      _OptionSection(title: 'Admin और Settings', options: adminOptions),
    ]);
  }

  static void _open(BuildContext context, Widget page, String title) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _StandalonePage(title: title, child: page),
      ),
    );
  }
}

class _OptionSection extends StatelessWidget {
  const _OptionSection({required this.title, required this.options});
  final String title;
  final List<_Option> options;

  @override
  Widget build(BuildContext context) => SectionCard(
        title: title,
        icon: Icons.apps_rounded,
        child: LayoutBuilder(builder: (context, constraints) {
          final columns = constraints.maxWidth >= 900
              ? 3
              : constraints.maxWidth >= 560
                  ? 2
                  : 1;
          final width = (constraints.maxWidth - (columns - 1) * 10) / columns;
          return Wrap(
            spacing: 10,
            runSpacing: 10,
            children: options
                .map((option) => SizedBox(
                      width: width,
                      child: QuickActionTile(
                        icon: option.icon,
                        label: option.title,
                        subtitle: option.subtitle,
                        color: option.color,
                        onTap: () =>
                            MorePage._open(context, option.page, option.title),
                      ),
                    ))
                .toList(),
          );
        }),
      );
}

class _StandalonePage extends StatelessWidget {
  const _StandalonePage({required this.title, required this.child});
  final String title;
  final Widget child;
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: Text(title),
          backgroundColor: Colors.white,
          foregroundColor: navy,
          surfaceTintColor: Colors.white,
          actions: [
            IconButton(
              tooltip: 'बंद करें',
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.close_rounded),
            ),
          ],
        ),
        body: child,
      );
}

class _Option {
  const _Option(this.title, this.subtitle, this.icon, this.color, this.page);
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final Widget page;
}
