import { chromium } from 'playwright';

(async () => {
  const browser = await chromium.launch();
  const page = await browser.newPage();

  console.log('Navigating to Woodgrove verification page...');
  await page.goto('https://woodgroveemployee.azurewebsites.net/verification');

  console.log('Waiting for QR code...');
  // Wait for an image that looks like a QR code.
  // Usually these have alt text like "QR Code" or are in a specific container.
  // Let's dump the HTML to see what we have after load.

  // Wait a bit for socket to connect and render
  await page.waitForTimeout(5000);

  const content = await page.content();
  console.log(content);

  await browser.close();
})();
