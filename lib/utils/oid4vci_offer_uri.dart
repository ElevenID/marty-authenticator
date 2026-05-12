import 'dart:convert';

const oid4vciCredentialOfferScheme = 'openid-credential-offer';

const _oid4vciSchemes = {
  oid4vciCredentialOfferScheme,
  'haip-vci',
};

const _walletWrapperSchemes = {
  'marty-authenticator',
  'martywallet',
};

const _nestedUriKeys = [
  'inner',
  'uri',
  'offer_uri',
  'offer',
  'credential_offer_uri',
];

/// Normalizes an incoming OID4VCI credential-offer handoff for SDK calls.
///
/// The app can receive a few shapes from QR codes, OS deep links, universal
/// links, and wallet-specific wrapper routes. Spruce's OID4VCI entry points
/// should receive the credential-offer URI envelope, not a Marty wrapper and
/// not a bare by-reference HTTPS endpoint.
String normalizeOid4vciCredentialOfferUri(String value) {
  final raw = value.trim();
  if (raw.isEmpty) return raw;

  final jsonOffer = _normalizeJsonCredentialOffer(raw);
  if (jsonOffer != null) return jsonOffer;

  final uri = Uri.tryParse(raw);
  if (uri == null || uri.scheme.isEmpty) return raw;

  final scheme = uri.scheme.toLowerCase();

  if (_walletWrapperSchemes.contains(scheme)) {
    final nested = _firstQueryValue(uri, _nestedUriKeys);
    if (nested != null && nested.trim().isNotEmpty) {
      return normalizeOid4vciCredentialOfferUri(nested);
    }
    return raw;
  }

  if (scheme == 'intent') {
    return _normalizeAndroidIntentUri(uri, raw);
  }

  if (_oid4vciSchemes.contains(scheme)) {
    return _normalizeOpenIdCredentialOfferUri(uri, raw);
  }

  if (scheme == 'http' || scheme == 'https') {
    return _normalizeHttpCredentialOfferUri(uri, raw);
  }

  return raw;
}

bool isOid4vciCredentialOfferUri(String value) {
  final uri = Uri.tryParse(value.trim());
  if (uri == null) return false;
  return _oid4vciSchemes.contains(uri.scheme.toLowerCase());
}

String? normalizedOid4vciCredentialOfferUriOrNull(String value) {
  final normalized = normalizeOid4vciCredentialOfferUri(value);
  return isOid4vciCredentialOfferUri(normalized) ? normalized : null;
}

String _normalizeOpenIdCredentialOfferUri(Uri uri, String raw) {
  final credentialOfferUri = uri.queryParameters['credential_offer_uri'];
  if (credentialOfferUri != null && credentialOfferUri.trim().isNotEmpty) {
    return normalizeOid4vciCredentialOfferUri(credentialOfferUri);
  }

  final credentialOffer = uri.queryParameters['credential_offer'];
  if (credentialOffer != null && credentialOffer.trim().isNotEmpty) {
    final nested = normalizedOid4vciCredentialOfferUriOrNull(credentialOffer);
    if (nested != null) return nested;

    final jsonOffer = _normalizeJsonCredentialOffer(credentialOffer);
    return jsonOffer ?? _credentialOfferByValueUri(credentialOffer);
  }

  final nested = _firstQueryValue(uri, ['inner', 'uri']);
  if (nested != null && nested.trim().isNotEmpty) {
    final normalizedNested = normalizedOid4vciCredentialOfferUriOrNull(nested);
    if (normalizedNested != null) return normalizedNested;
  }

  return raw;
}

String _normalizeHttpCredentialOfferUri(Uri uri, String raw) {
  final credentialOfferUri = uri.queryParameters['credential_offer_uri'];
  if (credentialOfferUri != null && credentialOfferUri.trim().isNotEmpty) {
    return normalizeOid4vciCredentialOfferUri(credentialOfferUri);
  }

  final credentialOffer = uri.queryParameters['credential_offer'];
  if (credentialOffer != null && credentialOffer.trim().isNotEmpty) {
    final nested = normalizedOid4vciCredentialOfferUriOrNull(credentialOffer);
    if (nested != null) return nested;

    final jsonOffer = _normalizeJsonCredentialOffer(credentialOffer);
    return jsonOffer ?? _credentialOfferByValueUri(credentialOffer);
  }

  return _credentialOfferByReferenceUri(raw);
}

String _normalizeAndroidIntentUri(Uri uri, String raw) {
  final credentialOfferUri = uri.queryParameters['credential_offer_uri'];
  if (credentialOfferUri != null && credentialOfferUri.trim().isNotEmpty) {
    return normalizeOid4vciCredentialOfferUri(credentialOfferUri);
  }

  final credentialOffer = uri.queryParameters['credential_offer'];
  if (credentialOffer != null && credentialOffer.trim().isNotEmpty) {
    return normalizeOid4vciCredentialOfferUri(credentialOffer);
  }

  final fragmentScheme = _intentFragmentValue(uri.fragment, 'scheme');
  if (fragmentScheme == oid4vciCredentialOfferScheme && uri.query.isNotEmpty) {
    return '$oid4vciCredentialOfferScheme://?${uri.query}';
  }

  return raw;
}

String? _normalizeJsonCredentialOffer(String raw) {
  final trimmed = raw.trimLeft();
  if (!trimmed.startsWith('{')) return null;

  try {
    final decoded = jsonDecode(raw);
    if (decoded is Map && decoded.containsKey('credential_issuer')) {
      return _credentialOfferByValueUri(raw);
    }
  } catch (_) {
    return null;
  }

  return null;
}

String? _firstQueryValue(Uri uri, List<String> keys) {
  for (final key in keys) {
    final value = uri.queryParameters[key];
    if (value != null && value.trim().isNotEmpty) return value;
  }
  return null;
}

String? _intentFragmentValue(String fragment, String key) {
  for (final part in fragment.split(';')) {
    final separator = part.indexOf('=');
    if (separator <= 0) continue;
    if (part.substring(0, separator) == key) {
      return part.substring(separator + 1).toLowerCase();
    }
  }
  return null;
}

String _credentialOfferByReferenceUri(String offerUri) =>
    '$oid4vciCredentialOfferScheme://?credential_offer_uri=${Uri.encodeQueryComponent(offerUri.trim())}';

String _credentialOfferByValueUri(String offerJson) =>
    '$oid4vciCredentialOfferScheme://?credential_offer=${Uri.encodeQueryComponent(offerJson.trim())}';