import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../layout/app_layout.dart';
import '../../widgets/common.dart';

class BoothUserPage extends StatefulWidget {
  const BoothUserPage({super.key});

  @override
  State<BoothUserPage> createState() => _BoothUserPageState();
}

class _BoothUserPageState extends State<BoothUserPage> {
  void refresh() => setState(() {});

  @override
  Widget build(BuildContext context) => AppPage(children: [
        Align(
          alignment: Alignment.centerRight,
          child: FilledButton.icon(
            onPressed: () => showDialog(
              context: context,
              builder: (_) => BoothUserForm(onSaved: refresh),
            ),
            icon: const Icon(Icons.person_add_alt),
            label: const Text('बूथ यूजर जोड़ें'),
          ),
        ),
        FutureBlock<List<dynamic>>(
          load: () => api.list('/api/auth/users'),
          builder: (users) => Panel(
            title: 'बूथ यूजर प्रबंधन',
            child: Column(
              children: users
                  .where((u) => u['role'] == 'booth')
                  .map(
                    (u) => ListTile(
                      leading: CircleAvatar(
                        child: Icon(u['active'] == false
                            ? Icons.person_off
                            : Icons.person),
                      ),
                      title: Text('${u['name'] ?? '-'}'),
                      subtitle: Text(
                        '${u['email'] ?? '-'}\nबूथ: ${u['assignedBooth']?['number'] ?? 'आवंटित नहीं'}',
                      ),
                      isThreeLine: true,
                      trailing: Wrap(
                        spacing: 4,
                        children: [
                          Switch(
                            value: u['active'] != false,
                            onChanged: (value) async {
                              await api.put('/api/auth/users/${u['_id']}',
                                  {'active': value});
                              refresh();
                            },
                          ),
                          IconButton(
                            tooltip: 'संपादित करें',
                            onPressed: () => showDialog(
                              context: context,
                              builder: (_) => BoothUserForm(
                                  user: Map<String, dynamic>.from(u),
                                  onSaved: refresh),
                            ),
                            icon: const Icon(Icons.edit_outlined),
                          ),
                          IconButton(
                            tooltip: 'पासवर्ड रीसेट',
                            onPressed: () => showDialog(
                              context: context,
                              builder: (_) =>
                                  ResetPasswordDialog(userId: '${u['_id']}'),
                            ),
                            icon: const Icon(Icons.password),
                          ),
                        ],
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
        ),
      ]);
}

class BoothUserForm extends StatefulWidget {
  const BoothUserForm({super.key, this.user, required this.onSaved});
  final Map<String, dynamic>? user;
  final VoidCallback onSaved;

  @override
  State<BoothUserForm> createState() => _BoothUserFormState();
}

class _BoothUserFormState extends State<BoothUserForm> {
  late final name = TextEditingController(text: widget.user?['name'] ?? '');
  late final email = TextEditingController(text: widget.user?['email'] ?? '');
  late final phone = TextEditingController(text: widget.user?['phone'] ?? '');
  final password = TextEditingController();
  String? boothId;
  bool active = true;
  bool canPrint = false;
  String error = '';

  @override
  void initState() {
    super.initState();
    boothId =
        widget.user?['assignedBooth']?['_id'] ?? widget.user?['assignedBooth'];
    active = widget.user?['active'] != false;
    canPrint = widget.user?['permissions']?['canPrintProfiles'] == true;
  }

  Future<void> save() async {
    try {
      final body = <String, dynamic>{
        'name': name.text.trim(),
        'email': email.text.trim(),
        'phone': phone.text.trim(),
        'role': 'booth',
        'assignedBooth': boothId,
        'active': active,
        'permissions': {'canPrintProfiles': canPrint},
      };
      if (password.text.isNotEmpty) body['password'] = password.text;
      if (widget.user == null) {
        await api.post('/api/auth/users', body);
      } else {
        await api.put('/api/auth/users/${widget.user!['_id']}', body);
      }
      widget.onSaved();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      setState(() => error = e.toString().replaceFirst('Exception: ', ''));
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: Text(
            widget.user == null ? 'बूथ यूजर जोड़ें' : 'बूथ यूजर संपादित करें'),
        content: SizedBox(
          width: 520,
          child: SingleChildScrollView(
            child: Column(children: [
              TextField(
                  controller: name,
                  decoration: const InputDecoration(labelText: 'नाम')),
              const SizedBox(height: 10),
              TextField(
                  controller: email,
                  decoration: const InputDecoration(labelText: 'ईमेल')),
              const SizedBox(height: 10),
              TextField(
                  controller: phone,
                  decoration: const InputDecoration(labelText: 'मोबाइल')),
              if (widget.user == null) ...[
                const SizedBox(height: 10),
                TextField(
                    controller: password,
                    obscureText: true,
                    decoration: const InputDecoration(labelText: 'पासवर्ड')),
              ],
              const SizedBox(height: 10),
              FutureBlock<List<dynamic>>(
                load: () => api.list('/api/booths'),
                builder: (booths) => DropdownButtonFormField<String>(
                  initialValue: boothId,
                  decoration:
                      const InputDecoration(labelText: 'बूथ आवंटित करें'),
                  items: booths
                      .map((b) => DropdownMenuItem<String>(
                            value: '${b['_id']}',
                            child: Text('${b['number']} - ${b['name']}'),
                          ))
                      .toList(),
                  onChanged: (value) => setState(() => boothId = value),
                ),
              ),
              SwitchListTile(
                value: active,
                onChanged: (value) => setState(() => active = value),
                title: const Text('यूजर सक्रिय'),
              ),
              SwitchListTile(
                value: canPrint,
                onChanged: (value) => setState(() => canPrint = value),
                title: const Text('प्रोफाइल प्रिंट अनुमति'),
              ),
              if (error.isNotEmpty)
                Text(error, style: const TextStyle(color: Colors.red)),
            ]),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('रद्द करें')),
          FilledButton.icon(
              onPressed: save,
              icon: const Icon(Icons.save),
              label: const Text('सेव करें')),
        ],
      );
}

class ResetPasswordDialog extends StatefulWidget {
  const ResetPasswordDialog({super.key, required this.userId});
  final String userId;

  @override
  State<ResetPasswordDialog> createState() => _ResetPasswordDialogState();
}

class _ResetPasswordDialogState extends State<ResetPasswordDialog> {
  final password = TextEditingController();
  String error = '';

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('पासवर्ड रीसेट'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(
              controller: password,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'नया पासवर्ड')),
          if (error.isNotEmpty)
            Text(error, style: const TextStyle(color: Colors.red)),
        ]),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('रद्द करें')),
          FilledButton(
            onPressed: () async {
              if (password.text.length < 6) {
                setState(() => error = 'पासवर्ड कम से कम 6 अक्षर का हो');
                return;
              }
              await api.put('/api/auth/users/${widget.userId}',
                  {'password': password.text});
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('रीसेट करें'),
          ),
        ],
      );
}
