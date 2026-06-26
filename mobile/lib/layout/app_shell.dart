import 'package:flutter/material.dart';

import '../core/api_client.dart';
import '../core/theme.dart';
import '../features/dashboard/dashboard_page.dart';
import '../features/families/family_page.dart';
import '../features/more/more_page.dart';
import '../features/reports/reports_page.dart';
import '../features/voters/voter_management_page.dart';
import 'app_layout.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key, required this.role});
  final String role;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int selected = 0;
  int refreshVersion = 0;

  void select(int index) => setState(() => selected = index);

  @override
  void initState() {
    super.initState();
    api.dataVersion.addListener(_onDataChanged);
  }

  @override
  void dispose() {
    api.dataVersion.removeListener(_onDataChanged);
    super.dispose();
  }

  void _onDataChanged() {
    if (mounted) setState(() => refreshVersion = api.dataVersion.value);
  }

  List<NavItem> get items => [
        NavItem(
          'होम',
          Icons.home_outlined,
          DashboardPage(
            key: ValueKey('dashboard-$refreshVersion'),
            onNavigate: select,
          ),
        ),
        NavItem(
          'मतदाता',
          Icons.groups_outlined,
          VoterManagementPage(key: ValueKey('voters-$refreshVersion')),
        ),
        NavItem(
          'परिवार',
          Icons.family_restroom,
          FamilyPage(key: ValueKey('families-$refreshVersion')),
        ),
        NavItem(
          'रिपोर्ट',
          Icons.bar_chart_outlined,
          ReportsPage(key: ValueKey('reports-$refreshVersion')),
        ),
        NavItem(
          'अधिक',
          Icons.grid_view_rounded,
          MorePage(key: ValueKey('more-$refreshVersion'), role: widget.role),
        ),
      ];

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 900;
    final currentItems = items;
    return Scaffold(
      drawer: wide ? null : AppDrawer(role: widget.role, openPage: (_, __) {}),
      body: Row(children: [
        if (wide)
          DesktopSidebar(
              items: currentItems, selected: selected, onSelect: select),
        Expanded(
          child: Column(children: [
            const MobileHeader(),
            Expanded(
              child: IndexedStack(
                index: selected,
                children: currentItems.map((e) => e.page).toList(),
              ),
            ),
          ]),
        ),
      ]),
      bottomNavigationBar: wide
          ? null
          : Container(
              margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: border),
                borderRadius: BorderRadius.circular(24),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x1a071b4b),
                    blurRadius: 22,
                    offset: Offset(0, 10),
                  ),
                ],
              ),
              child: SafeArea(
                top: false,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: NavigationBar(
                    height: 66,
                    backgroundColor: Colors.white,
                    indicatorColor: softBlue,
                    selectedIndex: selected,
                    labelBehavior:
                        NavigationDestinationLabelBehavior.alwaysShow,
                    onDestinationSelected: select,
                    destinations: currentItems
                        .map((e) => NavigationDestination(
                              icon: Icon(e.icon, color: muted),
                              selectedIcon: Icon(e.icon, color: blue),
                              label: e.label,
                            ))
                        .toList(),
                  ),
                ),
              ),
            ),
    );
  }
}
