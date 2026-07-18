import 'package:flutter_test/flutter_test.dart';
import 'package:marty_authenticator/utils/oid4vci_offer_uri.dart';

void main() {
  group('normalizeOid4vciCredentialOfferUri', () {
    test('wraps bare HTTPS by-reference offer endpoint', () {
      expect(
        normalizeOid4vciCredentialOfferUri('https://issuer.example/offers/123'),
        'openid-credential-offer://?credential_offer_uri=https%3A%2F%2Fissuer.example%2Foffers%2F123',
      );
    });

    test('keeps credential-offer URI envelope around credential_offer_uri', () {
      expect(
        normalizeOid4vciCredentialOfferUri(
          'openid-credential-offer://?credential_offer_uri=https%3A%2F%2Fissuer.example%2Foffers%2F123',
        ),
        'openid-credential-offer://?credential_offer_uri=https%3A%2F%2Fissuer.example%2Foffers%2F123',
      );
    });

    test('unwraps Marty app routing links to the inner credential offer', () {
      final inner =
          'openid-credential-offer://?credential_offer_uri=https%3A%2F%2Fissuer.example%2Foffers%2F123';
      final outer =
          'marty-authenticator://open?inner=${Uri.encodeQueryComponent(inner)}';

      expect(normalizeOid4vciCredentialOfferUri(outer), inner);
    });

    test('normalizes Android intent credential-offer links', () {
      expect(
        normalizeOid4vciCredentialOfferUri(
          'intent://?credential_offer_uri=https%3A%2F%2Fissuer.example%2Foffers%2F123#Intent;scheme=openid-credential-offer;package=com.spruceid.mobilesdkexample;end',
        ),
        'openid-credential-offer://?credential_offer_uri=https%3A%2F%2Fissuer.example%2Foffers%2F123',
      );
    });

    test('collapses accidentally nested credential-offer envelopes', () {
      final inner =
          'openid-credential-offer://?credential_offer_uri=https%3A%2F%2Fissuer.example%2Foffers%2F123';
      final outer =
          'openid-credential-offer://?credential_offer_uri=${Uri.encodeQueryComponent(inner)}';

      expect(normalizeOid4vciCredentialOfferUri(outer), inner);
    });

    test('wraps inline JSON credential offers by value', () {
      const offerJson =
          '{"credential_issuer":"https://issuer.example","credential_configuration_ids":["EmployeeBadge"],"grants":{}}';

      final normalized = normalizeOid4vciCredentialOfferUri(offerJson);
      final parsed = Uri.parse(normalized);

      expect(parsed.scheme, oid4vciCredentialOfferScheme);
      expect(parsed.queryParameters['credential_offer'], offerJson);
    });

    test('handles invalid, empty, wrapper, and unrelated inputs safely', () {
      expect(normalizeOid4vciCredentialOfferUri('  '), isEmpty);
      expect(normalizeOid4vciCredentialOfferUri('not a uri'), 'not a uri');
      expect(
        normalizeOid4vciCredentialOfferUri('mailto:test@example.com'),
        'mailto:test@example.com',
      );
      expect(
        normalizeOid4vciCredentialOfferUri('martywallet://open'),
        'martywallet://open',
      );
      expect(normalizeOid4vciCredentialOfferUri('{invalid'), '{invalid');
      expect(
        normalizeOid4vciCredentialOfferUri('{"other":true}'),
        '{"other":true}',
      );
      expect(isOid4vciCredentialOfferUri('not a uri'), isFalse);
      expect(
        isOid4vciCredentialOfferUri('HAIP-VCI://?credential_offer=x'),
        isTrue,
      );
      expect(
        normalizedOid4vciCredentialOfferUriOrNull('mailto:test@example.com'),
        isNull,
      );
    });

    test('normalizes by-value and nested variants across transports', () {
      const json = '{"credential_issuer":"https://issuer.example"}';
      final encodedJson = Uri.encodeQueryComponent(json);
      final expected = normalizeOid4vciCredentialOfferUri(json);

      expect(
        normalizeOid4vciCredentialOfferUri(
          'https://wallet.example/open?credential_offer=$encodedJson',
        ),
        expected,
      );
      expect(
        normalizeOid4vciCredentialOfferUri(
          'intent://open?credential_offer=$encodedJson#Intent;scheme=other;end',
        ),
        expected,
      );
      expect(
        normalizeOid4vciCredentialOfferUri(
          'openid-credential-offer://?credential_offer=$encodedJson',
        ),
        expected,
      );
      expect(
        normalizeOid4vciCredentialOfferUri(
          'openid-credential-offer://?inner=${Uri.encodeQueryComponent(expected)}',
        ),
        expected,
      );
      expect(
        normalizeOid4vciCredentialOfferUri(
          'intent://open?x=1#Intent;scheme=openid-credential-offer;end',
        ),
        'openid-credential-offer://?x=1',
      );
      expect(
        normalizeOid4vciCredentialOfferUri(
          'intent://open?x=1#Intent;scheme=other;end',
        ),
        'intent://open?x=1#Intent;scheme=other;end',
      );
      expect(
        normalizeOid4vciCredentialOfferUri(
          'openid-credential-offer://?credential_offer=opaque-offer',
        ),
        'openid-credential-offer://?credential_offer=opaque-offer',
      );
      expect(
        normalizeOid4vciCredentialOfferUri(
          'https://wallet.example/open?credential_offer_uri=${Uri.encodeQueryComponent('https://issuer.example/ref')}',
        ),
        normalizeOid4vciCredentialOfferUri('https://issuer.example/ref'),
      );
      expect(
        normalizeOid4vciCredentialOfferUri(
          'https://wallet.example/open?credential_offer=opaque-offer',
        ),
        'openid-credential-offer://?credential_offer=opaque-offer',
      );
    });
  });
}
