import 'dart:convert';
import 'dart:math';

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
    String Function()? createReplacement,
  }) : _client = client ?? http.Client(),
       _storeEnrollment = storeEnrollment ?? _store,
       _readEnrollment = readEnrollment ?? _read,
       _createReplacement = createReplacement ?? _secureReplacement;

  static const storageKey = 'marty:remote-holder-enrollment';
  static const _storage = FlutterSecureStorage();
  static final _tokenPattern = RegExp(r'^[A-Za-z0-9_-]{43}$');
  static bool _canonicalToken(String value) {
    if (!_tokenPattern.hasMatch(value)) return false;
    try {
      final bytes = base64Url.decode('$value=');
      return bytes.length == 32 && base64UrlEncode(bytes).replaceAll('=', '') == value;
    } catch (_) {
      return false;
    }
  }
  final http.Client _client;
  final Future<void> Function(String) _storeEnrollment;
  final Future<String?> Function() _readEnrollment;
  final String Function() _createReplacement;
  static Future<String>? _pairingInFlight;
  static Future<String>? _renewalInFlight;

  void close() => _client.close();

  static Future<void> _store(String value) =>
      _storage.write(key: storageKey, value: value);

  static Future<String?> _read() => _storage.read(key: storageKey);

  static String _secureReplacement() {
    final random = Random.secure();
    final bytes = List<int>.generate(32, (_) => random.nextInt(256));
    return base64UrlEncode(bytes).replaceAll('=', '');
  }

  static Uri _requiredOrigin(Object? value) {
    if (value is! String) throw const FormatException('Invalid remote wallet origin');
    final origin = Uri.tryParse(value);
    if (origin == null ||
        origin.scheme != 'https' ||
        origin.host.isEmpty ||
        origin.userInfo.isNotEmpty ||
        origin.path != '/' ||
        origin.hasQuery ||
        origin.hasFragment) {
      throw const FormatException('Invalid remote wallet origin');
    }
    return origin;
  }

  static Future<Object?> _readBoundedJson(
    http.StreamedResponse response,
    int limit,
  ) async {
    final bytes = <int>[];
    await for (final chunk in response.stream.timeout(const Duration(seconds: 45))) {
      bytes.addAll(chunk);
      if (bytes.length > limit) {
        throw const FormatException('Remote wallet response is too large');
      }
    }
    return jsonDecode(utf8.decode(bytes));
  }

  Future<String> pair({
    required String apiOrigin,
    required String pairingCode,
    required String platform,
  }) {
    if (_pairingInFlight != null) {
      throw StateError('Remote wallet pairing is already in progress');
    }
    late final Future<String> run;
    run = _pairInner(
      apiOrigin: apiOrigin,
      pairingCode: pairingCode,
      platform: platform,
    ).whenComplete(() {
      if (identical(_pairingInFlight, run)) _pairingInFlight = null;
    });
    _pairingInFlight = run;
    return run;
  }

  Future<String> _pairInner({
    required String apiOrigin,
    required String pairingCode,
    required String platform,
  }) async {
    final renewal = _renewalInFlight;
    if (renewal != null) {
      try {
        await renewal;
      } catch (_) {
        // A new user-approved pairing can replace a failed old renewal.
      }
    }
    final origin = _requiredOrigin(apiOrigin);
    if (!_canonicalToken(pairingCode) ||
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
    final data = await _readBoundedJson(response, 32 * 1024);
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
        !_canonicalToken(bearer) ||
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
        'confirmed': false,
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
    final origin = _requiredOrigin(data['api_origin']);
    final bearer = data['device_credential'];
    final pairingId = data['pairing_id'];
    final deviceId = data['device_id'];
    if (bearer is! String ||
        !_canonicalToken(bearer) ||
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
    final result = await _readBoundedJson(response, 1024);
    if (result is! Map<String, dynamic> ||
        result.length != 1 ||
        result['confirmed'] != true) {
      throw const FormatException('Remote wallet confirmation response is invalid');
    }
    data['confirmed'] = true;
    await _storeEnrollment(jsonEncode(data));
    return deviceId;
  }

  /// Refresh near expiry. The pending replacement is persisted before the
  /// network call, so a lost response can be retried with the same two tokens.
  Future<String> renewIfDue({bool force = false}) {
    final pairing = _pairingInFlight;
    if (pairing != null) {
      return pairing.then((_) => renewIfDue(force: force));
    }
    final ongoing = _renewalInFlight;
    if (ongoing != null) return ongoing;
    late final Future<String> run;
    run = _renewIfDueInner(force: force).whenComplete(() {
      if (identical(_renewalInFlight, run)) _renewalInFlight = null;
    });
    _renewalInFlight = run;
    return run;
  }

  Future<String> _renewIfDueInner({required bool force}) async {
    final stored = await _readEnrollment();
    if (stored == null) throw const FormatException('Remote wallet is not paired');
    final data = jsonDecode(stored);
    if (data is! Map<String, dynamic>) {
      throw const FormatException('Stored enrollment is invalid');
    }
    final origin = _requiredOrigin(data['api_origin']);
    final current = data['device_credential'];
    final registrationId = data['registration_id'];
    final expiresAt = DateTime.tryParse(data['credential_expires_at']?.toString() ?? '');
    final pending = data['pending_credential'];
    if (current is! String ||
        !_canonicalToken(current) ||
        registrationId is! String ||
        registrationId.isEmpty ||
        expiresAt == null ||
        data['confirmed'] != true ||
        (pending != null && (pending is! String || !_canonicalToken(pending)))) {
      throw const FormatException('Stored enrollment is invalid');
    }
    if (!force &&
        pending == null &&
        expiresAt.isAfter(DateTime.now().toUtc().add(const Duration(hours: 12)))) {
      return registrationId;
    }
    final replacement = pending as String? ?? _createReplacement();
    if (!_canonicalToken(replacement) || replacement == current) {
      throw const FormatException('Replacement credential is invalid');
    }
    if (pending == null) {
      data['pending_credential'] = replacement;
      await _storeEnrollment(jsonEncode(data));
    }
    final request = http.Request(
      'POST', origin.resolve('/v1/devices/holder-credential-rotations'),
    )..followRedirects = false;
    request.headers['authorization'] = 'Bearer $current';
    request.headers['content-type'] = 'application/json';
    request.body = jsonEncode({'replacement_credential': replacement});
    final response = await _client.send(request).timeout(const Duration(seconds: 45));
    if (response.statusCode != 200) {
      throw StateError('Remote wallet credential renewal was rejected');
    }
    final result = await _readBoundedJson(response, 1024);
    if (result is! Map<String, dynamic> ||
        result.keys.toSet().difference({'registration_id', 'credential_expires_at'}).isNotEmpty ||
        result.length != 2 ||
        result['registration_id'] != registrationId) {
      throw const FormatException('Credential renewal response is invalid');
    }
    final renewedExpiry = DateTime.tryParse(result['credential_expires_at']?.toString() ?? '');
    if (renewedExpiry == null || !renewedExpiry.isAfter(DateTime.now().toUtc())) {
      throw const FormatException('Credential renewal expiry is invalid');
    }
    data['device_credential'] = replacement;
    data['credential_expires_at'] = renewedExpiry.toUtc().toIso8601String();
    data.remove('pending_credential');
    await _storeEnrollment(jsonEncode(data));
    return registrationId;
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
        !_canonicalToken(value['x'] as String) ||
        (kty == 'EC' &&
            (value['y'] is! String ||
                !_canonicalToken(value['y'] as String)))) {
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
