enum DownloadInputKind { magnet, torrentUrl, nzbUrl, web }

class DownloadInput {
  final Uri uri;
  final DownloadInputKind kind;
  final String key;
  final String? infoHash;
  const DownloadInput._(this.uri, this.kind, this.key, [this.infoHash]);
  static DownloadInput parse(String text) {
    final uri = Uri.tryParse(text.trim());
    if (uri == null || uri.userInfo.isNotEmpty || text.length > 16384) {
      throw const FormatException('Enlace no válido.');
    }
    if (uri.scheme == 'magnet') {
      final xt = uri.queryParametersAll['xt']
          ?.where((s) => s.toLowerCase().startsWith('urn:btih:'))
          .firstOrNull;
      final hash = xt?.substring(9);
      if (hash == null ||
          !RegExp(r'^(?:[0-9a-fA-F]{40}|[a-zA-Z2-7]{32})$').hasMatch(hash)) {
        throw const FormatException(
          'El magnet debe contener un hash BitTorrent válido.',
        );
      }
      final hex = hash.length == 40 ? hash.toLowerCase() : _base32ToHex(hash);
      return DownloadInput._(uri, DownloadInputKind.magnet, 'magnet:$hex', hex);
    }
    if (!{'https', 'http'}.contains(uri.scheme) || uri.host.isEmpty) {
      throw const FormatException('Usa un magnet o una URL HTTP/HTTPS.');
    }
    final path = uri.path.toLowerCase();
    final kind = path.endsWith('.torrent')
        ? DownloadInputKind.torrentUrl
        : path.endsWith('.nzb')
        ? DownloadInputKind.nzbUrl
        : DownloadInputKind.web;
    return DownloadInput._(uri, kind, uri.replace(fragment: '').toString());
  }

  static String _base32ToHex(String value) {
    const alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ234567';
    var bits = 0;
    var buffer = 0;
    final bytes = <int>[];
    for (final char in value.toUpperCase().split('')) {
      buffer = (buffer << 5) | alphabet.indexOf(char);
      bits += 5;
      if (bits >= 8) {
        bits -= 8;
        bytes.add((buffer >> bits) & 255);
        buffer &= (1 << bits) - 1;
      }
    }
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }
}
