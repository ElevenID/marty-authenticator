import 'document_verification_config.dart';

class LivenessChallenge {
  final String challengeId;
  final String nonce;
  final DateTime issuedAt;
  final DateTime expiresAt;
  final List<LivenessGesture> gestures;
  final String signature;
  final String? nativePayload;

  const LivenessChallenge({
    required this.challengeId,
    required this.nonce,
    required this.issuedAt,
    required this.expiresAt,
    required this.gestures,
    required this.signature,
    this.nativePayload,
  });

  bool get isExpired => DateTime.now().toUtc().isAfter(expiresAt);

  void validateForCapture() {
    if (challengeId.isEmpty ||
        nonce.isEmpty ||
        signature.isEmpty ||
        nativePayload == null ||
        nativePayload!.isEmpty ||
        gestures.isEmpty ||
        gestures.length > LivenessGesture.values.length ||
        gestures.toSet().length != gestures.length ||
        !expiresAt.isAfter(issuedAt) ||
        isExpired) {
      throw const FormatException('Invalid remote liveness challenge');
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'challenge_id': challengeId,
      'nonce': nonce,
      'issued_at': issuedAt.toIso8601String(),
      'expires_at': expiresAt.toIso8601String(),
      'gestures': gestures.map((gesture) => gesture.name).toList(),
      'signature': signature,
      if (nativePayload != null) 'native_payload': nativePayload,
    };
  }

  factory LivenessChallenge.fromJson(Map<String, dynamic> json) {
    final rawGestures = json['gestures'];
    if (rawGestures is! List || rawGestures.any((value) => value is! String)) {
      throw const FormatException('Invalid remote liveness gestures');
    }
    final gestures = rawGestures.map((value) {
      for (final gesture in LivenessGesture.values) {
        if (gesture.name == value) return gesture;
      }
      throw const FormatException('Unknown remote liveness gesture');
    }).toList();
    final challenge = LivenessChallenge(
      challengeId: _requiredString(json, 'challenge_id'),
      nonce: _requiredString(json, 'nonce'),
      issuedAt: _parseDate(json['issued_at']),
      expiresAt: _parseDate(json['expires_at']),
      gestures: gestures,
      signature: _requiredString(json, 'signature'),
      nativePayload: _requiredString(json, 'native_payload'),
    );
    challenge.validateForCapture();
    return challenge;
  }

  static String _requiredString(Map<String, dynamic> json, String key) {
    final value = json[key];
    if (value is! String || value.isEmpty) {
      throw FormatException('Invalid remote liveness $key');
    }
    return value;
  }

  static DateTime _parseDate(dynamic value) {
    if (value is DateTime) return value.toUtc();
    if (value is String) {
      try {
        return DateTime.parse(value).toUtc();
      } on FormatException {
        throw const FormatException('Invalid remote liveness timestamp');
      }
    }
    throw const FormatException('Invalid remote liveness timestamp');
  }
}
