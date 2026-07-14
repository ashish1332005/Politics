import 'package:flutter/material.dart';

import '../core/api_client.dart';
import '../core/theme.dart';
import '../features/notifications/celebrations_page.dart';

class NavItem {
  const NavItem(this.label, this.icon, this.page);
  final String label;
  final IconData icon;
  final Widget page;
}

class CongressMark extends StatelessWidget {
  const CongressMark({super.key, this.size = 46});
  final double size;

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: const [
            BoxShadow(
                color: Color(0x1f071b4b), blurRadius: 14, offset: Offset(0, 5)),
          ],
          border: Border.all(
              color: Colors.white.withValues(alpha: .75), width: 1.4),
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [orange, Colors.white, green],
            stops: [0, .48, 1],
          ),
        ),
        alignment: Alignment.center,
        child: Text('INC',
            style: TextStyle(
                color: navy,
                fontSize: size * .24,
                fontWeight: FontWeight.w900,
                letterSpacing: -.5)),
      );
}

class MobileHeader extends StatelessWidget {
  const MobileHeader({
    super.key,
    this.title = 'मतदाता फोन बुक',
    this.onSearch,
  });
  final String title;
  final VoidCallback? onSearch;

  @override
  Widget build(BuildContext context) {
    final isPhone = MediaQuery.sizeOf(context).width < 640;
    return Container(
      padding: EdgeInsets.fromLTRB(isPhone ? 8 : 18, 5, isPhone ? 8 : 18, 7),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: border)),
      ),
      child: SafeArea(
        bottom: false,
        child: Row(children: [
          if (Scaffold.maybeOf(context)?.hasDrawer ?? false)
            IconButton(
              tooltip: 'मेनू खोलें',
              onPressed: () => Scaffold.of(context).openDrawer(),
              icon: const Icon(Icons.menu_rounded, color: navy, size: 26),
            ),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: navy,
                        fontSize: 18,
                        fontWeight: FontWeight.w900)),
                const Text('आसान मतदाता संपर्क और प्रबंधन',
                    style: TextStyle(color: muted, fontSize: 10)),
              ],
            ),
          ),
          if (onSearch != null)
            IconButton(
              tooltip: 'मतदाता खोजें',
              onPressed: onSearch,
              icon: const Icon(Icons.search_rounded, color: navy),
            ),
          FutureBuilder<Map<String, dynamic>>(
            future: api.get('/api/notifications/today'),
            builder: (context, snapshot) {
              final count = snapshot.data?['count'] ?? 0;
              return Stack(clipBehavior: Clip.none, children: [
                IconButton.filledTonal(
                  tooltip: 'आज की सूचनाएँ',
                  style: IconButton.styleFrom(
                    backgroundColor: softBlue,
                  ),
                  onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const CelebrationsPage())),
                  icon: Icon(Icons.notifications_none_rounded,
                      color: navy, size: 23),
                ),
                if (count > 0)
                  Positioned(
                    right: 1,
                    top: -1,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 5, vertical: 3),
                      decoration: BoxDecoration(
                        color: rose,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white, width: 1.5),
                      ),
                      child: Text('$count',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.w900)),
                    ),
                  ),
              ]);
            },
          ),
        ]),
      ),
    );
  }
}

class DesktopSidebar extends StatelessWidget {
  const DesktopSidebar(
      {super.key,
      required this.items,
      required this.selected,
      required this.onSelect});
  final List<NavItem> items;
  final int selected;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) => Material(
        color: deepNavy,
        child: SizedBox(
          width: 236,
          child: SafeArea(
            child: Column(children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 20, 16, 18),
                child: Row(children: [
                  CongressMark(size: 42),
                  SizedBox(width: 10),
                  Expanded(
                      child: Text('कांग्रेस संगठन\nप्रबंधन प्रणाली',
                          style: TextStyle(
                              color: Colors.white,
                              height: 1.25,
                              fontWeight: FontWeight.w900))),
                ]),
              ),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: items.length,
                  itemBuilder: (_, i) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: ListTile(
                      selected: selected == i,
                      selectedTileColor: blue,
                      tileColor: Colors.white.withValues(alpha: .03),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                      leading: Icon(items[i].icon, color: Colors.white),
                      title: Text(items[i].label,
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800)),
                      onTap: () => onSelect(i),
                    ),
                  ),
                ),
              ),
            ]),
          ),
        ),
      );
}

class AppPage extends StatelessWidget {
  const AppPage({super.key, required this.children, this.padding});
  final List<Widget> children;
  final EdgeInsets? padding;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final resolvedPadding = padding ??
        EdgeInsets.fromLTRB(
            width < 640 ? 14 : 20, 18, width < 640 ? 14 : 20, 30);
    return Material(
      color: bg,
      child: ListView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: resolvedPadding,
        children: children
            .map((e) =>
                Padding(padding: const EdgeInsets.only(bottom: 16), child: e))
            .toList(),
      ),
    );
  }
}

class PageHeading extends StatelessWidget {
  const PageHeading(
      {super.key, required this.title, this.subtitle, this.action});
  final String title;
  final String? subtitle;
  final Widget? action;

  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, c) {
        final compact = c.maxWidth < 620;
        final text =
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: Theme.of(context).textTheme.headlineSmall),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(subtitle!, style: const TextStyle(color: muted)),
          ],
        ]);
        if (action == null) return text;
        if (compact) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [text, const SizedBox(height: 12), action!],
          );
        }
        return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(child: text),
          action!,
        ]);
      });
}

class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key, required this.role, required this.openPage});
  final String role;
  final void Function(Widget page, String title) openPage;

  @override
  Widget build(BuildContext context) => Drawer(
        child: SafeArea(
          child: Column(children: [
            const Padding(
              padding: EdgeInsets.all(20),
              child: Row(children: [
                CongressMark(),
                SizedBox(width: 12),
                Expanded(
                    child: Text('कांग्रेस संगठन',
                        style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            color: navy))),
              ]),
            ),
            const Divider(),
            ListTile(
                leading: const CircleAvatar(
                    backgroundColor: softBlue,
                    child: Icon(Icons.person_outline, color: blue)),
                title: Text(api.user?['name'] ?? 'Admin User',
                    style: const TextStyle(fontWeight: FontWeight.w900)),
                subtitle: Text(role)),
            const Spacer(),
            const Padding(
              padding: EdgeInsets.all(20),
              child: Text('सुरक्षित मतदाता प्रबंधन प्रणाली',
                  style: TextStyle(color: muted)),
            ),
          ]),
        ),
      );
}
