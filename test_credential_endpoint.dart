import 'dart:convert';
import 'dart:io';

/// Test script to verify credential reception from the endpoint
/// https://trueidentityinc.azurewebsites.net/verify-credential
Future<void> testCredentialReception() async {
  final httpClient = HttpClient();

  try {
    print(
      'Testing credential reception from: https://trueidentityinc.azurewebsites.net/verify-credential',
    );

    // Create a sample credential for testing
    final testCredential = {
      '@context': ['https://www.w3.org/2018/credentials/v1'],
      'type': ['VerifiableCredential'],
      'issuer': 'did:key:test-issuer',
      'issuanceDate': DateTime.now().toIso8601String(),
      'credentialSubject': {
        'id': 'did:key:test-subject',
        'name': 'Test User',
        'email': 'test@example.com',
      },
    };

    // Make POST request to the verification endpoint
    final request = await httpClient.postUrl(
      Uri.parse('https://trueidentityinc.azurewebsites.net/verify-credential'),
    );

    request.headers.set('Content-Type', 'application/json');
    request.write(jsonEncode(testCredential));

    final response = await request.close();
    final responseBody = await response.transform(utf8.decoder).join();

    print('Response Status: ${response.statusCode}');
    print('Response Headers: ${response.headers}');
    print('Response Body: $responseBody');

    if (response.statusCode == 200) {
      print('✅ Credential verification successful!');
      final responseData = jsonDecode(responseBody);
      print('Verification Result: $responseData');
    } else {
      print(
        '❌ Credential verification failed with status: ${response.statusCode}',
      );
    }
  } catch (e) {
    print('❌ Error during credential verification: $e');
  } finally {
    httpClient.close();
  }
}

Future<void> testCredentialOfferReception() async {
  final httpClient = HttpClient();

  try {
    print('\n--- Testing credential offer reception ---');

    // Create a sample credential offer
    final credentialOffer = {
      'credential_issuer': 'https://trueidentityinc.azurewebsites.net',
      'credentials': [
        {
          'format': 'jwt_vc_json',
          'types': ['VerifiableCredential', 'UniversityDegreeCredential'],
        },
      ],
      'grants': {
        'urn:ietf:params:oauth:grant-type:pre-authorized_code': {
          'pre-authorized_code': 'test-pre-auth-code-123',
        },
      },
    };

    // Test OID4VCI credential offer deep link
    final offerUri = Uri.parse('openid-credential-offer://').replace(
      queryParameters: {'credential_offer': jsonEncode(credentialOffer)},
    );

    print('Generated credential offer URI: $offerUri');

    // In a real scenario, this would be handled by the app's deep link processor
    print('✅ Credential offer URI generated for deep linking');
  } catch (e) {
    print('❌ Error generating credential offer: $e');
  } finally {
    httpClient.close();
  }
}

void main() async {
  print('🚀 Starting credential endpoint testing...\n');

  await testCredentialReception();
  await testCredentialOfferReception();

  print('\n✨ Testing complete!');
}
