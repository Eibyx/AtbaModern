import 'package:atba/screens/jobs_status_page.dart';
import 'package:atba/screens/modern/rss_page.dart';
import 'package:flutter/material.dart';

import 'common.dart';

class AutomationsPage extends StatelessWidget {
  const AutomationsPage({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Automatizaciones')),
    body: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(
          'Deja que TorBox trabaje.',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: 12),
        const Text(
          'Las reglas RSS se ejecutan en TorBox. Los trabajos de integración transfieren archivos hacia servicios remotos.',
        ),
        const SectionTitle('Reglas y transferencias'),
        Card(
          child: ListTile(
            leading: const Icon(Icons.rss_feed),
            title: const Text('Feeds RSS'),
            subtitle: const Text(
              'Fuentes, filtros y elementos detectados · plan Pro',
            ),
            trailing: const Icon(Icons.arrow_forward),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const RssPage()),
            ),
          ),
        ),
        Card(
          child: ListTile(
            leading: const Icon(Icons.sync_alt),
            title: const Text('Trabajos de integración'),
            subtitle: const Text(
              'Progreso, estados y cancelación de transferencias',
            ),
            trailing: const Icon(Icons.arrow_forward),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const JobsStatusPage()),
            ),
          ),
        ),
        const StatusMessage(
          'El seguimiento se actualiza mientras la app está en primer plano. No se promete entrega instantánea con la aplicación cerrada.',
        ),
      ],
    ),
  );
}
