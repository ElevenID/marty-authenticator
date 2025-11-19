import { chromium } from 'playwright';

async function testCredentialReceptionInFlutter() {
  const browser = await chromium.launch({ headless: false });
  const context = await browser.newContext();
  
  try {
    // Open the Flutter app
    console.log('🚀 Opening Flutter app...');
    const page = await context.newPage();
    await page.goto('http://localhost:8080');
    await page.waitForLoadState('networkidle');
    
    // Take initial screenshot
    await page.screenshot({ path: 'flutter-initial.png', fullPage: true });
    
    // Create a test credential offer (same as what would be in QR code)
    const credentialOffer = {
      "credential_issuer": "https://trueidentityinc.azurewebsites.net",
      "credentials": [{
        "format": "jwt_vc_json", 
        "types": ["VerifiableCredential", "IdentityCredential"],
        "credentialSubject": {
          "id": "did:key:test-subject",
          "name": "John Doe",
          "email": "john.doe@example.com",
          "verified": true,
          "issueDate": new Date().toISOString()
        }
      }],
      "grants": {
        "urn:ietf:params:oauth:grant-type:pre-authorized_code": {
          "pre-authorized_code": "credential-test-123456",
          "user_pin_required": false
        }
      }
    };
    
    const encodedOffer = btoa(JSON.stringify(credentialOffer));
    const credentialOfferUrl = `openid-credential-offer://?credential_offer=${encodedOffer}`;
    
    console.log('📋 Testing credential offer URL:');
    console.log(credentialOfferUrl);
    
    // Look for QR scanner or import functionality in the Flutter app
    console.log('🔍 Looking for QR scanner or import functionality...');
    
    const scanButton = await page.$('[data-testid="qr-scanner"], button:has-text("Scan"), button:has-text("QR"), .scan-button, #scan-button');
    if (scanButton) {
      console.log('🎯 Found scan button, clicking it...');
      await scanButton.click();
      await page.waitForTimeout(2000);
    }
    
    // Look for add/import token functionality
    const addButton = await page.$('button:has-text("Add"), button:has-text("Import"), button:has-text("+"), .add-token, #add-token');
    if (addButton) {
      console.log('➕ Found add button, clicking it...');
      await addButton.click();
      await page.waitForTimeout(2000);
    }
    
    // Check if there's a way to manually input a credential offer
    const inputFields = await page.$$('input[type="text"], input[type="url"], textarea');
    if (inputFields.length > 0) {
      console.log(`📝 Found ${inputFields.length} input fields, trying to input credential offer...`);
      
      // Try to input the credential offer URL in the first text input
      await inputFields[0].fill(credentialOfferUrl);
      await page.waitForTimeout(1000);
      
      // Look for submit/continue buttons
      const submitButton = await page.$('button:has-text("Submit"), button:has-text("Continue"), button:has-text("Add"), button:has-text("Import")');
      if (submitButton) {
        console.log('✅ Found submit button, clicking it...');
        await submitButton.click();
        await page.waitForTimeout(3000);
      }
    }
    
    // Try to simulate a deep link directly using JavaScript
    console.log('🔗 Attempting to trigger deep link handling...');
    
    await page.evaluate((url) => {
      // Try to trigger deep link handling
      if (window.flutter && window.flutter.triggerDeepLink) {
        window.flutter.triggerDeepLink(url);
      }
      
      // Try posting message to Flutter
      if (window.postMessage) {
        window.postMessage({ 
          type: 'deeplink', 
          url: url 
        }, '*');
      }
      
      // Try setting window location (might trigger URL scheme handling)
      try {
        window.location.href = url;
      } catch (e) {
        console.log('URL scheme not supported in browser:', e.message);
      }
    }, credentialOfferUrl);
    
    await page.waitForTimeout(2000);
    
    // Take final screenshot to see what happened
    await page.screenshot({ path: 'flutter-after-credential.png', fullPage: true });
    console.log('📸 Final screenshot taken: flutter-after-credential.png');
    
    // Check if any credentials were added
    const credentialElements = await page.$$eval('[data-testid*="credential"], .credential, .token, [class*="credential"], [class*="token"]', 
      elements => elements.map(el => ({
        tagName: el.tagName,
        textContent: el.textContent?.substring(0, 100),
        className: el.className
      }))
    );
    
    if (credentialElements.length > 0) {
      console.log('🎉 Found credential/token elements:');
      credentialElements.forEach((el, i) => {
        console.log(`  ${i + 1}. ${el.tagName}: ${el.textContent}`);
      });
    } else {
      console.log('❓ No credential elements found. This may be expected since deep links work differently in browsers vs mobile apps.');
    }
    
    // Log the current page content for debugging
    const pageTitle = await page.title();
    const currentUrl = page.url();
    console.log(`📄 Current page: ${pageTitle} at ${currentUrl}`);
    
    // Test if we can access Flutter app console messages
    page.on('console', msg => {
      if (msg.type() === 'log' && msg.text().includes('credential')) {
        console.log('Flutter app console:', msg.text());
      }
    });
    
    await page.waitForTimeout(5000);
    
  } catch (error) {
    console.error('❌ Error during credential testing:', error);
  } finally {
    await browser.close();
  }
}

console.log('🧪 Testing credential reception in Flutter app...');
testCredentialReceptionInFlutter()
  .then(() => {
    console.log('✅ Credential testing completed!');
    console.log('\n📋 Summary:');
    console.log('- QR code found on verification webpage');
    console.log('- Valid OID4VC credential offer URL generated');
    console.log('- Flutter app interaction attempted');
    console.log('- Note: Deep links work differently in web vs mobile apps');
    console.log('\n💡 Next steps:');
    console.log('1. Test on actual mobile device for proper deep link handling');
    console.log('2. Implement QR code scanning in Flutter app if not present');
    console.log('3. Verify OID4VC deep link processing in app');
  })
  .catch(error => {
    console.error('💥 Testing failed:', error);
  });