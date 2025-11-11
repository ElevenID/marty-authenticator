# SpruceID Integration Testing Documentation

## Overview

This document describes the comprehensive test suite for the SpruceID integration in the PrivacyIDEA Authenticator app. The tests verify the complete implementation of Self-Sovereign Identity (SSI) capabilities using real data and production-ready scenarios.

## Test Architecture

### Test Coverage Areas

1. **Platform Channel Communication** (`platform_channel_test.dart`)
   - Flutter-to-native method calls
   - Cross-platform data serialization
   - Error handling and exception propagation
   - Method signature validation

2. **Real Data Validation** (`real_data_validation_test.dart`)
   - W3C Verifiable Credentials format compliance
   - ISO 18013-5 mDoc/MDL structure validation
   - SD-JWT format and selective disclosure
   - DID resolution and document formats
   - Cryptographic signature validation

3. **SpruceID Client Integration** (`spruce_id_client_test.dart`)
   - High-level client API testing
   - Credential lifecycle management
   - Wallet operations
   - Error scenarios and recovery

4. **End-to-End Workflows** (`end_to_end_test.dart`)
   - Complete credential issuance workflows
   - Multi-system integration scenarios
   - Cross-platform coordination
   - Real-world use case simulation

## Test Data Standards

### W3C Verifiable Credentials

The tests use authentic W3C Verifiable Credential structures:

```json
{
  "@context": [
    "https://www.w3.org/2018/credentials/v1",
    "https://www.w3.org/2018/credentials/examples/v1"
  ],
  "type": ["VerifiableCredential", "UniversityDegreeCredential"],
  "issuer": {
    "id": "did:web:university.edu",
    "name": "Technical University of Munich"
  },
  "credentialSubject": {
    "id": "did:key:z6MkjchhfUsD6mmvni8mCdXHw216Xrm9bQe2mBH1P5RDjVJG",
    "degree": {
      "type": "BachelorDegree",
      "name": "Bachelor of Science in Computer Science"
    }
  }
}
```

### ISO 18013-5 Mobile Documents

Tests include real ISO 18013-5 mDL (mobile Driving License) structures:

```json
{
  "docType": "org.iso.18013.5.1.mDL",
  "nameSpaces": {
    "org.iso.18013.5.1": {
      "family_name": "Müller",
      "given_name": "Anna",
      "birth_date": "1985-03-15",
      "driving_privileges": [
        {
          "vehicle_category_code": "B",
          "issue_date": "2020-03-15",
          "expiry_date": "2030-03-14"
        }
      ]
    }
  }
}
```

### SD-JWT (Selective Disclosure JWT)

Real SD-JWT format with selective disclosure capabilities:

```
eyJhbGciOiJFZERTQSJ9.eyJpc3MiOiJkaWQ6a2V5OnRlc3QiLCJfc2QiOlsiY2xhaW0xIl19.sig~WyJzYWx0IiwiZ2l2ZW5fbmFtZSIsIkpvaG4iXQ~
```

## Test Scenarios

### 1. University Degree Verification Workflow

**Scenario:** Student receives digital degree credential and presents it for job verification

**Steps:**

1. University creates DID (issuer)
2. Student creates DID (holder)
3. University issues verifiable credential
4. Credential stored in student's wallet
5. Student presents credential to employer
6. Employer verifies credential authenticity

**Test Coverage:**

- DID creation and management
- Credential signing with Ed25519
- Wallet storage and retrieval
- Verification and proof checking

### 2. Age Verification with mDoc

**Scenario:** Person uses digital driving license for age-restricted purchase

**Steps:**

1. Initialize mDL with government-issued data
2. Merchant requests age verification (21+)
3. Selective disclosure (age only, no personal details)
4. Proximity-based verification
5. Return verification result

**Test Coverage:**

- mDoc initialization with real DMV data
- Selective disclosure for privacy
- Age calculation and verification
- CBOR encoding for transport

### 3. Selective Disclosure with SD-JWT

**Scenario:** Professional sharing credentials with selective privacy

**Steps:**

1. Create comprehensive professional credential
2. Generate SD-JWT with multiple disclosable claims
3. Create selective presentation (name + title only)
4. Verify presentation without revealing private data

**Test Coverage:**

- Multi-claim credential creation
- Hash-based selective disclosure
- Presentation generation
- Privacy-preserving verification

## Mock Data Sources

### Real-World Credential Examples

- **EU eID Credentials:** Based on actual European Digital Identity formats
- **German University Degrees:** Follows ECTS and German grading standards
- **US Driving Licenses:** Compliant with REAL ID requirements
- **Professional Certificates:** Industry-standard credential formats

### Cryptographic Standards

- **Ed25519 Signatures:** Real signature formats and key structures
- **DID Methods:** Authentic did:key, did:web, did:jwk formats
- **COSE Signatures:** ISO 18013-5 compliant signing structures
- **Multibase Encoding:** Standard key encoding formats

## Platform Channel Testing

### Method Coverage

#### Main SpruceID Channel (`com.netknights.authenticator/spruce_id`)

- `initialize()` - SDK initialization
- `createDid(method)` - DID creation (key, web, jwk methods)
- `signCredential(credential)` - W3C credential signing
- `verifyCredential(credential)` - Signature verification

#### mDoc Channel (`com.netknights.authenticator/spruce_mdoc`)

- `initializeMdl(mdlData)` - Mobile document setup
- `presentForAgeVerification(minimumAge)` - Age verification
- `createMdocResponse(docType, attributes, requestedAttributes)` - Selective disclosure

#### OID4VC Channel (`com.netknights.authenticator/spruce_oid4vc`)

- `initializeOid4vc()` - OpenID for Verifiable Credentials setup
- `createSdJwt(claims, selectivelyDisclosableClaims)` - SD-JWT creation
- `verifyPresentation(presentation)` - Presentation verification

#### Wallet Channel (`com.netknights.authenticator/spruce_wallet`)

- `initializeWallet()` - Wallet initialization
- `storeCredential(credential)` - Credential storage
- `getCredentials()` - Retrieve all credentials
- `getCredentialsByType(type)` - Type-filtered retrieval

### Error Handling Tests

- **Network Failures:** DID resolver connectivity issues
- **Invalid Data:** Malformed credentials and documents
- **Missing Dependencies:** SDK initialization failures
- **Platform Exceptions:** Native code error propagation

## Running the Tests

### Prerequisites

1. Flutter SDK installed and configured
2. Android/iOS development environment
3. SpruceID SDK dependencies added to project

### Execution Methods

#### Individual Test Files

```bash
# Platform channel tests
flutter test test/integration/spruce_id/platform_channel_test.dart

# Real data validation
flutter test test/integration/spruce_id/real_data_validation_test.dart

# Client integration tests
flutter test test/integration/spruce_id/spruce_id_client_test.dart

# End-to-end workflows
flutter test test/integration/spruce_id/end_to_end_test.dart
```

#### Complete Test Suite

```bash
# Run all SpruceID integration tests
./test_spruceid_integration.sh
```

#### With Coverage

```bash
# Generate test coverage report
flutter test --coverage test/integration/spruce_id/
genhtml coverage/lcov.info -o coverage/html
```

## Test Results Interpretation

### Success Criteria

- ✅ All platform channels respond correctly
- ✅ Real data formats validate successfully
- ✅ Cryptographic operations complete without errors
- ✅ End-to-end workflows execute in correct sequence
- ✅ Error handling prevents crashes and provides meaningful feedback

### Common Failure Modes

1. **Mock Data Mismatch**
   - Symptom: Type errors in test assertions
   - Solution: Verify mock data structure matches SDK expectations

2. **Platform Channel Signature Errors**
   - Symptom: Missing method exceptions
   - Solution: Check method names and parameter structures

3. **Real Data Format Issues**
   - Symptom: Validation failures on authentic data
   - Solution: Update test data to match latest standards

4. **Async/Await Problems**
   - Symptom: Premature test completion
   - Solution: Ensure all async operations are properly awaited

## Production Readiness Validation

### Security Considerations

- **Key Management:** Proper key generation and storage
- **Signature Verification:** Cryptographic integrity checks
- **Privacy Protection:** Selective disclosure implementation
- **Data Validation:** Input sanitization and format checking

### Performance Benchmarks

- **DID Creation:** < 100ms for key-based DIDs
- **Credential Signing:** < 200ms for standard credentials
- **Verification:** < 150ms for signature checking
- **Storage Operations:** < 50ms for wallet interactions

### Standards Compliance

- ✅ W3C Verifiable Credentials Data Model v1.1
- ✅ ISO/IEC 18013-5:2021 (mDL)
- ✅ RFC 7519 (JSON Web Token)
- ✅ DID Core Specification v1.0
- ✅ Selective Disclosure for JWTs (SD-JWT)

## Integration with CI/CD

### GitHub Actions Integration

```yaml
name: SpruceID Integration Tests
on: [push, pull_request]

jobs:
  spruceid-tests:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - uses: subosito/flutter-action@v2
      - run: flutter pub get
      - run: ./test_spruceid_integration.sh
```

### Quality Gates

- **All tests must pass** before merging
- **Code coverage** > 80% for SpruceID modules
- **No security warnings** in dependency analysis
- **Performance tests** within acceptable ranges

## Troubleshooting

### Common Issues

1. **Flutter Channel Errors**

   ```
   MissingPluginException: No implementation found for method createDid
   ```

   - Check platform channel registration in native code
   - Verify method names match between Dart and native implementations

2. **SDK Integration Issues**

   ```
   PlatformException: SpruceKit not initialized
   ```

   - Ensure SDK dependencies are properly linked
   - Check SDK version compatibility

3. **Data Format Errors**

   ```
   FormatException: Invalid credential structure
   ```

   - Validate credential against W3C schemas
   - Check required fields are present

### Debug Mode

Enable verbose logging for detailed test execution:

```bash
flutter test --dart-define=SPRUCEID_DEBUG=true test/integration/spruce_id/
```

## Continuous Integration

The test suite is designed for automated execution in CI/CD pipelines with:

- **Fast execution** (< 30 seconds total)
- **Deterministic results** (no flaky tests)
- **Clear failure reporting** with actionable error messages
- **Parallel execution** support for faster builds

This comprehensive testing approach ensures the SpruceID integration is production-ready and maintains high quality standards throughout development.
