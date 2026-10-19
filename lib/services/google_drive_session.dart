import 'dart:convert';

import 'package:atba/config/constants.dart';
import 'package:atba/services/secure_storage_service.dart';

/// An OAuth access token is distinct from the TorBox API key.
class GoogleDriveSession {
  final String accessToken;
  final DateTime? expiresAt;

  const GoogleDriveSession(this.accessToken, {this.expiresAt});

  bool isExpired(DateTime now) =>
      expiresAt != null && !expiresAt!.isAfter(now.toUtc());

  static DateTime? parseExpiry(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    final unix = num.tryParse(value);
    if (unix != null && unix.isFinite && unix > 0) {
      final milliseconds = (unix < 100000000000 ? unix * 1000 : unix).round();
      if (milliseconds > 8640000000000000) return null;
      return DateTime.fromMillisecondsSinceEpoch(milliseconds, isUtc: true);
    }
    return DateTime.tryParse(value)?.toUtc();
  }

  static GoogleDriveSession? fromCallback(Uri uri) {
    if (uri.scheme != 'https' ||
        uri.host != 'torbox.app' ||
        uri.port != 443 ||
        uri.userInfo.isNotEmpty ||
        uri.path != '/oauth/google/success') {
      return null;
    }
    if (uri.queryParametersAll['token']?.length != 1 ||
        (uri.queryParametersAll['expires_at']?.length ?? 0) > 1) {
      return null;
    }
    final token = uri.queryParameters['token']?.trim();
    if (token == null || token.isEmpty) return null;
    final rawExpiry = uri.queryParameters['expires_at'];
    final expiry = parseExpiry(rawExpiry);
    if (rawExpiry != null && rawExpiry.isNotEmpty && expiry == null) {
      return null;
    }
    return GoogleDriveSession(token, expiresAt: expiry);
  }
}

/// Atomic secure record, with migration from the original storage keys.
class GoogleDriveSessionStore {
  static const recordKey = 'google_drive_session_v1';
  final SecureStorageService storage;
  final DateTime Function() now;
  final String? Function()? legacyExpiry;

  GoogleDriveSessionStore(
    this.storage, {
    DateTime Function()? now,
    this.legacyExpiry,
  }) : now = now ?? DateTime.now;

  Future<void> save(GoogleDriveSession session) async {
    if (session.accessToken.trim().isEmpty) {
      throw ArgumentError('La credencial de Google no puede estar vacía.');
    }
    await storage.write(
      recordKey,
      jsonEncode({
        'version': 1,
        'access_token': session.accessToken,
        'expires_at': session.expiresAt?.toUtc().toIso8601String(),
      }),
    );
  }

  Future<GoogleDriveSession?> restore() async {
    final record = await storage.read(recordKey);
    if (record != null) {
      final json = jsonDecode(record) as Map<String, dynamic>;
      if (json['version'] != 1) {
        throw const FormatException('Formato de sesión no compatible.');
      }
      final token = json['access_token'] as String?;
      if (token == null || token.isEmpty) {
        throw const FormatException('Sesión de Google incompleta.');
      }
      return GoogleDriveSession(
        token,
        expiresAt: GoogleDriveSession.parseExpiry(
          json['expires_at'] as String?,
        ),
      );
    }
    final token = await storage.read(Constants.googleDriveToken);
    if (token == null || token.isEmpty) return null;
    final expiry = await storage.read(Constants.googleDriveTokenExpiry);
    final session = GoogleDriveSession(
      token,
      expiresAt: GoogleDriveSession.parseExpiry(expiry ?? legacyExpiry?.call()),
    );
    await save(session);
    await storage.delete(Constants.googleDriveToken);
    await storage.delete(Constants.googleDriveTokenExpiry);
    return session;
  }

  Future<String?> usableToken() async {
    final session = await restore();
    return session == null || session.isExpired(now())
        ? null
        : session.accessToken;
  }

  Future<void> delete() async {
    await storage.delete(recordKey);
    await storage.delete(Constants.googleDriveToken);
    await storage.delete(Constants.googleDriveTokenExpiry);
  }
}
