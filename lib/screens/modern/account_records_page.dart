import 'package:atba/services/torbox_service.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:torbox_api/torbox_api.dart';

import 'common.dart';

class AccountRecordsPage extends StatefulWidget {
  const AccountRecordsPage({super.key});
  @override
  State<AccountRecordsPage> createState() => _AccountRecordsPageState();
}

class _AccountRecordsPageState extends State<AccountRecordsPage> {
  List<UserSubscription>? _subscriptions;
  List<UserTransaction>? _transactions;
  String? _error;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final service = context.read<TorboxAPI>().authenticatedApi!.user;
      final result = await Future.wait([
        service.getSubscriptions(),
        service.getTransactions(),
      ]);
      final subscriptions = result[0] as TorBoxResponse<List<UserSubscription>>;
      final transactions = result[1] as TorBoxResponse<List<UserTransaction>>;
      if (!subscriptions.success || !transactions.success) {
        throw StateError('Sin datos');
      }
      if (mounted) {
        setState(() {
          _subscriptions = subscriptions.data ?? [];
          _transactions = transactions.data ?? [];
          _error = null;
        });
      }
    } on Object {
      if (mounted) {
        setState(
          () => _error = 'No se pudieron consultar los registros de tu cuenta.',
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Suscripción y transacciones'),
      actions: [
        IconButton(
          tooltip: 'Actualizar',
          onPressed: _load,
          icon: const Icon(Icons.refresh),
        ),
      ],
    ),
    body: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        if (_error != null) StatusMessage(_error!, onRetry: _load),
        if (_subscriptions == null && _error == null)
          const LinearProgressIndicator(),
        const SectionTitle('Suscripciones'),
        if (_subscriptions?.isEmpty == true)
          const Text('Sin suscripciones registradas.'),
        ...?_subscriptions?.map(
          (s) => Card(
            child: ListTile(
              leading: const Icon(Icons.verified_outlined),
              title: Text(s.planName ?? s.planCode ?? 'Suscripción'),
              subtitle: Text(
                '${s.status ?? 'Estado no disponible'} · ${s.gateway ?? ''}\n${s.createdAt ?? ''}',
              ),
            ),
          ),
        ),
        const SectionTitle('Transacciones'),
        const Text(
          'Los importes se muestran tal como los informa la API. No se presupone una moneda no especificada.',
        ),
        if (_transactions?.isEmpty == true)
          const Text('Sin transacciones registradas.'),
        ...?_transactions?.map(
          (t) => Card(
            child: ListTile(
              leading: const Icon(Icons.receipt_long_outlined),
              title: Text(t.type),
              subtitle: Text(t.at),
              trailing: Text('${t.amount}'),
            ),
          ),
        ),
      ],
    ),
  );
}
