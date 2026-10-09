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
      return bytes.length == 32 &&
          base64UrlEncode(bytes).replaceAll('=', '') == value;
    } catch (_) {
      return false;
    }
  }

  static bool _containsPrivateKeyField(Object? value) {
    if (value is List) {
      return value.any(_containsPrivateKeyField);
    }
    if (value is! Map) return false;
    for (final entry in value.entries) {
      if (entry.key is! String) return true;
      final normalized = (entry.key as String).toLowerCase().replaceAll(
        RegExp(r'[^a-z0-9]'),
        '',
      );
      if ({'d', 'p', 'q', 'dp', 'dq', 'qi', 'oth', 'k'}.contains(normalized) ||
          normalized.contains('private') ||
          normalized.contains('secret') ||
          normalized.contains('seed') ||
          _containsPrivateKeyField(entry.value)) {
        return true;
      }
    }
    return false;
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
    if (value is! String) {
      throw const FormatException('Invalid remote wallet origin');
    }
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
    await for (final chunk in response.stream.timeout(
      const Duration(seconds: 45),
    )) {
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
    run =
        _pairInner(
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
    final response = await _client
        .send(request)
        .timeout(const Duration(seconds: 45));
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
      throw const FormatException(
        'Remote wallet pairing response has unexpected fields',
      );
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
    final request = http.Request(
      'POST',
      origin.resolve('/v1/devices/pairing-ack'),
    )..followRedirects = false;
    request.headers['authorization'] = 'Bearer $bearer';
    request.headers['content-type'] = 'application/json';
    request.body = jsonEncode({'pairing_id': pairingId});
    final response = await _client
        .send(request)
        .timeout(const Duration(seconds: 45));
    if (response.statusCode != 200) {
      throw StateError('Remote wallet confirmation was rejected');
    }
    final result = await _readBoundedJson(response, 1024);
    if (result is! Map<String, dynamic> ||
        result.length != 1 ||
        result['confirmed'] != true) {
      throw const FormatException(
        'Remote wallet confirmation response is invalid',
      );
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
    if (stored == null) {
      throw const FormatException('Remote wallet is not paired');
    }
    final data = jsonDecode(stored);
    if (data is! Map<String, dynamic>) {
      throw const FormatException('Stored enrollment is invalid');
    }
    final origin = _requiredOrigin(data['api_origin']);
    final current = data['device_credential'];
    final registrationId = data['registration_id'];
    final expiresAt = DateTime.tryParse(
      data['credential_expires_at']?.toString() ?? '',
    );
    final pending = data['pending_credential'];
    if (current is! String ||
        !_canonicalToken(current) ||
        registrationId is! String ||
        registrationId.isEmpty ||
        expiresAt == null ||
        data['confirmed'] != true ||
        (pending != null &&
            (pending is! String || !_canonicalToken(pending)))) {
      throw const FormatException('Stored enrollment is invalid');
    }
    if (!force &&
        pending == null &&
        expiresAt.isAfter(
          DateTime.now().toUtc().add(const Duration(hours: 12)),
        )) {
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
      'POST',
      origin.resolve('/v1/devices/holder-credential-rotations'),
    )..followRedirects = false;
    request.headers['authorization'] = 'Bearer $current';
    request.headers['content-type'] = 'application/json';
    request.body = jsonEncode({'replacement_credential': replacement});
    final response = await _client
        .send(request)
        .timeout(const Duration(seconds: 45));
    if (response.statusCode != 200) {
      throw StateError('Remote wallet credential renewal was rejected');
    }
    final result = await _readBoundedJson(response, 1024);
    if (result is! Map<String, dynamic> ||
        result.keys.toSet().difference({
          'registration_id',
          'credential_expires_at',
        }).isNotEmpty ||
        result.length != 2 ||
        result['registration_id'] != registrationId) {
      throw const FormatException('Credential renewal response is invalid');
    }
    final renewedExpiry = DateTime.tryParse(
      result['credential_expires_at']?.toString() ?? '',
    );
    if (renewedExpiry == null ||
        !renewedExpiry.isAfter(DateTime.now().toUtc())) {
      throw const FormatException('Credential renewal expiry is invalid');
    }
    data['device_credential'] = replacement;
    data['credential_expires_at'] = renewedExpiry.toUtc().toIso8601String();
    data.remove('pending_credential');
    await _storeEnrollment(jsonEncode(data));
    return registrationId;
  }

  /// Fetches current operator-governed public issuer keys for this confirmed
  /// pairing. Callers must use the result immediately; it is never cached.
  Future<Map<String, dynamic>> fetchIssuerKeys() async {
    final paired = await _currentConfirmedBearer();
    final request = http.Request(
      'GET',
      paired.origin.resolve('/v1/devices/wallet-issuer-keys'),
    )..followRedirects = false;
    request.headers['authorization'] = 'Bearer ${paired.bearer}';
    final response = await _client
        .send(request)
        .timeout(const Duration(seconds: 45));
    if (response.statusCode != 200) {
      throw StateError('Wallet issuer trust is unavailable');
    }
    final snapshot = await _readBoundedJson(response, 256 * 1024);
    if (snapshot is! Map<String, dynamic> ||
        snapshot.keys.toSet().difference({
          'organization_id',
          'trust_profile_id',
          'generated_at',
          'expires_at',
          'issuer_keys',
        }).isNotEmpty ||
        snapshot.length != 5 ||
        snapshot['organization_id'] is! String ||
        (snapshot['organization_id'] as String).isEmpty ||
        snapshot['trust_profile_id'] is! String ||
        !_uuidPattern.hasMatch(snapshot['trust_profile_id'] as String)) {
      throw const FormatException('Wallet issuer trust snapshot is invalid');
    }
    final now = DateTime.now().toUtc();
    final generatedAt = DateTime.tryParse(
      snapshot['generated_at']?.toString() ?? '',
    )?.toUtc();
    final trustExpiresAt = DateTime.tryParse(
      snapshot['expires_at']?.toString() ?? '',
    )?.toUtc();
    if (generatedAt == null ||
        trustExpiresAt == null ||
        generatedAt.isAfter(now.add(const Duration(seconds: 5))) ||
        !trustExpiresAt.isAfter(now) ||
        !trustExpiresAt.isAfter(generatedAt) ||
        trustExpiresAt.isAfter(generatedAt.add(const Duration(minutes: 1)))) {
      throw const FormatException('Wallet issuer trust snapshot is expired');
    }
    final keys = snapshot['issuer_keys'];
    if (keys is! List || keys.isEmpty || keys.length > 256) {
      throw const FormatException('Wallet issuer trust keys are invalid');
    }
    for (final key in keys) {
      if (key is! Map<String, dynamic> ||
          key.keys.toSet().difference({
            'issuer',
            'key_id',
            'algorithm',
            'public_jwk',
          }).isNotEmpty ||
          key['issuer'] is! String ||
          (key['issuer'] as String).isEmpty ||
          key['algorithm'] is! String ||
          !{'ES256', 'ES384', 'EdDSA', 'RS256'}.contains(key['algorithm']) ||
          (key['key_id'] != null && key['key_id'] is! String) ||
          key['public_jwk'] is! Map<String, dynamic>) {
        throw const FormatException('Wallet issuer trust key is invalid');
      }
      final jwk = key['public_jwk'] as Map<String, dynamic>;
      if (_containsPrivateKeyField(jwk)) {
        throw const FormatException(
          'Wallet issuer trust contains private key material',
        );
      }
    }
    return snapshot;
  }

  /// Signs an exact JWS input with the paired, non-exportable remote key.
  /// The ES256 result is returned in JOSE's raw 64-byte form.
  Future<List<int>> signInput({
    required String purpose,
    required List<int> signingInput,
  }) async {
    if (purpose != 'holder_binding' && purpose != 'presentation_signing') {
      throw const FormatException('Remote signing purpose is invalid');
    }
    if (signingInput.isEmpty || signingInput.length > 64 * 1024) {
      throw const FormatException('Remote signing input is invalid');
    }
    final paired = await _currentConfirmedBearer();
    final request = http.Request(
      'POST',
      paired.origin.resolve('/v1/devices/holder-signatures'),
    )..followRedirects = false;
    request.headers['authorization'] = 'Bearer ${paired.bearer}';
    request.headers['content-type'] = 'application/json';
    request.body = jsonEncode({
      'purpose': purpose,
      'payload_b64': base64UrlEncode(signingInput).replaceAll('=', ''),
    });
    final response = await _client
        .send(request)
        .timeout(const Duration(seconds: 45));
    if (response.statusCode != 200) {
      throw StateError('Remote wallet signing was rejected');
    }
    final signed = await _readBoundedJson(response, 2048);
    if (signed is! Map<String, dynamic> ||
        signed.keys.toSet().difference({
          'signature_b64',
          'signature_encoding',
          'transcoded_signature_b64',
        }).isNotEmpty) {
      throw const FormatException(
        'Remote wallet signature response is invalid',
      );
    }
    final encoded = purpose == 'presentation_signing'
        ? signed['transcoded_signature_b64']
        : signed['signature_b64'];
    if (signed['signature_encoding'] !=
            (purpose == 'presentation_signing' ? 'der' : 'raw') ||
        encoded is! String ||
        !RegExp(r'^[A-Za-z0-9_-]{86}$').hasMatch(encoded)) {
      throw const FormatException('Remote wallet signature is invalid');
    }
    final bytes = base64Url.decode('$encoded==');
    if (bytes.length != 64 ||
        base64UrlEncode(bytes).replaceAll('=', '') != encoded) {
      throw const FormatException('Remote wallet signature is invalid');
    }
    return bytes;
  }

  /// Returns only the public key pinned when this bearer was paired.
  Future<Map<String, String>> publicJwkForPurpose(String purpose) async {
    final paired = await _currentConfirmedBearer();
    return switch (purpose) {
      'holder_binding' => paired.holderBindingPublicJwk,
      'presentation_signing' => paired.presentationSigningPublicJwk,
      _ => throw const FormatException('Remote signing purpose is invalid'),
    };
  }

  Future<
    ({
      Uri origin,
      String bearer,
      Map<String, String> holderBindingPublicJwk,
      Map<String, String> presentationSigningPublicJwk,
    })
  >
  _currentConfirmedBearer() async {
    await renewIfDue();
    final stored = await _readEnrollment();
    if (stored == null) {
      throw const FormatException('Remote wallet is not paired');
    }
    final data = jsonDecode(stored);
    if (data is! Map<String, dynamic> || data['confirmed'] != true) {
      throw const FormatException('Stored enrollment is not confirmed');
    }
    final origin = _requiredOrigin(data['api_origin']);
    final bearer = data['device_credential'];
    final expiresAt = DateTime.tryParse(
      data['credential_expires_at']?.toString() ?? '',
    );
    if (bearer is! String ||
        !_canonicalToken(bearer) ||
        expiresAt == null ||
        !expiresAt.toUtc().isAfter(DateTime.now().toUtc())) {
      throw const FormatException('Stored enrollment is invalid');
    }
    return (
      origin: origin,
      bearer: bearer,
      holderBindingPublicJwk: _publicJwk(
        data['holder_binding_public_jwk'],
        'OKP',
        'Ed25519',
      ),
      presentationSigningPublicJwk: _publicJwk(
        data['presentation_signing_public_jwk'],
        'EC',
        'P-256',
      ),
    );
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
