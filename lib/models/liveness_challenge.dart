import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

import '../utils/crypto_utils.dart';
import 'document_verification_config.dart';

class LivenessChallenge {
  final String challengeId;
  final String nonce;
  final DateTime issuedAt;
  final DateTime expiresAt;
  final List<LivenessGesture> gestures;
  final String signature;

  const LivenessChallenge({
    required this.challengeId,
    required this.nonce,
    required this.issuedAt,
    required this.expiresAt,
    required this.gestures,
    required this.signature,
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
    );
  }

  static LivenessChallenge create({
    required List<LivenessGesture> gestures,
    required Duration ttl,
    required String signingSecret,
  }) {
    final now = DateTime.now().toUtc();
    final expiresAt = now.add(ttl);
    final challengeId = _randomId('lv');
    final nonce = _randomId('nonce');
    final signature = _sign(
      challengeId: challengeId,
      nonce: nonce,
      issuedAt: now,
      expiresAt: expiresAt,
      gestures: gestures,
      signingSecret: signingSecret,
    );

    return LivenessChallenge(
      challengeId: challengeId,
      nonce: nonce,
      issuedAt: now,
      expiresAt: expiresAt,
      gestures: gestures,
      signature: signature,
    );
  }

  static String _sign({
    required String challengeId,
    required String nonce,
    required DateTime issuedAt,
    required DateTime expiresAt,
    required List<LivenessGesture> gestures,
    required String signingSecret,
  }) {
    final payload = jsonEncode({
      'challenge_id': challengeId,
      'nonce': nonce,
      'issued_at': issuedAt.toIso8601String(),
      'expires_at': expiresAt.toIso8601String(),
      'gestures': gestures.map((gesture) => gesture.name).toList(),
    });
    final hmac = Hmac(sha256, utf8.encode(signingSecret));
    return hmac.convert(utf8.encode(payload)).toString();
  }

  static String _randomId(String prefix) {
    final random = secureRandom();
    final bytes = Uint8List(12);
    for (var i = 0; i < bytes.length; i++) {
      bytes[i] = random.nextUint8();
    }
    final hex = bytes
        .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
        .join();
    return '$prefix-$hex';
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
