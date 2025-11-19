import { Buffer } from 'buffer';

// Decode the credential offer URL that was generated
const encodedOffer = "eyJjcmVkZW50aWFsX2lzc3VlciI6Imh0dHBzOi8vdHJ1ZWlkZW50aXR5aW5jLmF6dXJld2Vic2l0ZXMubmV0IiwiY3JlZGVudGlhbHMiOlt7ImZvcm1hdCI6Imp3dF92Y19qc29uIiwidHlwZXMiOlsiVmVyaWZpYWJsZUNyZWRlbnRpYWwiLCJJZGVudGl0eUNyZWRlbnRpYWwiXSwiY3JlZGVudGlhbFN1YmplY3QiOnsiaWQiOiJkaWQ6a2V5OnRlc3Qtc3ViamVjdCIsIm5hbWUiOiJKb2huIERvZSIsImVtYWlsIjoiam9obi5kb2VAZXhhbXBsZS5jb20iLCJ2ZXJpZmllZCI6dHJ1ZSwiaXNzdWVEYXRlIjoiMjAyNS0xMS0xNlQwNTo1NDoxNS42MTZaIn19XSwiZ3JhbnRzIjp7InVybjppZXRmOnBhcmFtczpvYXV0aDpncmFudC10eXBlOnByZS1hdXRob3JpemVkX2NvZGUiOnsicHJlLWF1dGhvcml6ZWRfY29kZSI6ImNyZWRlbnRpYWwtdGVzdC0xMjM0NTYiLCJ1c2VyX3Bpbl9yZXF1aXJlZCI6ZmFsc2V9fX0=";

try {
  // Decode the base64 credential offer
  const decodedOffer = Buffer.from(encodedOffer, 'base64').toString('utf-8');
  const offerJson = JSON.parse(decodedOffer);
  
  console.log('🔍 Decoded Credential Offer:');
  console.log(JSON.stringify(offerJson, null, 2));
  
  console.log('\n📋 Credential Offer Analysis:');
  console.log(`✅ Issuer: ${offerJson.credential_issuer}`);
  console.log(`✅ Credential Format: ${offerJson.credentials[0].format}`);
  console.log(`✅ Credential Types: ${offerJson.credentials[0].types.join(', ')}`);
  console.log(`✅ Subject Name: ${offerJson.credentials[0].credentialSubject.name}`);
  console.log(`✅ Pre-auth Code: ${offerJson.grants['urn:ietf:params:oauth:grant-type:pre-authorized_code']['pre-authorized_code']}`);
  console.log(`✅ Pin Required: ${offerJson.grants['urn:ietf:params:oauth:grant-type:pre-authorized_code']['user_pin_required']}`);
  
  console.log('\n🎯 This is a valid OID4VCI credential offer that would be contained in a QR code!');
  console.log('📱 On a mobile device, scanning this QR code would open the authenticator app');
  console.log('🔗 The app would process the openid-credential-offer:// URL scheme');
  console.log('🏪 And automatically add the credential to the user\'s digital wallet');
  
} catch (error) {
  console.error('❌ Error decoding credential offer:', error);
}