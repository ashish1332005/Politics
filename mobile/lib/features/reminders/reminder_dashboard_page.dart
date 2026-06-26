import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/api_client.dart';
import '../../core/contact_actions.dart';
import '../../core/theme.dart';
import '../../layout/app_layout.dart';
import '../../widgets/common.dart';
import '../voters/voter_edit_page.dart';

class ReminderDashboardPage extends StatefulWidget {
  const ReminderDashboardPage({super.key});

  @override
  State<ReminderDashboardPage> createState() => _ReminderDashboardPageState();
}

class _ReminderDashboardPageState extends State<ReminderDashboardPage> {
  @override
  Widget build(BuildContext context) => AppPage(children: [
        const PageHeading(
          title: 'Follow-up Dashboard',
          subtitle: 'आज, overdue और आने वाले संपर्क',
        ),
        FutureBlock<Map<String, dynamic>>(
          load: () => api.get('/api/follow-ups/dashboard'),
          builder: (data) => DefaultTabController(
            length: 3,
            child: Column(children: [
              TabBar(tabs: [
                Tab(text: 'Overdue (${_items(data, 'overdue').length})'),
                Tab(text: 'आज (${_items(data, 'today').length})'),
                Tab(text: 'आने वाले (${_items(data, 'upcoming').length})'),
              ]),
              SizedBox(
                height: 560,
                child: TabBarView(children: [
                  _ReminderList(
                      items: _items(data, 'overdue'),
                      refresh: () => setState(() {}),
                      color: Colors.red),
                  _ReminderList(
                      items: _items(data, 'today'),
                      refresh: () => setState(() {}),
                      color: orange),
                  _ReminderList(
                      items: _items(data, 'upcoming'),
                      refresh: () => setState(() {}),
                      color: blue),
                ]),
              ),
            ]),
          ),
        ),
      ]);

  List<dynamic> _items(Map<String, dynamic> data, String key) =>
      List.from(data[key] ?? []);
}

class _ReminderList extends StatelessWidget {
  const _ReminderList(
      {required this.items, required this.refresh, required this.color});
  final List<dynamic> items;
  final VoidCallback refresh;
  final Color color;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const Center(child: Text('कोई reminder नहीं है'));
    }
    return ListView.builder(
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = Map<String, dynamic>.from(items[index]);
        final member = Map<String, dynamic>.from(item['member']);
        final followUp = Map<String, dynamic>.from(item['followUp']);
        return Card(
          child: ListTile(
            leading: CircleAvatar(
                backgroundColor: color.withValues(alpha: .12),
                child: Icon(Icons.notifications_active, color: color)),
            title: Text('${member['name'] ?? ''} — ${followUp['title'] ?? ''}',
                style: const TextStyle(fontWeight: FontWeight.w800)),
            subtitle: Text(
                '${DateFormat('dd-MM-yyyy').format(DateTime.parse('${followUp['dueAt']}'))} • ${member['village'] ?? member['organizationPost'] ?? ''}'),
            onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) =>
                        VoterEditPage(voter: member, onSaved: refresh))),
            trailing: Row(mainAxisSize: MainAxisSize.min, children: [
              IconButton(
                  onPressed: () =>
                      callNumber(context, '${member['mobile'] ?? ''}'),
                  icon: const Icon(Icons.call, color: blue)),
              IconButton(
                  onPressed: () => openWhatsApp(
                      context, '${member['mobile'] ?? ''}',
                      message: 'नमस्कार ${member['name'] ?? ''} जी,'),
                  icon: const Icon(Icons.chat, color: green)),
              IconButton(
                tooltip: 'पूरा करें',
                onPressed: () async {
                  await api.put(
                      '/api/follow-ups/${member['_id']}/${followUp['_id']}',
                      {'status': 'done'});
                  refresh();
                },
                icon: const Icon(Icons.check_circle_outline, color: green),
              ),
            ]),
          ),
        );
      },
    );
  }
}
