import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../layout/app_layout.dart';
import '../../widgets/common.dart';

class ActivityPage extends StatelessWidget {
  const ActivityPage({super.key});

  @override
  Widget build(BuildContext context) => FutureBlock<List<dynamic>>(
        load: () => api.list('/api/activity'),
        builder: (items) => AppPage(children: [
          Panel(
              title: 'गतिविधि लॉग',
              child: Column(
                  children: items
                      .map((a) => ListTile(
                            leading: const Icon(Icons.history),
                            title: Text('${a['action'] ?? '-'}'),
                            subtitle: Text('${a['createdAt'] ?? ''}'),
                          ))
                      .toList())),
        ]),
      );
}
