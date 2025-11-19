/// QR code fixtures for testing credential flows
/// Provides sample QR code data for all supported protocols
library;

/// Factory for OID4VC (OpenID for Verifiable Credentials) QR codes
class Oid4VcQrFixtures {
  /// University degree credential offer
  static String universityDegreeOffer() {
    return 'openid-credential-offer://?credential_offer=%7B%22credential_issuer%22%3A%22https%3A%2F%2Funiversity.edu%2Fissuer%22%2C%22credentials%22%3A%5B%7B%22format%22%3A%22jwt_vc_json%22%2C%22types%22%3A%5B%22VerifiableCredential%22%2C%22UniversityDegreeCredential%22%5D%7D%5D%2C%22grants%22%3A%7B%22authorization_code%22%3A%7B%22issuer_state%22%3A%22eyJhbGciOiJSU0Et...%22%7D%7D%7D';
  }

  /// Driver license credential offer
  static String driverLicenseOffer() {
    return 'openid-credential-offer://?credential_offer=%7B%22credential_issuer%22%3A%22https%3A%2F%2Fdmv.state.gov%2Fissuer%22%2C%22credentials%22%3A%5B%7B%22format%22%3A%22jwt_vc_json%22%2C%22types%22%3A%5B%22VerifiableCredential%22%2C%22DriverLicenseCredential%22%5D%7D%5D%2C%22grants%22%3A%7B%22urn%3Aietf%3Aparams%3Aoauth%3Agrant-type%3Apre-authorized_code%22%3A%7B%22pre-authorized_code%22%3A%22SplxlOBeZQQYbYS6WxSbIA%22%2C%22user_pin_required%22%3Afalse%7D%7D%7D';
  }

  /// Identity credential offer
  static String identityOffer() {
    return 'openid-credential-offer://?credential_offer=%7B%22credential_issuer%22%3A%22https%3A%2F%2Fgovernment.example%2Fissuer%22%2C%22credentials%22%3A%5B%7B%22format%22%3A%22jwt_vc_json%22%2C%22types%22%3A%5B%22VerifiableCredential%22%2C%22IdentityCredential%22%5D%7D%5D%2C%22grants%22%3A%7B%22urn%3Aietf%3Aparams%3Aoauth%3Agrant-type%3Apre-authorized_code%22%3A%7B%22pre-authorized_code%22%3A%22IdentityCode123%22%2C%22user_pin_required%22%3Atrue%7D%7D%7D';
  }

  /// Professional certificate offer
  static String certificateOffer() {
    return 'openid-credential-offer://?credential_offer=%7B%22credential_issuer%22%3A%22https%3A%2F%2Fcertification-body.org%2Fissuer%22%2C%22credentials%22%3A%5B%7B%22format%22%3A%22jwt_vc_json%22%2C%22types%22%3A%5B%22VerifiableCredential%22%2C%22CertificateCredential%22%5D%7D%5D%2C%22grants%22%3A%7B%22authorization_code%22%3A%7B%22issuer_state%22%3A%22CertState456%22%7D%7D%7D';
  }

  /// Membership credential offer
  static String membershipOffer() {
    return 'openid-credential-offer://?credential_offer=%7B%22credential_issuer%22%3A%22https%3A%2F%2Fprofessional-association.org%2Fissuer%22%2C%22credentials%22%3A%5B%7B%22format%22%3A%22jwt_vc_json%22%2C%22types%22%3A%5B%22VerifiableCredential%22%2C%22MembershipCredential%22%5D%7D%5D%2C%22grants%22%3A%7B%22urn%3Aietf%3Aparams%3Aoauth%3Agrant-type%3Apre-authorized_code%22%3A%7B%22pre-authorized_code%22%3A%22MemberCode789%22%2C%22user_pin_required%22%3Afalse%7D%7D%7D';
  }

  /// Employment credential offer
  static String employmentOffer() {
    return 'openid-credential-offer://?credential_offer=%7B%22credential_issuer%22%3A%22https%3A%2F%2Ftechcorp.example%2Fissuer%22%2C%22credentials%22%3A%5B%7B%22format%22%3A%22jwt_vc_json%22%2C%22types%22%3A%5B%22VerifiableCredential%22%2C%22EmploymentCredential%22%5D%7D%5D%2C%22grants%22%3A%7B%22authorization_code%22%3A%7B%22issuer_state%22%3A%22EmployState012%22%7D%7D%7D';
  }

  /// mDoc credential offer (ISO 18013-5 mobile driver license)
  static String mdocOffer() {
    return 'openid-credential-offer://?credential_offer=%7B%22credential_issuer%22%3A%22https%3A%2F%2Fdmv.state.gov%2Fissuer%22%2C%22credentials%22%3A%5B%7B%22format%22%3A%22mso_mdoc%22%2C%22doctype%22%3A%22org.iso.18013.5.1.mDL%22%7D%5D%2C%22grants%22%3A%7B%22urn%3Aietf%3Aparams%3Aoauth%3Agrant-type%3Apre-authorized_code%22%3A%7B%22pre-authorized_code%22%3A%22MdocPreAuth345%22%2C%22user_pin_required%22%3Afalse%7D%7D%7D';
  }

  /// SD-JWT credential offer
  static String sdJwtOffer() {
    return 'openid-credential-offer://?credential_offer=%7B%22credential_issuer%22%3A%22https%3A%2F%2Fissuer.example.com%22%2C%22credentials%22%3A%5B%7B%22format%22%3A%22vc%2Bsd-jwt%22%2C%22vct%22%3A%22https%3A%2F%2Fcredentials.example.com%2Funiversity-degree%22%7D%5D%2C%22grants%22%3A%7B%22urn%3Aietf%3Aparams%3Aoauth%3Agrant-type%3Apre-authorized_code%22%3A%7B%22pre-authorized_code%22%3A%22SdJwtCode678%22%2C%22user_pin_required%22%3Atrue%7D%7D%7D';
  }

  /// Credential offer with PIN required
  static String offerWithPin() {
    return identityOffer(); // Identity offer requires PIN
  }

  /// Credential offer with authorization code flow
  static String offerWithAuthCode() {
    return universityDegreeOffer(); // University degree uses authorization code
  }

  /// Credential offer with pre-authorized code flow
  static String offerWithPreAuthCode() {
    return driverLicenseOffer(); // Driver license uses pre-authorized code
  }

  /// Invalid/malformed credential offer
  static String malformedOffer() {
    return 'openid-credential-offer://?credential_offer=INVALID_JSON_DATA';
  }

  /// Get all OID4VC offer types
  static List<String> allOffers() {
    return [
      universityDegreeOffer(),
      driverLicenseOffer(),
      identityOffer(),
      certificateOffer(),
      membershipOffer(),
      employmentOffer(),
      mdocOffer(),
      sdJwtOffer(),
    ];
  }
}

/// Factory for W3C VC presentation request QR codes
class W3cPresentationQrFixtures {
  /// Basic presentation request
  static String basicRequest() {
    return 'https://verifier.example.com/present?request=eyJhbGciOiJFUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJkaWQ6d2ViOnZlcmlmaWVyLmV4YW1wbGUuY29tIiwiYXVkIjoiZGlkOmtleTp6Nk1raGFYZ0JaRHZvdERrTDUyNTdmYWl6dGlHaUMyUXRLTEdwYm5uRUd0YTJkb0siLCJpYXQiOjE2Nzg4ODY0MDAsImV4cCI6MTY3ODg5MDAwMCwicmVzcG9uc2VfdHlwZSI6InZwX3Rva2VuIiwicmVzcG9uc2VfbW9kZSI6ImRpcmVjdF9wb3N0IiwicHJlc2VudGF0aW9uX2RlZmluaXRpb24iOnsiaWQiOiJiYXNpYy1yZXF1ZXN0IiwiaW5wdXRfZGVzY3JpcHRvcnMiOlt7ImlkIjoiaWRlbnRpdHkiLCJmb3JtYXQiOnsianl0X3ZwIjp7ImFsZyI6WyJFUzI1NiJdfX0sImNvbnN0cmFpbnRzIjp7ImZpZWxkcyI6W3sicGF0aCI6WyIkLnZjLnR5cGVbKl0iXSwiZmlsdGVyIjp7InR5cGUiOiJzdHJpbmciLCJwYXR0ZXJuIjoiSWRlbnRpdHlDcmVkZW50aWFsIn19XX19XX19.signature';
  }

  /// Request for specific credential type (driver license)
  static String driverLicenseRequest() {
    return 'https://verifier.example.com/present?request=eyJhbGciOiJFUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJkaWQ6d2ViOnZlcmlmaWVyLmV4YW1wbGUuY29tIiwiYXVkIjoiZGlkOmtleTp6Nk1raGFYZ0JaRHZvdERrTDUyNTdmYWl6dGlHaUMyUXRLTEdwYm5uRUd0YTJkb0siLCJpYXQiOjE2Nzg4ODY0MDAsImV4cCI6MTY3ODg5MDAwMCwicmVzcG9uc2VfdHlwZSI6InZwX3Rva2VuIiwicHJlc2VudGF0aW9uX2RlZmluaXRpb24iOnsiaWQiOiJkcml2ZXItbGljZW5zZSIsImlucHV0X2Rlc2NyaXB0b3JzIjpbeyJpZCI6ImRsIiwiZm9ybWF0Ijp7Imp3dF92cCI6eyJhbGciOlsiRVMyNTYiXX19LCJjb25zdHJhaW50cyI6eyJmaWVsZHMiOlt7InBhdGgiOlsiJC52Yy50eXBlWypdIl0sImZpbHRlciI6eyJ0eXBlIjoic3RyaW5nIiwicGF0dGVybiI6IkRyaXZlckxpY2Vuc2VDcmVkZW50aWFsIn19XX19XX19.signature';
  }

  /// Request for selective disclosure
  static String selectiveDisclosureRequest() {
    return 'https://verifier.example.com/present?request=eyJhbGciOiJFUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJkaWQ6d2ViOnZlcmlmaWVyLmV4YW1wbGUuY29tIiwiYXVkIjoiZGlkOmtleTp6Nk1raGFYZ0JaRHZvdERrTDUyNTdmYWl6dGlHaUMyUXRLTEdwYm5uRUd0YTJkb0siLCJpYXQiOjE2Nzg4ODY0MDAsImV4cCI6MTY3ODg5MDAwMCwicHJlc2VudGF0aW9uX2RlZmluaXRpb24iOnsiaWQiOiJzZWxlY3RpdmUtcmVxdWVzdCIsImlucHV0X2Rlc2NyaXB0b3JzIjpbeyJpZCI6InNkLWp3dCIsImZvcm1hdCI6eyJ2Yytmc2Qtand0Ijp7ImFsZyI6WyJFUzI1NiJdfX0sImNvbnN0cmFpbnRzIjp7ImZpZWxkcyI6W3sicGF0aCI6WyIkLnZjdCJdLCJmaWx0ZXIiOnsidHlwZSI6InN0cmluZyIsInBhdHRlcm4iOiJodHRwczovL2NyZWRlbnRpYWxzLmV4YW1wbGUuY29tL2lkZW50aXR5In19LHsicGF0aCI6WyIkLmdpdmVuX25hbWUiXX0seyJwYXRoIjpbIiQuZmFtaWx5X25hbWUiXX1dfX1dfX0.signature';
  }

  /// Request for multiple credentials
  static String multiCredentialRequest() {
    return 'https://verifier.example.com/present?request=eyJhbGciOiJFUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJkaWQ6d2ViOnZlcmlmaWVyLmV4YW1wbGUuY29tIiwiYXVkIjoiZGlkOmtleTp6Nk1raGFYZ0JaRHZvdERrTDUyNTdmYWl6dGlHaUMyUXRLTEdwYm5uRUd0YTJkb0siLCJpYXQiOjE2Nzg4ODY0MDAsImV4cCI6MTY3ODg5MDAwMCwicHJlc2VudGF0aW9uX2RlZmluaXRpb24iOnsiaWQiOiJtdWx0aS1jcmVkZW50aWFsIiwiaW5wdXRfZGVzY3JpcHRvcnMiOlt7ImlkIjoiaWRlbnRpdHkiLCJmb3JtYXQiOnsianl0X3ZwIjp7ImFsZyI6WyJFUzI1NiJdfX0sImNvbnN0cmFpbnRzIjp7ImZpZWxkcyI6W3sicGF0aCI6WyIkLnZjLnR5cGVbKl0iXSwiZmlsdGVyIjp7InR5cGUiOiJzdHJpbmciLCJwYXR0ZXJuIjoiSWRlbnRpdHlDcmVkZW50aWFsIn19XX19LHsiaWQiOiJlbXBsb3ltZW50IiwiZm9ybWF0Ijp7Imp3dF92cCI6eyJhbGciOlsiRVMyNTYiXX19LCJjb25zdHJhaW50cyI6eyJmaWVsZHMiOlt7InBhdGgiOlsiJC52Yy50eXBlWypdIl0sImZpbHRlciI6eyJ0eXBlIjoic3RyaW5nIiwicGF0dGVybiI6IkVtcGxveW1lbnRDcmVkZW50aWFsIn19XX19XX19.signature';
  }

  /// Invalid presentation request
  static String malformedRequest() {
    return 'https://verifier.example.com/present?request=INVALID_JWT';
  }

  /// Get all presentation request types
  static List<String> allRequests() {
    return [
      basicRequest(),
      driverLicenseRequest(),
      selectiveDisclosureRequest(),
      multiCredentialRequest(),
    ];
  }
}

/// Factory for mDoc presentation request QR codes
class MDocPresentationQrFixtures {
  /// Basic mDL presentation request (driver license)
  static String mdlRequest() {
    return 'mdoc://verifier.example.com?request=%7B%22version%22%3A%221.0%22%2C%22docRequests%22%3A%5B%7B%22itemsRequest%22%3A%7B%22docType%22%3A%22org.iso.18013.5.1.mDL%22%2C%22nameSpaces%22%3A%7B%22org.iso.18013.5.1%22%3A%7B%22family_name%22%3Atrue%2C%22given_name%22%3Atrue%2C%22birth_date%22%3Atrue%2C%22portrait%22%3Afalse%7D%7D%7D%7D%5D%7D';
  }

  /// mID presentation request (mobile ID)
  static String midRequest() {
    return 'mdoc://verifier.example.com?request=%7B%22version%22%3A%221.0%22%2C%22docRequests%22%3A%5B%7B%22itemsRequest%22%3A%7B%22docType%22%3A%22org.iso.18013.5.1.mID%22%2C%22nameSpaces%22%3A%7B%22org.iso.18013.5.1%22%3A%7B%22family_name%22%3Atrue%2C%22given_name%22%3Atrue%2C%22birth_date%22%3Atrue%2C%22nationality%22%3Atrue%7D%7D%7D%7D%5D%7D';
  }

  /// Passport presentation request
  static String passportRequest() {
    return 'mdoc://verifier.example.com?request=%7B%22version%22%3A%221.0%22%2C%22docRequests%22%3A%5B%7B%22itemsRequest%22%3A%7B%22docType%22%3A%22org.icao.mrtd.passport%22%2C%22nameSpaces%22%3A%7B%22org.icao.mrtd%22%3A%7B%22family_name%22%3Atrue%2C%22given_name%22%3Atrue%2C%22document_number%22%3Atrue%2C%22nationality%22%3Atrue%7D%7D%7D%7D%5D%7D';
  }

  /// Request with age verification only
  static String ageVerificationRequest() {
    return 'mdoc://verifier.example.com?request=%7B%22version%22%3A%221.0%22%2C%22docRequests%22%3A%5B%7B%22itemsRequest%22%3A%7B%22docType%22%3A%22org.iso.18013.5.1.mDL%22%2C%22nameSpaces%22%3A%7B%22org.iso.18013.5.1%22%3A%7B%22age_over_18%22%3Atrue%2C%22age_over_21%22%3Atrue%7D%7D%7D%7D%5D%7D';
  }

  /// Get all mDoc request types
  static List<String> allRequests() {
    return [
      mdlRequest(),
      midRequest(),
      passportRequest(),
      ageVerificationRequest(),
    ];
  }
}

/// Factory for TOTP/HOTP QR codes
class TotpHotpQrFixtures {
  /// Standard TOTP QR code
  static String totpBasic() {
    return 'otpauth://totp/Example:alice@example.com?secret=JBSWY3DPEHPK3PXP&issuer=Example';
  }

  /// TOTP with custom parameters
  static String totpCustom() {
    return 'otpauth://totp/GitHub:alice@example.com?secret=HXDMVJECJJWSRB3HWIZR4IFUGFTMXBOZ&issuer=GitHub&algorithm=SHA256&digits=8&period=60';
  }

  /// HOTP QR code
  static String hotpBasic() {
    return 'otpauth://hotp/Example:alice@example.com?secret=JBSWY3DPEHPK3PXP&issuer=Example&counter=0';
  }

  /// Steam Guard TOTP (special format)
  static String steamGuard() {
    return 'otpauth://totp/Steam:alice?secret=JBSWY3DPEHPK3PXP&issuer=Steam&digits=5&period=30';
  }

  /// Get all TOTP/HOTP types
  static List<String> allTotpHotp() {
    return [
      totpBasic(),
      totpCustom(),
      hotpBasic(),
      steamGuard(),
    ];
  }
}

/// Master QR fixture class combining all QR types
class SpruceQrFixtures {
  /// Get all QR code types
  static Map<String, List<String>> allQrCodes() {
    return {
      'oid4vc': Oid4VcQrFixtures.allOffers(),
      'w3cPresentation': W3cPresentationQrFixtures.allRequests(),
      'mdocPresentation': MDocPresentationQrFixtures.allRequests(),
      'totpHotp': TotpHotpQrFixtures.allTotpHotp(),
    };
  }

  /// Get a diverse set of QR codes for UI testing
  static List<String> diverseSet() {
    return [
      Oid4VcQrFixtures.universityDegreeOffer(),
      Oid4VcQrFixtures.driverLicenseOffer(),
      Oid4VcQrFixtures.mdocOffer(),
      W3cPresentationQrFixtures.basicRequest(),
      MDocPresentationQrFixtures.mdlRequest(),
      TotpHotpQrFixtures.totpBasic(),
    ];
  }

  /// Get test scenarios with specific flows
  static Map<String, String> testScenarios() {
    return {
      'credential_offer_no_pin': Oid4VcQrFixtures.offerWithPreAuthCode(),
      'credential_offer_with_pin': Oid4VcQrFixtures.offerWithPin(),
      'presentation_request_single': W3cPresentationQrFixtures.basicRequest(),
      'presentation_request_multiple': W3cPresentationQrFixtures.multiCredentialRequest(),
      'mdoc_offer': Oid4VcQrFixtures.mdocOffer(),
      'mdoc_presentation': MDocPresentationQrFixtures.mdlRequest(),
      'totp_token': TotpHotpQrFixtures.totpBasic(),
      'malformed_offer': Oid4VcQrFixtures.malformedOffer(),
      'malformed_request': W3cPresentationQrFixtures.malformedRequest(),
    };
  }
}
