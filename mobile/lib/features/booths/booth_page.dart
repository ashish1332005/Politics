import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../layout/app_layout.dart';
import '../../widgets/common.dart';

class BoothPage extends StatelessWidget {
  const BoothPage({super.key});

  @override
  Widget build(BuildContext context) => FutureBlock<List<dynamic>>(
        load: () => api.list('/api/booths'),
        builder: (items) => AppPage(children: [
          Panel(
              title: 'बूथ प्रबंधन',
              child: Column(children: [
                Align(
                    alignment: Alignment.centerRight,
                    child: FilledButton.icon(
                        onPressed: () {},
                        icon: const Icon(Icons.add),
                        label: const Text('बूथ जोड़ें'))),
                ...items.map((b) => ListTile(
                    leading: const Icon(Icons.home_work_outlined),
                    title: Text('${b['number']} - ${b['name']}'),
                    subtitle: const Text('कुल मतदाता reports में दिखेंगे'),
                    trailing: const Icon(Icons.edit))),
              ])),
        ]),
      );
}
