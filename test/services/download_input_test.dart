import 'package:atba/services/download_input.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'detects documented transfer inputs without accepting arbitrary schemes',
    () {
      expect(
        DownloadInput.parse(
          'magnet:?xt=urn:btih:0123456789012345678901234567890123456789',
        ).kind,
        DownloadInputKind.magnet,
      );
      expect(
        DownloadInput.parse('https://example.test/file.NZB?download=1').kind,
        DownloadInputKind.nzbUrl,
      );
      expect(
        DownloadInput.parse('https://example.test/file.torrent').kind,
        DownloadInputKind.torrentUrl,
      );
      expect(
        DownloadInput.parse('https://example.test/file.zip').kind,
        DownloadInputKind.web,
      );
      for (final input in [
        'javascript:alert(1)',
        'file:///etc/passwd',
        'https://user:secret@example.test/file',
        'magnet:?dn=no-hash',
        'not a url',
      ]) {
        expect(() => DownloadInput.parse(input), throwsFormatException);
      }
    },
  );
  test('equivalent magnets deduplicate independently of tracker ordering', () {
    final a = DownloadInput.parse(
      'magnet:?xt=urn:btih:ABCDEF0123456789012345678901234567890123&dn=one',
    );
    final b = DownloadInput.parse(
      'magnet:?dn=two&xt=urn:btih:abcdef0123456789012345678901234567890123',
    );
    expect(a.key, b.key);
    expect(
      DownloadInput.parse(
        'magnet:?xt=urn:btih:AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',
      ).infoHash,
      '0000000000000000000000000000000000000000',
    );
  });
}
