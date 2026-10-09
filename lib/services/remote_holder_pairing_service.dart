import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

class RemotePairingConfirmationPending implements Exception {
  const RemotePairingConfirmationPending();
}

/// The wallet retains an opaque capability and public metadata; signing keys
/// remain in the remote KMS. The QR origin is shown for user approval first.
class RemoteHolderPairingService {
  RemoteHolderPairingService({
    http.Client? client,
    Future<void> Function(String)? storeEnrollment,
    Future<String?> Function()? readEnrollment,
  }) : _client = client ?? http.Client(),
       _storeEnrollment = storeEnrollment ?? _store,
       _readEnrollment = readEnrollment ?? _read;

  static const storageKey = 'marty:remote-holder-enrollment';
  static const _storage = FlutterSecureStorage();
  static final _tokenPattern = RegExp(r'^[A-Za-z0-9_-]{43}$');
  final http.Client _client;
  final Future<void> Function(String) _storeEnrollment;
  final Future<String?> Function() _readEnrollment;

  void close() => _client.close();

  static Future<void> _store(String value) =>
      _storage.write(key: storageKey, value: value);

  static Future<String?> _read() => _storage.read(key: storageKey);

  Future<String> pair({
    required String apiOrigin,
    required String pairingCode,
    required String platform,
  }) async {
    final origin = Uri.tryParse(apiOrigin);
    if (origin == null ||
        origin.scheme != 'https' ||
        origin.host.isEmpty ||
        origin.userInfo.isNotEmpty ||
        origin.path != '/' ||
        origin.hasQuery ||
        origin.hasFragment ||
        !_tokenPattern.hasMatch(pairingCode) ||
        (platform != 'android' && platform != 'ios')) {
      throw const FormatException('Invalid remote wallet pairing request');
    }
    final request = http.Request('POST', origin.resolve('/v1/devices/pair'))
      ..followRedirects = false;
    request.headers['content-type'] = 'application/json';
    request.body = jsonEncode({
      'pairing_code': pairingCode,
      'platform': platform,
    });
    final response = await _client.send(request).timeout(const Duration(seconds: 45));
    if (response.statusCode != 200) {
      throw StateError('Remote wallet pairing was rejected');
    }
    final bytes = <int>[];
    await for (final chunk in response.stream.timeout(
      const Duration(seconds: 45),
    )) {
      bytes.addAll(chunk);
      if (bytes.length > 32 * 1024) {
        throw const FormatException('Remote wallet pairing response is too large');
      }
    }
    final data = jsonDecode(utf8.decode(bytes));
    if (data is! Map<String, dynamic>) {
      throw const FormatException('Remote wallet pairing response is invalid');
    }
    const expectedFields = {
      'registration_id',
      'pairing_id',
      'device_id',
      'device_credential',
      'credential_expires_at',
      'holder_binding_public_jwk',
      'presentation_signing_public_jwk',
    };
    if (data.keys.toSet().difference(expectedFields).isNotEmpty ||
        expectedFields.difference(data.keys.toSet()).isNotEmpty) {
      throw const FormatException('Remote wallet pairing response has unexpected fields');
    }
    final bearer = data['device_credential'];
    final pairingId = data['pairing_id'];
    final registrationId = data['registration_id'];
    final deviceId = data['device_id'];
    final expiresAt = DateTime.tryParse(
      data['credential_expires_at']?.toString() ?? '',
    );
    if (bearer is! String ||
        !_tokenPattern.hasMatch(bearer) ||
        pairingId is! String ||
        !_uuidPattern.hasMatch(pairingId) ||
        registrationId is! String ||
        registrationId.isEmpty ||
        deviceId is! String ||
        deviceId.isEmpty ||
        expiresAt == null ||
        !expiresAt.isAfter(DateTime.now().toUtc())) {
      throw const FormatException('Remote wallet pairing response is invalid');
    }
    final binding = _publicJwk(
      data['holder_binding_public_jwk'],
      'OKP',
      'Ed25519',
    );
    final presentation = _publicJwk(
      data['presentation_signing_public_jwk'],
      'EC',
      'P-256',
    );
    await _storeEnrollment(
      jsonEncode({
        'api_origin': origin.toString(),
        'registration_id': registrationId,
        'pairing_id': pairingId,
        'device_id': deviceId,
        'device_credential': bearer,
        'credential_expires_at': expiresAt.toUtc().toIso8601String(),
        'holder_binding_public_jwk': binding,
        'presentation_signing_public_jwk': presentation,
      }),
    );
    try {
      await confirmStored();
    } catch (_) {
      throw const RemotePairingConfirmationPending();
    }
    return deviceId;
  }

  static final _uuidPattern = RegExp(
    r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
  );

  /// Safe to retry with the stored bearer if the acknowledgment response was
  /// lost. The server rejects stale, rotated, or expired pending pairings.
  Future<String> confirmStored() async {
    final stored = await _readEnrollment();
    if (stored == null) throw const FormatException('No pending enrollment');
    final data = jsonDecode(stored);
    if (data is! Map<String, dynamic>) {
      throw const FormatException('Stored enrollment is invalid');
    }
    final origin = Uri.tryParse(data['api_origin']?.toString() ?? '');
    final bearer = data['device_credential'];
    final pairingId = data['pairing_id'];
    final deviceId = data['device_id'];
    if (origin == null ||
        origin.scheme != 'https' ||
        origin.host.isEmpty ||
        origin.userInfo.isNotEmpty ||
        origin.path != '/' ||
        origin.hasQuery ||
        origin.hasFragment ||
        bearer is! String ||
        !_tokenPattern.hasMatch(bearer) ||
        pairingId is! String ||
        !_uuidPattern.hasMatch(pairingId) ||
        deviceId is! String ||
        deviceId.isEmpty) {
      throw const FormatException('Stored enrollment is invalid');
    }
    final request = http.Request('POST', origin.resolve('/v1/devices/pairing-ack'))
      ..followRedirects = false;
    request.headers['authorization'] = 'Bearer $bearer';
    request.headers['content-type'] = 'application/json';
    request.body = jsonEncode({'pairing_id': pairingId});
    final response = await _client.send(request).timeout(const Duration(seconds: 45));
    if (response.statusCode != 200) {
      throw StateError('Remote wallet confirmation was rejected');
    }
    final bytes = <int>[];
    await for (final chunk in response.stream.timeout(const Duration(seconds: 45))) {
      bytes.addAll(chunk);
      if (bytes.length > 1024) {
        throw const FormatException('Remote wallet confirmation response is too large');
      }
    }
    final result = jsonDecode(utf8.decode(bytes));
    if (result is! Map<String, dynamic> ||
        result.length != 1 ||
        result['confirmed'] != true) {
      throw const FormatException('Remote wallet confirmation response is invalid');
    }
    return deviceId;
  }

  static Map<String, String> _publicJwk(Object? value, String kty, String crv) {
    final expectedFields = kty == 'EC'
        ? {'kty', 'crv', 'x', 'y', 'kid'}
        : {'kty', 'crv', 'x', 'kid'};
    if (value is! Map<String, dynamic> ||
        value.keys.toSet().difference(expectedFields).isNotEmpty ||
        expectedFields.difference(value.keys.toSet()).isNotEmpty ||
        value['kty'] != kty ||
        value['crv'] != crv ||
        value['kid'] is! String ||
        (value['kid'] as String).isEmpty ||
        (value['kid'] as String).length > 512 ||
        value['x'] is! String ||
        !_tokenPattern.hasMatch(value['x'] as String) ||
        (kty == 'EC' &&
            (value['y'] is! String ||
                !_tokenPattern.hasMatch(value['y'] as String)))) {
      throw const FormatException('Remote holder public key is invalid');
    }
    return {
      'kty': kty,
      'crv': crv,
      'x': value['x'] as String,
      'kid': value['kid'] as String,
      if (kty == 'EC') 'y': value['y'] as String,
    };
  }
}
