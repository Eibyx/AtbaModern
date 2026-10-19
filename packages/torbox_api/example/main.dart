import 'dart:io';
import 'package:torbox_api/torbox_api.dart';

Future<void> main() async {
  final token = Platform.environment['TORBOX_API_KEY'];
  if (token == null || token.isEmpty) {
    stderr.writeln(
      'Configure TORBOX_API_KEY securely before running this example.',
    );
    exitCode = 1;
    return;
  }
  final api = TorboxApi(token: token);
  try {
    final response = await api.torrents.getTorrentList(limit: 10);
    stdout.writeln('Transfer count: ${response.data?.length ?? 0}');
  } on TorboxApiException {
    stderr.writeln('TorBox request failed. No credentials or URLs are logged.');
    exitCode = 1;
  } finally {
    api.close();
  }
}
