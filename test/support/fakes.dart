import 'package:atba/services/secure_storage_service.dart';

class MemorySecureStorage extends SecureStorageService {
  final Map<String, String> values;
  MemorySecureStorage([Map<String, String>? values]) : values = values ?? {};
  @override
  Future<String?> read(String key) async => values[key];
  @override
  Future<void> write(String key, String value) async {
    values[key] = value;
  }

  @override
  Future<void> delete(String key) async {
    values.remove(key);
  }
}

Map<String, dynamic> transferJson({int id = 1, double progress = 0.2}) => {
  'id': id,
  'name': 'Transferencia $id',
  'created_at': '2026-01-01T00:00:00Z',
  'updated_at': '2026-01-01T00:00:00Z',
  'size': 1000,
  'active': progress < 1,
  'auth_id': 'example-account',
  'download_state': progress >= 1 ? 'completed' : 'downloading',
  'progress': progress,
  'download_speed': 10,
  'upload_speed': 0,
  'eta': 80,
  'torrent_file': false,
  'expires_at': null,
  'download_present': progress >= 1,
  'download_finished': progress >= 1,
  'files': <Map<String, dynamic>>[],
  'inactive_check': 0,
  'availability': 1,
  'hash': 'example-hash',
  'magnet': null,
  'seeds': 1,
  'peers': 0,
  'ratio': 0.0,
  'download_path': '',
  'tracker': '',
  'total_uploaded': 0,
  'total_downloaded': 200,
  'cached': false,
  'owner': 'example-account',
  'seed_torrent': false,
  'allow_zipped': true,
  'long_term_seeding': false,
  'tracker_message': null,
  'error': '',
  'server': 1,
};
