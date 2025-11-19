import { chromium } from 'playwright';

async function main() {
  const browser = await chromium.launch({ headless: false });
  const context = await browser.newContext();
  
  try {
    console.log('🚀 Testing credential flow between True Identity and privacyIDEA Authenticator\n');
    
    // Step 1: Check the True Identity credential page
    console.log('📋 Step 1: Examining True Identity credential verification page');
    const credentialPage = await context.newPage();
    await credentialPage.goto('https://trueidentityinc.azurewebsites.net/verify-credential');
    
    console.log('⏳ Waiting for page to load...');
    await credentialPage.waitForLoadState('networkidle');
    
    // Take screenshot
    await credentialPage.screenshot({ path: 'true-identity-page.png', fullPage: true });
    console.log('📸 Screenshot saved: true-identity-page.png');
    
    // Look for QR codes or credential offers
    const pageAnalysis = await credentialPage.evaluate(() => {
      const result = {
        title: document.title,
        hasCanvas: document.querySelector('canvas') !== null,
        hasQRElements: document.querySelectorAll('[class*="qr"], [id*="qr"]').length,
        credentialLinks: [],
        formActions: []
      };
      
      // Look for any credential-related links
      const links = document.querySelectorAll('a');
      for (const link of links) {
        if (link.href.includes('credential') || link.href.includes('openid')) {
          result.credentialLinks.push(link.href);
        }
      }
      
      // Look for forms that might generate credentials
      const forms = document.querySelectorAll('form');
      for (const form of forms) {
        result.formActions.push(form.action || 'No action');
      }
      
      return result;
    });
    
    console.log(`   Page title: ${pageAnalysis.title}`);
    console.log(`   Has canvas (QR): ${pageAnalysis.hasCanvas}`);
    console.log(`   QR elements: ${pageAnalysis.hasQRElements}`);
    console.log(`   Credential links: ${pageAnalysis.credentialLinks.length}`);
    console.log(`   Forms: ${pageAnalysis.formActions.length}`);
    
    if (pageAnalysis.credentialLinks.length > 0) {
      console.log('🔗 Found credential links:');
      pageAnalysis.credentialLinks.forEach(link => console.log(`   - ${link}`));
    }
    
    // Step 2: Wait for Flutter app and test it
    console.log('\n📱 Step 2: Testing privacyIDEA Authenticator');
    
    // Try multiple possible ports for the Flutter app
    const possiblePorts = [3000, 8080, 8081, 3001];
    let authenticatorPage = null;
    let appUrl = null;
    
    for (const port of possiblePorts) {
      try {
        console.log(`   Trying port ${port}...`);
        const testPage = await context.newPage();
        await testPage.goto(`http://localhost:${port}`, { timeout: 5000 });
        
        // Check if this looks like the Flutter app
        const isFlutterApp = await testPage.evaluate(() => {
          return document.documentElement.innerHTML.includes('flutter') || 
                 document.querySelector('flt-glass-pane') !== null ||
                 window.flutterWebRenderer !== undefined;
        });
        
        if (isFlutterApp) {
          authenticatorPage = testPage;
          appUrl = `http://localhost:${port}`;
          console.log(`✅ Found Flutter app on port ${port}`);
          break;
        } else {
          await testPage.close();
        }
      } catch (e) {
        // Port not available, try next one
      }
    }
    
    if (!authenticatorPage) {
      console.log('❌ Could not find running Flutter app on any port');
      console.log('ℹ️ Please ensure the app is running with: flutter run -d chrome');
      await browser.close();
      return;
    }
    
    // Wait for the app to fully load
    console.log('⏳ Waiting for app to initialize...');
    await authenticatorPage.waitForLoadState('networkidle');
    await authenticatorPage.waitForTimeout(3000);
    
    // Take screenshot of the app
    await authenticatorPage.screenshot({ path: 'authenticator-app.png', fullPage: true });
    console.log('📸 App screenshot: authenticator-app.png');
    
    // Analyze the app's current state
    const appState = await authenticatorPage.evaluate(() => {
      const state = {
        hasAddButton: false,
        hasImportButton: false,
        hasScanButton: false,
        hasFloatingActionButton: false,
        visibleButtons: [],
        tokenCount: 0,
        isFirstRun: false
      };
      
      // Look for various add/import buttons
      const allButtons = document.querySelectorAll('button, [role="button"]');
      for (const btn of allButtons) {
        const text = (btn.textContent || '').toLowerCase().trim();
        if (text.length > 0) {
          state.visibleButtons.push(text.substring(0, 20));
        }
        
        if (text.includes('add') || text.includes('+')) state.hasAddButton = true;
        if (text.includes('import')) state.hasImportButton = true;
        if (text.includes('scan')) state.hasScanButton = true;
      }
      
      // Look for floating action buttons (common in Flutter)
      const fabElements = document.querySelectorAll('[class*="fab"], [class*="floating"]');
      state.hasFloatingActionButton = fabElements.length > 0;
      
      // Count existing tokens
      const tokenElements = document.querySelectorAll('[class*="token"], [class*="card"], [data-testid*="token"]');
      state.tokenCount = tokenElements.length;
      
      // Check if this looks like a first run screen
      const pageText = document.body.textContent || '';
      state.isFirstRun = pageText.toLowerCase().includes('welcome') || 
                       pageText.toLowerCase().includes('get started') ||
                       pageText.toLowerCase().includes('first time');
      
      return state;
    });
    
    console.log('🔍 App Analysis:');
    console.log(`   Has Add button: ${appState.hasAddButton}`);
    console.log(`   Has Import button: ${appState.hasImportButton}`);
    console.log(`   Has Scan button: ${appState.hasScanButton}`);
    console.log(`   Has FAB: ${appState.hasFloatingActionButton}`);
    console.log(`   Token count: ${appState.tokenCount}`);
    console.log(`   First run: ${appState.isFirstRun}`);
    console.log(`   Visible buttons (${appState.visibleButtons.length}): ${appState.visibleButtons.slice(0, 3).join(', ')}`);
    
    // Step 3: Test credential import workflow
    console.log('\n🧪 Step 3: Testing credential import capabilities');
    
    // Try clicking any add-related buttons
    const addButton = await authenticatorPage.$('button:has-text("Add"), [role="button"]:has-text("Add"), button:has-text("+"), [aria-label*="Add"]');
    
    if (addButton) {
      console.log('🔘 Found add button, testing click...');
      await addButton.click();
      await authenticatorPage.waitForTimeout(2000);
      
      // Check what happened after clicking
      await authenticatorPage.screenshot({ path: 'authenticator-after-add.png', fullPage: true });
      console.log('📸 After add click: authenticator-after-add.png');
      
      const afterAdd = await authenticatorPage.evaluate(() => {
        return {
          hasModal: document.querySelector('[role="dialog"], .modal, .overlay') !== null,
          hasUrlInput: document.querySelector('input[type="url"], input[placeholder*="URL"], input[placeholder*="Link"]') !== null,
          hasTextInput: document.querySelector('textarea, input[type="text"]') !== null,
          newButtons: Array.from(document.querySelectorAll('button')).map(b => b.textContent?.trim()).filter(t => t && t.length > 0 && t.length < 20)
        };
      });
      
      console.log(`   Modal opened: ${afterAdd.hasModal}`);
      console.log(`   URL input available: ${afterAdd.hasUrlInput}`);
      console.log(`   Text input available: ${afterAdd.hasTextInput}`);
      
      // If we found an input, try entering a credential offer
      if (afterAdd.hasUrlInput || afterAdd.hasTextInput) {
        const input = await authenticatorPage.$('input[type="url"], input[placeholder*="URL"], input[placeholder*="Link"], textarea, input[type="text"]');
        
        if (input) {
          console.log('📝 Testing with sample credential offer...');
          const sampleOffer = "openid-credential-offer://?credential_offer=eyJjcmVkZW50aWFsX2lzc3VlciI6Imh0dHBzOi8vdHJ1ZWlkZW50aXR5aW5jLmF6dXJld2Vic2l0ZXMubmV0IiwiY3JlZGVudGlhbHMiOlt7ImZvcm1hdCI6Imp3dF92Y19qc29uIiwidHlwZXMiOlsiVmVyaWZpYWJsZUNyZWRlbnRpYWwiLCJJZGVudGl0eUNyZWRlbnRpYWwiXSwiY3JlZGVudGlhbFN1YmplY3QiOnsiaWQiOiJkaWQ6a2V5OnRlc3Qtc3ViamVjdCIsIm5hbWUiOiJKb2huIERvZSIsImVtYWlsIjoiam9obi5kb2VAZXhhbXBsZS5jb20iLCJ2ZXJpZmllZCI6dHJ1ZX19XSwiZ3JhbnRzIjp7InVybjppZXRmOnBhcmFtczpvYXV0aDpncmFudC10eXBlOnByZS1hdXRob3JpemVkX2NvZGUiOnsicHJlLWF1dGhvcml6ZWRfY29kZSI6InRlc3QtcHJlLWF1dGgtY29kZS0xMjMiLCJ1c2VyX3Bpbl9yZXF1aXJlZCI6ZmFsc2V9fX0=";
          
          await input.fill(sampleOffer);
          await authenticatorPage.waitForTimeout(1000);
          
          // Look for submit/confirm button
          const submitBtn = await authenticatorPage.$('button:has-text("Submit"), button:has-text("Import"), button:has-text("Add"), button:has-text("OK"), button:has-text("Confirm")');
          
          if (submitBtn) {
            console.log('⚡ Submitting credential offer...');
            await submitBtn.click();
            await authenticatorPage.waitForTimeout(3000);
            
            // Take final screenshot
            await authenticatorPage.screenshot({ path: 'authenticator-final.png', fullPage: true });
            console.log('📸 Final state: authenticator-final.png');
          }
        }
      }
    } else {
      console.log('ℹ️ No obvious add button found in current UI');
    }
    
    // Final assessment
    const finalCheck = await authenticatorPage.evaluate(() => {
      const tokens = document.querySelectorAll('[class*="token"], [class*="credential"], [class*="card"]');
      const errors = document.querySelectorAll('[class*="error"], .alert-danger');
      const success = document.querySelectorAll('[class*="success"], .alert-success');
      
      return {
        tokenCount: tokens.length,
        errorCount: errors.length,
        successCount: success.length,
        pageText: (document.body.textContent || '').toLowerCase()
      };
    });
    
    console.log('\n📊 Final Results:');
    console.log(`   Final token count: ${finalCheck.tokenCount}`);
    console.log(`   Error messages: ${finalCheck.errorCount}`);
    console.log(`   Success messages: ${finalCheck.successCount}`);
    
    const hasCredentialText = finalCheck.pageText.includes('john doe') || 
                             finalCheck.pageText.includes('identity') ||
                             finalCheck.pageText.includes('verified');
    
    console.log(`   Contains credential data: ${hasCredentialText}`);
    
    if (finalCheck.tokenCount > appState.tokenCount) {
      console.log('🎉 SUCCESS: New tokens/credentials appear to have been added!');
    } else if (hasCredentialText) {
      console.log('🔄 PARTIAL: Credential data detected but may not be fully processed yet');
    } else {
      console.log('ℹ️ INCONCLUSIVE: No obvious signs of credential processing in web UI');
      console.log('   (This is common - mobile features may not be fully available in web version)');
    }
    
    console.log('\n📸 Screenshots created:');
    console.log('   - true-identity-page.png (credential source)');
    console.log('   - authenticator-app.png (initial app state)');
    console.log('   - authenticator-after-add.png (after clicking add)'); 
    console.log('   - authenticator-final.png (final state)');
    
  } catch (error) {
    console.error('❌ Test failed:', error);
  } finally {
    await browser.close();
  }
}

main().catch(console.error);