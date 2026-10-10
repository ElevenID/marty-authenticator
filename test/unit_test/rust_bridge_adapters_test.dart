import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:marty_authenticator/models/document_verification_config.dart';
import 'package:marty_authenticator/models/liveness_gesture_detector.dart';
import 'package:marty_authenticator/rust/marty_bridge.dart/frb_generated.dart';
import 'package:marty_authenticator/rust/marty_bridge.dart/status.dart';
import 'package:marty_authenticator/services/status_list_service.dart';

class _MockRustApi implements RustLibApi {
  String? parsedStatusJson;
  String? evaluatedEntryJson;
  String? evaluatedCredentialJson;
  String? evaluatedGesture;
  double? evaluatedSmile;
  double? evaluatedHeadX;
  double? evaluatedHeadY;

  @override
  Future<List<FrbStatusEntry>> crateStatusParseStatusEntries({
    required String credentialStatusJson,
  }) async {
    parsedStatusJson = credentialStatusJson;
    return [
      FrbStatusEntry(
        id: 'https://issuer.example/status/3#5',
        purpose: 'revocation',
        index: BigInt.from(5),
        listUrl: 'https://issuer.example/status/3',
        entryJson: jsonEncode({
          'id': 'https://issuer.example/status/3#5',
          'statusPurpose': 'revocation',
        }),
      ),
    ];
  }

  @override
  Future<FrbStatusDecision> crateStatusEvaluateBitstringStatus({
    required String entryJson,
    required String statusListCredentialJson,
  }) async {
    evaluatedEntryJson = entryJson;
    evaluatedCredentialJson = statusListCredentialJson;
    return FrbStatusDecision(
      purpose: 'revocation',
      index: BigInt.from(5),
      asserted: true,
      listSize: BigInt.from(131072),
    );
  }

  @override
  bool crateBiometricsEvaluateLivenessGesture({
    required String gesture,
    double? smilingProbability,
    double? headEulerAngleX,
    double? headEulerAngleY,
  }) {
    evaluatedGesture = gesture;
    evaluatedSmile = smilingProbability;
    evaluatedHeadX = headEulerAngleX;
    evaluatedHeadY = headEulerAngleY;
    return gesture == 'smile' && smilingProbability == 0.8;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  final native = _MockRustApi();

  setUpAll(() => RustLib.initMock(api: native));
  tearDownAll(RustLib.dispose);

  test('status adapter preserves Rust entry and decision fields', () async {
    const adapter = RustStatusListNativeAdapter();
    final statusJson = jsonEncode({
      'id': 'https://issuer.example/status/3#5',
      'statusPurpose': 'revocation',
    });

    final entries = await adapter.parseEntries(statusJson);
    final decision = await adapter.evaluate(
      entries.single.entryJson,
      '{"credentialSubject":{"encodedList":"fixture"}}',
    );

    expect(native.parsedStatusJson, statusJson);
    expect(entries.single.purpose, 'revocation');
    expect(entries.single.listUrl, 'https://issuer.example/status/3');
    expect(decision.purpose, 'revocation');
    expect(decision.asserted, isTrue);
    expect(native.evaluatedEntryJson, entries.single.entryJson);
    expect(native.evaluatedCredentialJson, contains('encodedList'));
  });

  test('gesture detector forwards measured values to Rust', () {
    final detected = LivenessGestureDetector.detects(
      LivenessGesture.smile,
      smilingProbability: 0.8,
      headEulerAngleX: -3,
      headEulerAngleY: 7,
    );

    expect(detected, isTrue);
    expect(native.evaluatedGesture, 'smile');
    expect(native.evaluatedSmile, 0.8);
    expect(native.evaluatedHeadX, -3);
    expect(native.evaluatedHeadY, 7);
  });
}
