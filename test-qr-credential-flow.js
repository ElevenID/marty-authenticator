import { chromium } from 'playwright';
import fs from 'fs';

async function extractQRCodeFromWebpage() {
  const browser = await chromium.launch({ headless: false });
  const context = await browser.newContext();
  
  try {
    // Open the credential verification page
    console.log('🌐 Opening True Identity credential verification page...');
    const page = await context.newPage();
    await page.goto('https://trueidentityinc.azurewebsites.net/verify-credential');
    await page.waitForLoadState('networkidle');
    
    // Take screenshot to see the page
    await page.screenshot({ path: 'trueidentity-page.png', fullPage: true });
    console.log('📸 Screenshot saved: trueidentity-page.png');
    
    // Look for QR codes - first check if there's a canvas element (common for QR codes)
    const qrCanvas = await page.$('canvas');
    let qrCodeContent = null;
    
    if (qrCanvas) {
      console.log('🎯 Found QR code canvas, attempting to extract data...');
      
      // Try to extract QR code content using JavaScript
      qrCodeContent = await page.evaluate(() => {
        // Look for any data attributes or JavaScript variables that might contain the QR content
        const canvas = document.querySelector('canvas');
        if (canvas) {
          // Check for data attributes
          const dataUrl = canvas.getAttribute('data-url') || canvas.getAttribute('data-qr');
          if (dataUrl) return dataUrl;
          
          // Check for nearby script tags or data elements
          const scripts = document.querySelectorAll('script');
          for (const script of scripts) {
            const content = script.textContent || script.innerHTML;
            if (content.includes('openid-credential-offer') || content.includes('credential_offer')) {
              const match = content.match(/openid-credential-offer:\/\/[^"'\s]+/);
              if (match) return match[0];
            }
          }
          
          // Look for hidden inputs or data elements
          const dataElements = document.querySelectorAll('[data-qr], [data-url], input[type="hidden"]');
          for (const el of dataElements) {
            const value = el.value || el.getAttribute('data-qr') || el.getAttribute('data-url');
            if (value && value.includes('openid-credential-offer')) {
              return value;
            }
          }
        }
        return null;
      });
    }
    
    // If we didn't find QR content in canvas, look in page source
    if (!qrCodeContent) {
      console.log('🔍 Searching page source for credential offers...');
      const pageContent = await page.content();
      
      // Look for credential offer URLs
      const credentialOfferMatch = pageContent.match(/openid-credential-offer:\/\/[^"'\s<>]+/);
      if (credentialOfferMatch) {
        qrCodeContent = credentialOfferMatch[0];
      } else {
        // Look for base64 encoded credential offers
        const base64Match = pageContent.match(/credential_offer=([A-Za-z0-9+/=]+)/);
        if (base64Match) {
          qrCodeContent = `openid-credential-offer://?credential_offer=${base64Match[1]}`;
        }
      }
    }
    
    await browser.close();
    return qrCodeContent;
    
  } catch (error) {
    console.error('❌ Error extracting QR code:', error);
    await browser.close();
    return null;
  }
}

async function testAuthenticatorCredentialAcceptance(credentialOfferUrl) {
  console.log('📱 Testing authenticator app credential acceptance...');
  
  const browser = await chromium.launch({ headless: false });
  const context = await browser.newContext();
  
  try {
    // Open the Flutter authenticator app
    const page = await context.newPage();
    await page.goto('http://localhost:8080');
    await page.waitForLoadState('networkidle');
    
    console.log('🔍 Looking for credential import functionality...');
    
    // Take screenshot of initial app state
    await page.screenshot({ path: 'app-before-credential.png', fullPage: true });
    
    // Look for ways to add/import credentials
    const importMethods = await page.evaluate(() => {
      const methods = [];
      
      // Look for QR scan buttons
      const scanButtons = document.querySelectorAll('button, [role="button"]');
      for (const btn of scanButtons) {
        const text = (btn.textContent || btn.getAttribute('aria-label') || '').toLowerCase();
        if (text.includes('scan') || text.includes('qr') || text.includes('camera')) {
          methods.push({ type: 'scan', element: btn.tagName, text: btn.textContent });
        }
      }
      
      // Look for add/import buttons
      for (const btn of scanButtons) {
        const text = (btn.textContent || btn.getAttribute('aria-label') || '').toLowerCase();
        if (text.includes('add') || text.includes('import') || text.includes('+')) {
          methods.push({ type: 'add', element: btn.tagName, text: btn.textContent });
        }
      }
      
      // Look for input fields
      const inputs = document.querySelectorAll('input, textarea');
      for (const input of inputs) {
        const placeholder = (input.placeholder || '').toLowerCase();
        if (placeholder.includes('url') || placeholder.includes('link') || placeholder.includes('credential')) {
          methods.push({ type: 'input', element: input.tagName, placeholder: input.placeholder });
        }
      }
      
      return methods;
    });
    
    console.log('🛠️ Available import methods:', importMethods);
    
    // Try to trigger credential import
    if (credentialOfferUrl) {
      console.log('📋 Credential offer URL to test:', credentialOfferUrl.substring(0, 100) + '...');
      
      // Method 1: Try clicking add/import buttons
      const addButton = await page.$('button:has-text("Add"), button:has-text("Import"), button:has-text("+")');
      if (addButton) {
        console.log('➕ Clicking add/import button...');
        await addButton.click();
        await page.waitForTimeout(2000);
        
        // Look for input fields that appeared
        const urlInput = await page.$('input[type="url"], input[placeholder*="URL"], input[placeholder*="Link"], textarea');
        if (urlInput) {
          console.log('📝 Found input field, entering credential offer URL...');
          await urlInput.fill(credentialOfferUrl);
          await page.waitForTimeout(1000);
          
          // Look for submit/confirm button
          const submitBtn = await page.$('button:has-text("Submit"), button:has-text("Add"), button:has-text("Import"), button:has-text("Continue")');
          if (submitBtn) {
            console.log('✅ Clicking submit button...');
            await submitBtn.click();
            await page.waitForTimeout(3000);
          }
        }
      }
      
      // Method 2: Try direct JavaScript injection (simulate deep link handling)
      console.log('🔗 Attempting to trigger deep link processing...');
      await page.evaluate((url) => {
        // Try to trigger the app's deep link handler
        if (window.flutter_inappwebview && window.flutter_inappwebview.callHandler) {
          window.flutter_inappwebview.callHandler('handleDeepLink', url);
        }
        
        // Try triggering custom events
        window.dispatchEvent(new CustomEvent('deeplink', { detail: { url: url } }));
        window.dispatchEvent(new CustomEvent('credential-offer', { detail: { offer: url } }));
        
        // Store in sessionStorage for the app to pick up
        sessionStorage.setItem('pending_credential_offer', url);
        localStorage.setItem('pending_credential_offer', url);
        
      }, credentialOfferUrl);
      
      await page.waitForTimeout(2000);
    }
    
    // Check for credential storage
    console.log('🏪 Checking for stored credentials...');
    
    const credentialElements = await page.evaluate(() => {
      const credentials = [];
      
      // Look for credential/token displays
      const possibleCredentialElements = document.querySelectorAll(
        '.credential, .token, .card, [data-testid*="credential"], [data-testid*="token"], ' +
        '[class*="credential"], [class*="token"], [class*="card"]'
      );
      
      for (const el of possibleCredentialElements) {
        credentials.push({
          tagName: el.tagName,
          className: el.className,
          textContent: (el.textContent || '').substring(0, 200),
          hasCredentialData: (el.textContent || '').toLowerCase().includes('john doe') || 
                           (el.textContent || '').toLowerCase().includes('identity') ||
                           (el.textContent || '').toLowerCase().includes('verified')
        });
      }
      
      return credentials;
    });
    
    // Take final screenshot
    await page.screenshot({ path: 'app-after-credential.png', fullPage: true });
    console.log('📸 Final screenshot saved: app-after-credential.png');
    
    // Check console messages for credential processing
    const consoleMessages = [];
    page.on('console', msg => {
      if (msg.text().toLowerCase().includes('credential') || msg.text().toLowerCase().includes('token')) {
        consoleMessages.push(msg.text());
      }
    });
    
    await page.waitForTimeout(2000);
    
    console.log('📊 Test Results:');
    console.log(`   Found ${credentialElements.length} potential credential elements`);
    console.log(`   Console messages: ${consoleMessages.length}`);
    
    if (credentialElements.length > 0) {
      console.log('🎉 Credential elements found:');
      credentialElements.forEach((cred, i) => {
        if (cred.hasCredentialData || cred.textContent.length > 10) {
          console.log(`   ${i + 1}. ${cred.tagName}.${cred.className}: ${cred.textContent.substring(0, 100)}`);
        }
      });
    }
    
    if (consoleMessages.length > 0) {
      console.log('💬 Relevant console messages:');
      consoleMessages.forEach(msg => console.log(`   - ${msg}`));
    }
    
    await browser.close();
    
    return {
      credentialElements: credentialElements.length,
      hasCredentialData: credentialElements.some(c => c.hasCredentialData),
      consoleMessages: consoleMessages.length
    };
    
  } catch (error) {
    console.error('❌ Error testing credential acceptance:', error);
    await browser.close();
    return null;
  }
}

async function main() {
  console.log('🚀 Starting QR Code Credential Test...\n');
  
  // Step 1: Extract QR code from True Identity webpage
  console.log('Step 1: Extracting QR code from True Identity webpage');
  const qrCodeContent = await extractQRCodeFromWebpage();
  
  if (qrCodeContent) {
    console.log('✅ Successfully extracted credential offer URL from QR code!');
    console.log(`🔗 Credential offer: ${qrCodeContent.substring(0, 100)}...`);
    
    // Step 2: Test authenticator app credential acceptance
    console.log('\nStep 2: Testing authenticator app credential acceptance');
    const testResults = await testAuthenticatorCredentialAcceptance(qrCodeContent);
    
    if (testResults) {
      console.log('\n📋 Final Test Summary:');
      console.log(`✅ QR Code extracted: Yes`);
      console.log(`📱 App tested: Yes`);
      console.log(`🏪 Credential elements found: ${testResults.credentialElements}`);
      console.log(`📊 Contains credential data: ${testResults.hasCredentialData ? 'Yes' : 'No'}`);
      console.log(`💬 Console activity: ${testResults.consoleMessages > 0 ? 'Yes' : 'No'}`);
      
      if (testResults.hasCredentialData) {
        console.log('🎉 SUCCESS: The app appears to have processed the credential!');
      } else {
        console.log('ℹ️ NOTE: Credential may have been processed but not visibly displayed yet.');
        console.log('   This is common for web versions of mobile apps.');
      }
    }
    
  } else {
    console.log('❌ Could not extract credential offer from QR code');
    console.log('ℹ️ This might be because:');
    console.log('   - The QR code is generated dynamically by JavaScript');
    console.log('   - The content is stored server-side and not in the page source');
    console.log('   - The QR code requires user interaction to generate');
    
    console.log('\n🔄 Falling back to testing with a sample credential offer...');
    const sampleOffer = "openid-credential-offer://?credential_offer=eyJjcmVkZW50aWFsX2lzc3VlciI6Imh0dHBzOi8vdHJ1ZWlkZW50aXR5aW5jLmF6dXJld2Vic2l0ZXMubmV0IiwiY3JlZGVudGlhbHMiOlt7ImZvcm1hdCI6Imp3dF92Y19qc29uIiwidHlwZXMiOlsiVmVyaWZpYWJsZUNyZWRlbnRpYWwiLCJJZGVudGl0eUNyZWRlbnRpYWwiXSwiY3JlZGVudGlhbFN1YmplY3QiOnsiaWQiOiJkaWQ6a2V5OnRlc3Qtc3ViamVjdCIsIm5hbWUiOiJKb2huIERvZSIsImVtYWlsIjoiam9obi5kb2VAZXhhbXBsZS5jb20iLCJ2ZXJpZmllZCI6dHJ1ZX19XSwiZ3JhbnRzIjp7InVybjppZXRmOnBhcmFtczpvYXV0aDpncmFudC10eXBlOnByZS1hdXRob3JpemVkX2NvZGUiOnsicHJlLWF1dGhvcml6ZWRfY29kZSI6InRlc3QtcHJlLWF1dGgtY29kZS0xMjMiLCJ1c2VyX3Bpbl9yZXF1aXJlZCI6ZmFsc2V9fX0=";
    
    await testAuthenticatorCredentialAcceptance(sampleOffer);
  }
  
  console.log('\n🏁 Testing completed!');
}

main().catch(console.error);