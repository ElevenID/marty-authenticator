import { chromium } from 'playwright';

async function testAuthenticatorCredentialFlow() {
  const browser = await chromium.launch({ headless: false });
  const context = await browser.newContext();
  
  try {
    console.log('🚀 Starting OID4VC Credential Test with privacyIDEA Authenticator...\n');
    
    // Step 1: First, let's see what's on the credential page to understand the QR code
    console.log('📋 Step 1: Checking the credential verification page...');
    const credentialPage = await context.newPage();
    await credentialPage.goto('https://trueidentityinc.azurewebsites.net/verify-credential');
    await credentialPage.waitForLoadState('networkidle');
    
    // Take screenshot and examine the page
    await credentialPage.screenshot({ path: 'credential-page-detailed.png', fullPage: true });
    console.log('📸 Screenshot saved: credential-page-detailed.png');
    
    // Extract any available credential information
    const pageInfo = await credentialPage.evaluate(() => {
      const info = {
        title: document.title,
        qrElements: [],
        links: [],
        scripts: [],
        forms: []
      };
      
      // Look for QR code elements
      const canvases = document.querySelectorAll('canvas');
      const qrImages = document.querySelectorAll('img[src*="qr"], img[alt*="qr"], img[alt*="QR"]');
      const qrDivs = document.querySelectorAll('[class*="qr"], [id*="qr"], [data-qr]');
      
      info.qrElements = [
        ...Array.from(canvases).map(el => ({ type: 'canvas', id: el.id, class: el.className })),
        ...Array.from(qrImages).map(el => ({ type: 'img', src: el.src, alt: el.alt })),
        ...Array.from(qrDivs).map(el => ({ type: 'div', id: el.id, class: el.className, text: el.textContent?.substring(0, 100) }))
      ];
      
      // Look for credential offer links
      const allLinks = document.querySelectorAll('a[href*="credential"], a[href*="openid"]');
      info.links = Array.from(allLinks).map(el => ({ href: el.href, text: el.textContent?.substring(0, 50) }));
      
      // Check for JavaScript that might contain credential info
      const scripts = document.querySelectorAll('script:not([src])');
      for (const script of scripts) {
        const content = script.textContent || '';
        if (content.includes('credential') || content.includes('openid') || content.includes('qr')) {
          info.scripts.push(content.substring(0, 200));
        }
      }
      
      // Look for forms that might generate credentials
      const forms = document.querySelectorAll('form');
      info.forms = Array.from(forms).map(form => ({
        action: form.action,
        method: form.method,
        inputs: Array.from(form.querySelectorAll('input, button')).map(input => ({
          type: input.type,
          name: input.name,
          value: input.value,
          text: input.textContent?.substring(0, 30)
        }))
      }));
      
      return info;
    });
    
    console.log('🔍 Page Analysis:');
    console.log(`   Title: ${pageInfo.title}`);
    console.log(`   QR Elements: ${pageInfo.qrElements.length}`);
    console.log(`   Credential Links: ${pageInfo.links.length}`);
    console.log(`   Forms: ${pageInfo.forms.length}`);
    
    if (pageInfo.qrElements.length > 0) {
      console.log('📱 Found QR elements:');
      pageInfo.qrElements.forEach((el, i) => {
        console.log(`   ${i + 1}. ${el.type}: ${el.id || el.class || el.src}`);
      });
    }
    
    // Step 2: Open the privacyIDEA authenticator app
    console.log('\n📱 Step 2: Opening privacyIDEA Authenticator app...');
    const authenticatorPage = await context.newPage();
    await authenticatorPage.goto('http://localhost:8080');
    await authenticatorPage.waitForLoadState('networkidle');
    
    // Wait a bit for the app to fully initialize
    await authenticatorPage.waitForTimeout(3000);
    
    // Take screenshot of initial app state
    await authenticatorPage.screenshot({ path: 'authenticator-initial.png', fullPage: true });
    console.log('📸 Authenticator app screenshot: authenticator-initial.png');
    
    // Analyze the app interface
    const appInterface = await authenticatorPage.evaluate(() => {
      const appUI = {
        buttons: [],
        inputs: [],
        menuItems: [],
        tokens: []
      };
      
      // Find buttons (especially add/import/scan buttons)
      const buttons = document.querySelectorAll('button, [role="button"], .btn');
      appUI.buttons = Array.from(buttons).map(btn => ({
        text: btn.textContent?.trim().substring(0, 30) || '',
        class: btn.className,
        id: btn.id,
        clickable: !btn.disabled
      })).filter(btn => btn.text.length > 0);
      
      // Find input fields
      const inputs = document.querySelectorAll('input, textarea');
      appUI.inputs = Array.from(inputs).map(input => ({
        type: input.type,
        placeholder: input.placeholder,
        name: input.name,
        id: input.id
      }));
      
      // Look for menu items or navigation
      const menuItems = document.querySelectorAll('[role="menuitem"], .menu-item, nav a, .navigation a');
      appUI.menuItems = Array.from(menuItems).map(item => ({
        text: item.textContent?.trim().substring(0, 30) || '',
        href: item.href
      })).filter(item => item.text.length > 0);
      
      // Check for existing tokens
      const tokenElements = document.querySelectorAll('.token, [data-testid*="token"], .credential, [class*="card"]');
      appUI.tokens = Array.from(tokenElements).map(token => ({
        text: token.textContent?.trim().substring(0, 50) || '',
        class: token.className
      }));
      
      return appUI;
    });
    
    console.log('🔧 App Interface Analysis:');
    console.log(`   Buttons: ${appInterface.buttons.length}`);
    console.log(`   Inputs: ${appInterface.inputs.length}`);
    console.log(`   Menu Items: ${appInterface.menuItems.length}`);
    console.log(`   Existing Tokens: ${appInterface.tokens.length}`);
    
    if (appInterface.buttons.length > 0) {
      console.log('🔲 Available buttons:');
      appInterface.buttons.slice(0, 5).forEach((btn, i) => {
        console.log(`   ${i + 1}. "${btn.text}" (${btn.clickable ? 'clickable' : 'disabled'})`);
      });
    }
    
    // Step 3: Test different methods to add a credential
    console.log('\n🧪 Step 3: Testing credential import methods...');
    
    // Method 1: Look for add/import buttons
    const addButton = await authenticatorPage.$('button:has-text("Add"), button:has-text("Import"), button:has-text("+"), [aria-label*="Add"], [aria-label*="Import"]');
    
    if (addButton) {
      console.log('✅ Found add/import button, testing...');
      await addButton.click();
      await authenticatorPage.waitForTimeout(2000);
      
      // Take screenshot after clicking add
      await authenticatorPage.screenshot({ path: 'authenticator-after-add-click.png', fullPage: true });
      
      // Check what appeared
      const afterAddClick = await authenticatorPage.evaluate(() => {
        return {
          modals: document.querySelectorAll('.modal, .dialog, [role="dialog"]').length,
          newInputs: document.querySelectorAll('input[type="url"], input[placeholder*="URL"], textarea').length,
          newButtons: Array.from(document.querySelectorAll('button')).map(btn => btn.textContent?.trim()).filter(text => text && text.length > 0)
        };
      });
      
      console.log(`   Modals opened: ${afterAddClick.modals}`);
      console.log(`   New inputs: ${afterAddClick.newInputs}`);
      
      // If there's a URL input, try entering a credential offer
      if (afterAddClick.newInputs > 0) {
        const urlInput = await authenticatorPage.$('input[type="url"], input[placeholder*="URL"], input[placeholder*="Link"], textarea');
        if (urlInput) {
          console.log('📝 Found URL input, testing with sample credential offer...');
          
          // Use a sample OID4VC credential offer
          const sampleCredentialOffer = "openid-credential-offer://?credential_offer=eyJjcmVkZW50aWFsX2lzc3VlciI6Imh0dHBzOi8vdHJ1ZWlkZW50aXR5aW5jLmF6dXJld2Vic2l0ZXMubmV0IiwiY3JlZGVudGlhbHMiOlt7ImZvcm1hdCI6Imp3dF92Y19qc29uIiwidHlwZXMiOlsiVmVyaWZpYWJsZUNyZWRlbnRpYWwiLCJJZGVudGl0eUNyZWRlbnRpYWwiXSwiY3JlZGVudGlhbFN1YmplY3QiOnsiaWQiOiJkaWQ6a2V5OnRlc3Qtc3ViamVjdCIsIm5hbWUiOiJKb2huIERvZSIsImVtYWlsIjoiam9obi5kb2VAZXhhbXBsZS5jb20iLCJ2ZXJpZmllZCI6dHJ1ZX19XSwiZ3JhbnRzIjp7InVybjppZXRmOnBhcmFtczpvYXV0aDpncmFudC10eXBlOnByZS1hdXRob3JpemVkX2NvZGUiOnsicHJlLWF1dGhvcml6ZWRfY29kZSI6InRlc3QtcHJlLWF1dGgtY29kZS0xMjMiLCJ1c2VyX3Bpbl9yZXF1aXJlZCI6ZmFsc2V9fX0=";
          
          await urlInput.fill(sampleCredentialOffer);
          await authenticatorPage.waitForTimeout(1000);
          
          // Look for submit button
          const submitButton = await authenticatorPage.$('button:has-text("Submit"), button:has-text("Add"), button:has-text("Import"), button:has-text("OK"), button:has-text("Continue")');
          if (submitButton) {
            console.log('⚡ Clicking submit button...');
            await submitButton.click();
            await authenticatorPage.waitForTimeout(3000);
          }
        }
      }
    }
    
    // Method 2: Try deep link simulation
    console.log('\n🔗 Method 2: Testing deep link simulation...');
    await authenticatorPage.evaluate(() => {
      const credentialOffer = "openid-credential-offer://?credential_offer=eyJjcmVkZW50aWFsX2lzc3VlciI6Imh0dHBzOi8vdHJ1ZWlkZW50aXR5aW5jLmF6dXJld2Vic2l0ZXMubmV0IiwiY3JlZGVudGlhbHMiOlt7ImZvcm1hdCI6Imp3dF92Y19qc29uIiwidHlwZXMiOlsiVmVyaWZpYWJsZUNyZWRlbnRpYWwiLCJJZGVudGl0eUNyZWRlbnRpYWwiXSwiY3JlZGVudGlhbFN1YmplY3QiOnsiaWQiOiJkaWQ6a2V5OnRlc3Qtc3ViamVjdCIsIm5hbWUiOiJKb2huIERvZSIsImVtYWlsIjoiam9obi5kb2VAZXhhbXBsZS5jb20iLCJ2ZXJpZmllZCI6dHJ1ZX19XSwiZ3JhbnRzIjp7InVybjppZXRmOnBhcmFtczpvYXV0aDpncmFudC10eXBlOnByZS1hdXRob3JpemVkX2NvZGUiOnsicHJlLWF1dGhvcml6ZWRfY29kZSI6InRlc3QtcHJlLWF1dGgtY29kZS0xMjMiLCJ1c2VyX3Bpbl9yZXF1aXJlZCI6ZmFsc2V9fX0=";
      
      // Try various methods to trigger deep link handling
      console.log('Simulating deep link:', credentialOffer);
      
      // Method A: Custom event
      window.dispatchEvent(new CustomEvent('deeplink', { detail: { url: credentialOffer } }));
      
      // Method B: Direct Flutter channel (if available)
      if (window.flutter_inappwebview) {
        window.flutter_inappwebview.callHandler('handleDeepLink', credentialOffer);
      }
      
      // Method C: Storage for app to pick up
      sessionStorage.setItem('pending_credential_offer', credentialOffer);
      localStorage.setItem('pending_credential_offer', credentialOffer);
      
      // Method D: Hash change (some apps listen for this)
      window.location.hash = '#credential-offer=' + encodeURIComponent(credentialOffer);
      
      // Method E: Try to trigger any registered link handlers
      document.dispatchEvent(new Event('DOMContentLoaded'));
    });
    
    await authenticatorPage.waitForTimeout(3000);
    
    // Step 4: Check final app state
    console.log('\n📊 Step 4: Checking final app state...');
    
    // Take final screenshot
    await authenticatorPage.screenshot({ path: 'authenticator-final.png', fullPage: true });
    
    // Check for any new tokens or credentials
    const finalState = await authenticatorPage.evaluate(() => {
      const state = {
        tokens: [],
        credentials: [],
        errors: [],
        successMessages: [],
        modalContents: []
      };
      
      // Look for token elements
      const tokenElements = document.querySelectorAll('.token, [data-testid*="token"], [class*="token"]');
      state.tokens = Array.from(tokenElements).map(el => ({
        text: el.textContent?.trim().substring(0, 100) || '',
        class: el.className,
        visible: !el.hidden && el.style.display !== 'none'
      }));
      
      // Look for credential elements
      const credentialElements = document.querySelectorAll('.credential, [data-testid*="credential"], [class*="credential"]');
      state.credentials = Array.from(credentialElements).map(el => ({
        text: el.textContent?.trim().substring(0, 100) || '',
        class: el.className,
        visible: !el.hidden && el.style.display !== 'none'
      }));
      
      // Look for error messages
      const errorElements = document.querySelectorAll('.error, .alert-error, [class*="error"]');
      state.errors = Array.from(errorElements).map(el => el.textContent?.trim() || '').filter(text => text.length > 0);
      
      // Look for success messages
      const successElements = document.querySelectorAll('.success, .alert-success, [class*="success"]');
      state.successMessages = Array.from(successElements).map(el => el.textContent?.trim() || '').filter(text => text.length > 0);
      
      // Check modal contents
      const modals = document.querySelectorAll('.modal, .dialog, [role="dialog"]');
      state.modalContents = Array.from(modals).map(modal => modal.textContent?.trim().substring(0, 200) || '');
      
      return state;
    });
    
    console.log('📈 Final Results:');
    console.log(`   Tokens found: ${finalState.tokens.length}`);
    console.log(`   Credentials found: ${finalState.credentials.length}`);
    console.log(`   Error messages: ${finalState.errors.length}`);
    console.log(`   Success messages: ${finalState.successMessages.length}`);
    console.log(`   Active modals: ${finalState.modalContents.length}`);
    
    if (finalState.tokens.length > 0) {
      console.log('🎉 Tokens detected:');
      finalState.tokens.forEach((token, i) => {
        if (token.visible && token.text.length > 5) {
          console.log(`   ${i + 1}. ${token.text}`);
        }
      });
    }
    
    if (finalState.credentials.length > 0) {
      console.log('🏆 Credentials detected:');
      finalState.credentials.forEach((cred, i) => {
        if (cred.visible && cred.text.length > 5) {
          console.log(`   ${i + 1}. ${cred.text}`);
        }
      });
    }
    
    if (finalState.errors.length > 0) {
      console.log('❌ Errors detected:');
      finalState.errors.forEach((error, i) => {
        console.log(`   ${i + 1}. ${error}`);
      });
    }
    
    if (finalState.successMessages.length > 0) {
      console.log('✅ Success messages:');
      finalState.successMessages.forEach((msg, i) => {
        console.log(`   ${i + 1}. ${msg}`);
      });
    }
    
    // Check console for any relevant messages
    const consoleLogs = [];
    authenticatorPage.on('console', msg => {
      const text = msg.text();
      if (text.toLowerCase().includes('credential') || text.toLowerCase().includes('token') || text.toLowerCase().includes('oid4vc')) {
        consoleLogs.push(text);
      }
    });
    
    if (consoleLogs.length > 0) {
      console.log('💬 Console messages (credential-related):');
      consoleLogs.forEach((log, i) => {
        console.log(`   ${i + 1}. ${log}`);
      });
    }
    
    await browser.close();
    
    // Final assessment
    console.log('\n🎯 Test Assessment:');
    const hasNewContent = finalState.tokens.length > 0 || finalState.credentials.length > 0 || finalState.successMessages.length > 0;
    const hasErrors = finalState.errors.length > 0;
    
    if (hasNewContent && !hasErrors) {
      console.log('✅ SUCCESS: The authenticator app appears to have processed the credential successfully!');
    } else if (hasErrors) {
      console.log('⚠️ PARTIAL: The app attempted to process the credential but encountered errors.');
    } else {
      console.log('ℹ️ UNCLEAR: No obvious signs of credential processing. This could mean:');
      console.log('   - The web version doesn\'t show the full mobile UI');
      console.log('   - The credential was processed but not visually displayed');
      console.log('   - The deep link handling requires a different approach');
    }
    
    return {
      success: hasNewContent && !hasErrors,
      tokensFound: finalState.tokens.length,
      credentialsFound: finalState.credentials.length,
      errorsFound: finalState.errors.length,
      successMessages: finalState.successMessages.length
    };
    
  } catch (error) {
    console.error('❌ Test failed:', error);
    await browser.close();
    return null;
  }
}

// Run the test
testAuthenticatorCredentialFlow().catch(console.error);