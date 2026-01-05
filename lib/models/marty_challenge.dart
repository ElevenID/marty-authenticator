import 'dart:convert';
import 'dart:typed_data';

import 'package:pointycastle/export.dart';

import '../utils/rsa_utils.dart';
import '../utils/logger.dart';

/// Format identifier for Marty-native challenges.
const String martyChallengeFormat = 'marty/v1';

/// An option for multi-choice challenges, displayed as a button.
class ChallengeOption {
  /// Unique identifier sent in response.
  final String id;

  /// Display text for the button.
  final String label;

  const ChallengeOption({required this.id, required this.label});

  factory ChallengeOption.fromJson(Map<String, dynamic> json) {
    return ChallengeOption(
      id: json['id']?.toString() ?? '',
      label: json['label']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {'id': id, 'label': label};
  }

  @override
  String toString() => 'ChallengeOption(id: $id, label: $label)';
}

/// Marty-native push challenge payload (marty/v1 format).
///
/// Used for both FCM and SSE delivery. Supports server-signed
/// challenges with multi-choice options.
class MartyChallenge {
  /// Format identifier (always "marty/v1").
  final String format;

  /// Unique challenge identifier.
  final String challengeId;

  /// Target device identifier.
  final String deviceId;

  /// Challenge title shown to user.
  final String title;

  /// Authentication question or action prompt.
  final String question;

  /// Cryptographic nonce for signature verification.
  final String nonce;

  /// Time-to-live in seconds.
  final int ttlSeconds;

  /// When the challenge was created.
  final DateTime createdAt;

  /// Whether the response requires a cryptographic signature.
  final bool requireSignature;

  /// Options for multi-choice challenges (displayed as buttons).
  final List<ChallengeOption> options;

  /// Server's RSA signature of the challenge.
  final String signature;

  /// Optional: specific credential ID to use.
  final String? credentialId;

  /// Optional: relying party identifier.
  final String? relyingPartyId;

  /// Optional: additional metadata.
  final Map<String, dynamic> data;

  const MartyChallenge({
    required this.format,
    required this.challengeId,
    required this.deviceId,
    required this.title,
    required this.question,
    required this.nonce,
    required this.ttlSeconds,
    required this.createdAt,
    required this.requireSignature,
    required this.options,
    required this.signature,
    this.credentialId,
    this.relyingPartyId,
    this.data = const {},
  });

  /// Whether the challenge has expired.
  bool get isExpired {
    final expiresAt = createdAt.add(Duration(seconds: ttlSeconds));
    return DateTime.now().toUtc().isAfter(expiresAt);
  }

  /// When the challenge expires.
  DateTime get expiresAt => createdAt.add(Duration(seconds: ttlSeconds));

  /// Build canonical string for signature verification.
  ///
  /// Format: challenge_id|nonce|device_id|ttl_seconds|created_at|options_json
  String get canonicalString {
    final optionsJson = jsonEncode(options.map((opt) => opt.toJson()).toList());
    return [
      challengeId,
      nonce,
      deviceId,
      ttlSeconds.toString(),
      createdAt.toIso8601String(),
      optionsJson,
    ].join('|');
  }

  /// Create from FCM data payload.
  ///
  /// FCM data payloads have all values as strings, so this factory
  /// handles parsing strings to appropriate types.
  factory MartyChallenge.fromFcmData(Map<String, dynamic> data) {
    // Parse options from JSON string
    List<ChallengeOption> options = [];
    final optionsStr = data['options'];
    if (optionsStr != null && optionsStr is String && optionsStr.isNotEmpty) {
      try {
        final optionsList = jsonDecode(optionsStr) as List;
        options = optionsList
            .map((opt) => ChallengeOption.fromJson(opt as Map<String, dynamic>))
            .toList();
      } catch (e) {
        // If parsing fails, use default options
        options = [
          const ChallengeOption(id: 'accept', label: 'Approve'),
          const ChallengeOption(id: 'reject', label: 'Deny'),
        ];
      }
    }

    // Parse additional data from JSON string
    Map<String, dynamic> additionalData = {};
    final dataStr = data['data'];
    if (dataStr != null && dataStr is String && dataStr.isNotEmpty) {
      try {
        additionalData = jsonDecode(dataStr) as Map<String, dynamic>;
      } catch (e) {
        // Ignore parsing errors for additional data
      }
    }

    // Parse ttl_seconds (string in FCM)
    int ttlSeconds = 120;
    final ttlStr = data['ttl_seconds'];
    if (ttlStr != null) {
      ttlSeconds = int.tryParse(ttlStr.toString()) ?? 120;
    }

    // Parse require_signature (string in FCM)
    bool requireSignature = true;
    final reqSigStr = data['require_signature'];
    if (reqSigStr != null) {
      requireSignature = reqSigStr.toString().toLowerCase() == 'true';
    }

    // Parse created_at
    DateTime createdAt = DateTime.now().toUtc();
    final createdAtStr = data['created_at'];
    if (createdAtStr != null && createdAtStr is String) {
      try {
        createdAt = DateTime.parse(createdAtStr);
      } catch (e) {
        // Use current time if parsing fails
      }
    }

    return MartyChallenge(
      format: data['format']?.toString() ?? martyChallengeFormat,
      challengeId: data['challenge_id']?.toString() ?? '',
      deviceId: data['device_id']?.toString() ?? '',
      title: data['title']?.toString() ?? '',
      question: data['question']?.toString() ?? '',
      nonce: data['nonce']?.toString() ?? '',
      ttlSeconds: ttlSeconds,
      createdAt: createdAt,
      requireSignature: requireSignature,
      options: options,
      signature: data['signature']?.toString() ?? '',
      credentialId: data['credential_id']?.toString(),
      relyingPartyId: data['relying_party_id']?.toString(),
      data: additionalData,
    );
  }

  /// Create from JSON (e.g., from SSE or polling response).
  factory MartyChallenge.fromJson(Map<String, dynamic> json) {
    // For SSE/polling, data may already be properly typed
    List<ChallengeOption> options = [];
    final optionsData = json['options'];
    if (optionsData != null) {
      if (optionsData is String) {
        // JSON string (like FCM)
        try {
          final optionsList = jsonDecode(optionsData) as List;
          options = optionsList
              .map(
                (opt) => ChallengeOption.fromJson(opt as Map<String, dynamic>),
              )
              .toList();
        } catch (e) {
          // Ignore
        }
      } else if (optionsData is List) {
        // Already parsed list
        options = optionsData
            .map((opt) => ChallengeOption.fromJson(opt as Map<String, dynamic>))
            .toList();
      }
    }

    // Parse additional data
    Map<String, dynamic> additionalData = {};
    final dataField = json['data'];
    if (dataField != null) {
      if (dataField is String) {
        try {
          additionalData = jsonDecode(dataField) as Map<String, dynamic>;
        } catch (e) {
          // Ignore
        }
      } else if (dataField is Map) {
        additionalData = Map<String, dynamic>.from(dataField);
      }
    }

    // Parse ttl_seconds
    int ttlSeconds = 120;
    final ttlField = json['ttl_seconds'];
    if (ttlField != null) {
      if (ttlField is int) {
        ttlSeconds = ttlField;
      } else {
        ttlSeconds = int.tryParse(ttlField.toString()) ?? 120;
      }
    }

    // Parse require_signature
    bool requireSignature = true;
    final reqSigField = json['require_signature'];
    if (reqSigField != null) {
      if (reqSigField is bool) {
        requireSignature = reqSigField;
      } else {
        requireSignature = reqSigField.toString().toLowerCase() == 'true';
      }
    }

    // Parse created_at
    DateTime createdAt = DateTime.now().toUtc();
    final createdAtField = json['created_at'];
    if (createdAtField != null) {
      if (createdAtField is DateTime) {
        createdAt = createdAtField;
      } else if (createdAtField is String) {
        try {
          createdAt = DateTime.parse(createdAtField);
        } catch (e) {
          // Use current time
        }
      }
    }

    return MartyChallenge(
      format: json['format']?.toString() ?? martyChallengeFormat,
      challengeId: json['challenge_id']?.toString() ?? '',
      deviceId: json['device_id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      question: json['question']?.toString() ?? '',
      nonce: json['nonce']?.toString() ?? '',
      ttlSeconds: ttlSeconds,
      createdAt: createdAt,
      requireSignature: requireSignature,
      options: options,
      signature: json['signature']?.toString() ?? '',
      credentialId: json['credential_id']?.toString(),
      relyingPartyId: json['relying_party_id']?.toString(),
      data: additionalData,
    );
  }

  /// Convert to JSON for storage or transmission.
  Map<String, dynamic> toJson() {
    return {
      'format': format,
      'challenge_id': challengeId,
      'device_id': deviceId,
      'title': title,
      'question': question,
      'nonce': nonce,
      'ttl_seconds': ttlSeconds,
      'created_at': createdAt.toIso8601String(),
      'require_signature': requireSignature,
      'options': options.map((opt) => opt.toJson()).toList(),
      'signature': signature,
      if (credentialId != null) 'credential_id': credentialId,
      if (relyingPartyId != null) 'relying_party_id': relyingPartyId,
      if (data.isNotEmpty) 'data': data,
    };
  }

  /// Check if this is a valid Marty challenge format.
  static bool isMartyFormat(Map<String, dynamic> data) {
    final format = data['format']?.toString();
    return format != null && format.startsWith('marty/');
  }

  /// Verify the server's signature on this challenge.
  ///
  /// [serverPublicKeyBase64] - Server's RSA public key in base64 PKCS#8 DER format.
  /// [rsaUtils] - RSA utilities instance (optional, uses default if not provided).
  ///
  /// Returns true if signature is valid, false otherwise.
  /// Returns true without verification if signature is empty (unsigned challenge).
  bool verifySignature(
    String serverPublicKeyBase64, {
    RsaUtils rsaUtils = const RsaUtils(),
  }) {
    // If no signature, nothing to verify
    if (signature.isEmpty) {
      Logger.info('MartyChallenge: No signature to verify');
      return true;
    }

    // If no server public key, cannot verify
    if (serverPublicKeyBase64.isEmpty) {
      Logger.warning('MartyChallenge: No server public key available');
      return false;
    }

    try {
      // Parse the server's public key (PKCS#8 format from server, fallback to PKCS#1)
      RSAPublicKey publicKey;
      try {
        publicKey = rsaUtils.deserializeRSAPublicKeyPKCS8(
          serverPublicKeyBase64,
        );
      } catch (_) {
        // Try PKCS#1 format as fallback
        try {
          publicKey = rsaUtils.deserializeRSAPublicKeyPKCS1(
            serverPublicKeyBase64,
          );
        } catch (e2) {
          Logger.error(
            'MartyChallenge: Failed to parse server public key',
            error: e2,
          );
          return false;
        }
      }

      // Decode the signature from base64
      final Uint8List signatureBytes;
      try {
        signatureBytes = Uint8List.fromList(base64Decode(signature));
      } catch (e) {
        Logger.error('MartyChallenge: Failed to decode signature', error: e);
        return false;
      }

      // Get the canonical string that was signed
      final messageBytes = Uint8List.fromList(utf8.encode(canonicalString));

      // Verify the signature
      final isValid = rsaUtils.verifyRSASignature(
        publicKey,
        messageBytes,
        signatureBytes,
      );

      if (isValid) {
        Logger.info('MartyChallenge: Signature verification succeeded');
      } else {
        Logger.warning('MartyChallenge: Signature verification failed');
      }

      return isValid;
    } catch (e, s) {
      Logger.error(
        'MartyChallenge: Error during signature verification',
        error: e,
        stackTrace: s,
      );
      return false;
    }
  }

  @override
  String toString() {
    return 'MartyChallenge('
        'challengeId: $challengeId, '
        'title: $title, '
        'question: $question, '
        'options: ${options.length}, '
        'isExpired: $isExpired)';
  }
}
