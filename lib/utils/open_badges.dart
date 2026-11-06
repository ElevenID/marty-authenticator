import 'dart:convert';

const retiredOpenBadgesMessage =
    'Open Badges 2.0 is no longer supported. Ask the issuer to reissue your '
    'badge as Open Badges 3.0.';

/// Identify retired assertions before any credential presentation or routing.
/// JWT contents are decoded only to reject legacy input, never to verify it.
bool isRetiredOpenBadge(Object? value) {
  if (value is List) {
    return value.any(isRetiredOpenBadge);
  }
  if (value is String) {
    final parts = value.split('~').first.split('.');
    if (parts.length != 3) return false;
    try {
      return isRetiredOpenBadge(
        jsonDecode(utf8.decode(base64Url.decode(base64Url.normalize(parts[1])))),
      );
    } on FormatException {
      return false;
    }
  }
  if (value is! Map) return false;

  bool containsMarker(Object? candidate, bool Function(String) matches) {
    if (candidate is String) return matches(candidate);
    return candidate is List &&
        candidate.any((item) => item is String && matches(item));
  }

  bool legacyContext(String context) =>
      context.contains('openbadges/v2') ||
      context.contains('/ob/v2p0/');

  if (containsMarker(value['@context'], legacyContext) ||
      containsMarker(value['context'], legacyContext) ||
      containsMarker(value['type'], (type) => type == 'Assertion')) {
    return true;
  }
  return const [
    'credential',
    'vc',
    'assertion',
    'vp',
    'verifiableCredential',
  ].any((key) => isRetiredOpenBadge(value[key]));
}
