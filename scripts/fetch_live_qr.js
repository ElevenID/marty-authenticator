import { chromium } from 'playwright';
import { Jimp } from 'jimp';
import jsQR from 'jsqr';

// Script to fetch a live QR code (credential offer) from the demo website.
// Usage: node scripts/fetch_live_qr.js
// Output: The openid-credential-offer URL string.

async function fetchQRCode() {
  const browser = await chromium.launch({ headless: true });
  const context = await browser.newContext();

  try {
    const page = await context.newPage();
    await page.goto('https://trueidentityinc.azurewebsites.net/verify-credential');

    await page.waitForLoadState('networkidle');
    await page.waitForTimeout(5000); // Wait extra time for canvas rendering

    // Take a screenshot
    const buffer = await page.screenshot({ fullPage: true });

    // Decode QR code
    const image = await Jimp.read(buffer);
    const code = jsQR(image.bitmap.data, image.bitmap.width, image.bitmap.height);

    if (code) {
      console.log(code.data);
      process.exit(0);
    } else {
      console.error('Error: No QR code found in the screenshot.');
      process.exit(1);
    }

  } catch (e) {
    console.error('Error: Exception occurred while fetching QR code:', e);
    process.exit(1);
  } finally {
    await browser.close();
  }
}

fetchQRCode();
