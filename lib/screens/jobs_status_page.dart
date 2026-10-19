import 'dart:async';

import 'package:atba/services/adaptive_poller.dart';
import 'package:atba/services/local_event_notifier.dart';
import 'package:atba/services/torbox_service.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:torbox_api/torbox_api.dart';

class JobsStatusPage extends StatefulWidget {
  const JobsStatusPage({super.key});
  @override
  State<JobsStatusPage> createState() => _JobsStatusPageState();
}

class _JobsStatusPageState extends State<JobsStatusPage>
    with WidgetsBindingObserver {
  late final AdaptivePoller _poller;
  List<IntegrationJobData>? _jobs;
  String? _error;
  final LocalEventNotifier _events = LocalEventNotifier();
  final Set<int> _cancelling = {};
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _poller = AdaptivePoller(
      poll: _refresh,
      onError: (_) {
        if (mounted) {
          setState(
            () => _error = 'No se pudieron actualizar los trabajos. Se reintentará automáticamente.',
          );
        }
      },
    );
    _poller.start();
  }

  Future<bool> _refresh() async {
    final api = context.read<TorboxAPI>().authenticatedApi;
    if (api == null) throw StateError('Conecta TorBox primero.');
    final response = await api.integrations.getAllJobs();
    if (!response.success) {
      throw StateError('No se pudieron consultar los trabajos.');
    }
    final jobs = response.data ?? [];
    jobs.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    if (!mounted) return false;
    final previous = {
      for (final job in _jobs ?? <IntegrationJobData>[]) job.id: job.status,
    };
    for (final job in jobs) {
      if (previous.containsKey(job.id) &&
          previous[job.id] != job.status &&
          {'completed', 'failed'}.contains(job.status)) {
        await _events.show(
          id: job.id,
          title:
              '${job.integration} · ${job.status == 'completed' ? 'Transferencia completada' : 'Transferencia fallida'}',
          body: 'Trabajo de integración #${job.id}',
        );
      }
    }
    if (mounted) {
      setState(() {
        _jobs = jobs;
        _error = null;
      });
    }
    return jobs.any(
      (j) => !{'completed', 'failed', 'cancelled'}.contains(j.status),
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _poller.start();
    } else {
      _poller.pause();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _poller.dispose();
    super.dispose();
  }

  Future<void> _cancel(IntegrationJobData job) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Cancelar la transferencia?'),
        content: const Text(
          'Se detendrá este trabajo de integración; los archivos de TorBox se conservan.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Volver'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Cancelar trabajo'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _cancelling.add(job.id));
    try {
      final response = await context
          .read<TorboxAPI>()
          .authenticatedApi!
          .integrations
          .cancelJob(job.id);
      if (!response.success) throw StateError('No se pudo cancelar.');
      await _poller.refresh();
    } on Object {
      if (mounted) {
        setState(
          () => _error = 'No se pudo cancelar el trabajo. Comprueba su estado antes de reintentar.',
        );
      }
    } finally {
      if (mounted) setState(() => _cancelling.remove(job.id));
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Trabajos de integración'),
      actions: [
        IconButton(
          tooltip: 'Actualizar',
          onPressed: _poller.refresh,
          icon: const Icon(Icons.refresh),
        ),
      ],
    ),
    body: RefreshIndicator(
      onRefresh: _poller.refresh,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        itemCount: (_jobs?.length ?? 0) + 1,
        itemBuilder: (context, index) {
          if (index == 0) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Column(
                children: [
                  const Text(
                    'Progreso de TorBox al servicio remoto. Es independiente de la descarga al teléfono.',
                  ),
                  if (_error != null)
                    Text(
                      _error!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  if (_jobs == null && _error == null)
                    const LinearProgressIndicator(),
                  if (_jobs?.isEmpty == true)
                    const Padding(
                      padding: EdgeInsets.all(32),
                      child: Text('No hay trabajos de integración.'),
                    ),
                ],
              ),
            );
          }
          final job = _jobs![index - 1];
          final progress = job.progress.isFinite
              ? job.progress.clamp(0.0, 1.0)
              : 0.0;
          final done = {
            'completed',
            'failed',
            'cancelled',
          }.contains(job.status);
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    job.fileName.isEmpty ? 'Trabajo #${job.id}' : job.fileName,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  Text(
                    '${job.integration} · ${job.status} · ${(progress * 100).toStringAsFixed(1)} %',
                  ),
                  const SizedBox(height: 8),
                  LinearProgressIndicator(value: progress),
                  if (job.status == 'failed')
                    const Text(
                      'El servicio remoto no completó la transferencia. La conexión local se conserva.',
                    ),
                  if (!done)
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: _cancelling.contains(job.id)
                            ? null
                            : () => _cancel(job),
                        child: const Text('Cancelar trabajo'),
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    ),
  );
}
