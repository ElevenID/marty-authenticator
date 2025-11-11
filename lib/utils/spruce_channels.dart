/// Platform channels for SpruceID integration with clear separation of concerns
///
/// This file defines the method channel names and method signatures
/// for communicating with native SpruceKit Mobile SDKs, organized by technology
class SpruceIdChannels {
  // W3C Verifiable Credentials (DID-based only)
  static const String w3c = 'com.netknights.authenticator/spruce_w3c';

  // mDoc/MDL (X.509-based)
  static const String mdoc = 'com.netknights.authenticator/spruce_mdoc';

  // JWT/SD-JWT (URL issuer-based)
  static const String jwt = 'com.netknights.authenticator/spruce_jwt';

  // PKI/X.509 operations (certificate-based)
  static const String pki = 'com.netknights.authenticator/spruce_pki';

  // Credential storage (technology agnostic)
  static const String wallet = 'com.netknights.authenticator/spruce_wallet';

  // Legacy support
  @Deprecated('Use SpruceIdChannels.w3c instead')
  static const String main = 'com.netknights.authenticator/spruce_id';
  @Deprecated('Use SpruceIdChannels.oid4vc_native instead')
  static const String oid4vc = 'com.netknights.authenticator/spruce_oid4vc';
}

/// Method names for W3C Verifiable Credentials (DID-required)
class SpruceIdW3CMethods {
  static const String initialize = 'initialize';
  static const String createDid = 'createDid';
  static const String resolveDid = 'resolveDid';
  static const String signVerifiableCredential = 'signVerifiableCredential';
  static const String verifyVerifiableCredential = 'verifyVerifiableCredential';
}

/// Method names for PKI/X.509 operations (certificate-based)
class SpruceIdPkiMethods {
  static const String generateKeyPair = 'generateKeyPair';
  static const String createCSR = 'createCSR';
  static const String signWithCertificate = 'signWithCertificate';
  static const String verifyCertificateChain = 'verifyCertificateChain';
}

/// Method names for JWT/SD-JWT operations (URL issuer-based)
class SpruceIdJwtMethods {
  static const String createJWT = 'createJWT';
  static const String verifyJWT = 'verifyJWT';
  static const String createSdJwt = 'createSdJwt';
  static const String verifySdJwt = 'verifySdJwt';
}

/// Method names for mDoc/MDL channel
class SpruceIdMdocMethods {
  // mDoc operations
  static const String initializeMdl = 'initializeMdl';
  static const String createDeviceEngagement = 'createDeviceEngagement';
  static const String createMdocResponse = 'createMdocResponse';
  static const String presentForAgeVerification = 'presentForAgeVerification';
  static const String presentForIdVerification = 'presentForIdVerification';

  // Session management
  static const String startSession = 'startSession';
  static const String handleRequest = 'handleRequest';
  static const String getSessionStatus = 'getSessionStatus';
}

/// Method names for OID4VC channel
class SpruceIdOid4vcMethods {
  // OID4VP operations
  static const String handleVpRequest = 'handleVpRequest';
  static const String createPresentation = 'createPresentation';

  // OID4VCI operations
  static const String handleCredentialOffer = 'handleCredentialOffer';
  static const String requestCredential = 'requestCredential';

  // SD-JWT operations
  static const String createSdJwt = 'createSdJwt';
  static const String presentSdJwt = 'presentSdJwt';
}

/// Method names for wallet operations
class SpruceIdWalletMethods {
  // Credential storage
  static const String storeCredential = 'storeCredential';
  static const String getCredentials = 'getCredentials';
  static const String getCredentialsByType = 'getCredentialsByType';
  static const String deleteCredential = 'deleteCredential';

  // Wallet management
  static const String exportWallet = 'exportWallet';
  static const String importWallet = 'importWallet';
  static const String backupWallet = 'backupWallet';
}

/// Error codes for SpruceID operations
class SpruceIdErrors {
  static const String initializationFailed = 'INITIALIZATION_FAILED';
  static const String invalidCredential = 'INVALID_CREDENTIAL';
  static const String verificationFailed = 'VERIFICATION_FAILED';
  static const String didOperationFailed = 'DID_OPERATION_FAILED';
  static const String mdocOperationFailed = 'MDOC_OPERATION_FAILED';
  static const String oid4vcOperationFailed = 'OID4VC_OPERATION_FAILED';
  static const String walletOperationFailed = 'WALLET_OPERATION_FAILED';
  static const String unsupportedOperation = 'UNSUPPORTED_OPERATION';
  static const String networkError = 'NETWORK_ERROR';
  static const String storageError = 'STORAGE_ERROR';
}
