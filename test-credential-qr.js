import { chromium } from 'playwright';

async function scanQRCodeAndTestCredentials() {
  const browser = await chromium.launch({ headless: false });
  const context = await browser.newContext();
  
  try {
    // Open the credential verification page
    const page = await context.newPage();
    console.log('🌐 Navigating to credential verification page...');
    await page.goto('https://trueidentityinc.azurewebsites.net/verify-credential');
    
    // Wait for page to load
    await page.waitForLoadState('networkidle');
    
    // Take a screenshot to see what's on the page
    await page.screenshot({ path: 'credential-page.png', fullPage: true });
    console.log('📸 Screenshot taken: credential-page.png');
    
    // Look for QR codes or credential offer elements
    const qrElements = await page.$$eval('canvas, img[src*="qr"], img[alt*="QR"], .qr-code, #qr-code', 
      elements => elements.map(el => ({
        tagName: el.tagName,
        src: el.src || '',
        alt: el.alt || '',
        className: el.className || '',
        id: el.id || ''
      }))
    );
    
    if (qrElements.length > 0) {
      console.log('🎯 Found QR code elements:', qrElements);
    } else {
      console.log('❓ No QR code elements found, checking page content...');
    }
    
    // Check for credential offer URLs or deep links
    const pageContent = await page.content();
    const credentialOfferRegex = /openid-credential-offer:\/\/[^\s"']*/g;
    const oid4vpRegex = /openid4vp:\/\/[^\s"']*/g;
    
    const credentialOffers = pageContent.match(credentialOfferRegex) || [];
    const presentationRequests = pageContent.match(oid4vpRegex) || [];
    
    console.log('🔍 Found credential offers:', credentialOffers);
    console.log('🔍 Found presentation requests:', presentationRequests);
    
    // Open Flutter app in new tab to test credential reception
    console.log('🚀 Opening Flutter app...');
    const flutterPage = await context.newPage();
    await flutterPage.goto('http://localhost:8080');
    
    // Wait for Flutter app to load
    await flutterPage.waitForLoadState('networkidle');
    await flutterPage.screenshot({ path: 'flutter-app.png', fullPage: true });
    console.log('📸 Flutter app screenshot taken: flutter-app.png');
    
    // If we found a credential offer, test it directly
    if (credentialOffers.length > 0) {
      const offerUrl = credentialOffers[0];
      console.log('🧪 Testing credential offer:', offerUrl);
      
      // Try to navigate to the credential offer URL (this would trigger the deep link)
      try {
        await flutterPage.goto(offerUrl);
        console.log('✅ Successfully navigated to credential offer URL');
      } catch (error) {
        console.log('⚠️ Direct navigation failed, this is expected for deep links');
        console.log('   In a real mobile app, this would be handled by the OS');
      }
    }
    
    // Simulate credential issuance by creating a test credential offer
    console.log('🔧 Creating test credential offer...');
    const testCredentialOffer = {
      "credential_issuer": "https://trueidentityinc.azurewebsites.net",
      "credentials": [{
        "format": "jwt_vc_json",
        "types": ["VerifiableCredential", "IdentityCredential"],
        "credentialSubject": {
          "id": "did:key:test-subject",
          "name": "Test User",
          "verified": true
        }
      }],
      "grants": {
        "urn:ietf:params:oauth:grant-type:pre-authorized_code": {
          "pre-authorized_code": "test-pre-auth-code-123",
          "user_pin_required": false
        }
      }
    };
    
    const encodedOffer = btoa(JSON.stringify(testCredentialOffer));
    const testOfferUrl = `openid-credential-offer://?credential_offer=${encodedOffer}`;
    
    console.log('📋 Generated test credential offer URL:');
    console.log(testOfferUrl);
    
    // Check if the Flutter app has QR scanning capabilities
    const hasQRScanner = await flutterPage.evaluate(() => {
      return document.querySelector('[data-testid="qr-scanner"]') !== null ||
             document.querySelector('.qr-scanner') !== null ||
             document.body.textContent.includes('Scan QR') ||
             document.body.textContent.includes('scan') ||
             document.body.textContent.includes('QR');
    });
    
    console.log('🔍 Flutter app has QR scanner:', hasQRScanner);
    
    // Wait a moment to see the results
    await new Promise(resolve => setTimeout(resolve, 5000));
    
  } catch (error) {
    console.error('❌ Error during credential testing:', error);
  } finally {
    await browser.close();
  }
}

console.log('🚀 Starting credential QR code and OID4VC testing...');
scanQRCodeAndTestCredentials()
  .then(() => {
    console.log('✅ Testing completed!');
  })
  .catch(error => {
    console.error('💥 Testing failed:', error);
  });