import '../rust/marty_bridge.dart/biometrics.dart' as rust_biometrics;
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
    final gestureValues = (json['gestures'] as List? ?? [])
        .map((gesture) => gesture.toString())
        .toList();
    final parsedGestures = gestureValues
        .map(
          (value) => LivenessGesture.values.firstWhere(
            (gesture) => gesture.name == value,
            orElse: () => LivenessGesture.smile,
          ),
        )
        .toList();

    return LivenessChallenge(
      challengeId: json['challenge_id']?.toString() ?? '',
      nonce: json['nonce']?.toString() ?? '',
      issuedAt: _parseDate(json['issued_at']),
      expiresAt: _parseDate(json['expires_at']),
      gestures: parsedGestures,
      signature: json['signature']?.toString() ?? '',
      nativePayload: json['native_payload']?.toString(),
    );
  }

  static Future<LivenessChallenge> create({
    required List<LivenessGesture> gestures,
    required Duration ttl,
    required String signingSecret,
  }) async {
    final native = rust_biometrics.createLivenessChallenge(
      gestures: gestures.map((gesture) => gesture.name).toList(growable: false),
      ttlSeconds: BigInt.from(ttl.inSeconds),
      signingSecret: signingSecret,
    );
    return LivenessChallenge(
      challengeId: native.challengeId,
      nonce: native.nonce,
      issuedAt: DateTime.parse(native.issuedAt).toUtc(),
      expiresAt: DateTime.parse(native.expiresAt).toUtc(),
      gestures: gestures,
      signature: native.signature,
      nativePayload: native.nativePayload,
    );
  }

  static DateTime _parseDate(dynamic value) {
    if (value is DateTime) return value.toUtc();
    if (value is String) {
      try {
        return DateTime.parse(value).toUtc();
      } catch (_) {
        return DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
      }
    }
    return DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
  }
}
