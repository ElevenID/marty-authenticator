import 'package:flutter_test/flutter_test.dart';
import 'package:marty_authenticator/utils/oid4vci_offer_uri.dart';

void main() {
  group('normalizeOid4vciCredentialOfferUri', () {
    test('wraps bare HTTPS by-reference offer endpoint', () {
      expect(
        normalizeOid4vciCredentialOfferUri(
          'https://issuer.example/offers/123',
        ),
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
  });
}