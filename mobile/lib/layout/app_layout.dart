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
  const MobileHeader({super.key, this.blueStyle = true});
  final bool blueStyle;

  @override
  Widget build(BuildContext context) {
    final foreground = blueStyle ? Colors.white : navy;
    final isPhone = MediaQuery.sizeOf(context).width < 640;
    return Container(
      padding: EdgeInsets.fromLTRB(isPhone ? 10 : 18, 8, isPhone ? 10 : 18, 10),
      decoration: BoxDecoration(
        gradient: blueStyle
            ? const LinearGradient(
                colors: [Color(0xff062c8f), royalBlue, blue],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : null,
        color: blueStyle ? null : Colors.white,
        boxShadow: const [
          BoxShadow(
              color: Color(0x12071b4b), blurRadius: 18, offset: Offset(0, 8)),
        ],
      ),
      child: SafeArea(
        bottom: false,
        child: Row(children: [
          if (Scaffold.maybeOf(context)?.hasDrawer ?? false)
            IconButton(
              tooltip: 'मेनू',
              onPressed: () => Scaffold.of(context).openDrawer(),
              icon: Icon(Icons.menu_rounded, color: foreground, size: 27),
            ),
          CongressMark(size: isPhone ? 38 : 42),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('कांग्रेस संगठन',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        color: foreground,
                        fontSize: isPhone ? 16 : 18,
                        fontWeight: FontWeight.w900)),
                Text('संगठन ही शक्ति है',
                    style: TextStyle(
                        color: foreground.withValues(alpha: .78),
                        fontSize: 11)),
              ],
            ),
          ),
          FutureBuilder<Map<String, dynamic>>(
            future: api.get('/api/notifications/today'),
            builder: (context, snapshot) {
              final count = snapshot.data?['count'] ?? 0;
              return Stack(clipBehavior: Clip.none, children: [
                IconButton.filledTonal(
                  tooltip: 'आज के Birthday / Anniversary',
                  style: IconButton.styleFrom(
                    backgroundColor: blueStyle
                        ? Colors.white.withValues(alpha: .14)
                        : softBlue,
                  ),
                  onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const CelebrationsPage())),
                  icon: Icon(Icons.notifications_none_rounded,
                      color: foreground, size: 24),
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
          if (!isPhone) ...[
            const SizedBox(width: 8),
            CircleAvatar(
              radius: 20,
              backgroundColor: blueStyle ? Colors.white : softBlue,
              child: const Icon(Icons.person_rounded, color: navy),
            ),
          ],
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
