import { chromium } from 'playwright';
import { Jimp } from 'jimp';
import jsQR from 'jsqr';

(async () => {
  try {
    const browser = await chromium.launch();
    const page = await browser.newPage();

    // console.error('Navigating to Woodgrove verification page...');
    await page.goto('https://woodgroveemployee.azurewebsites.net/verification');

    // Click "I've been verified" to unlock the flow
    // console.error('Clicking "I\'ve been verified"...');
    await page.click('button.btn-link');

    // Wait a bit
    await page.waitForTimeout(2000);

    // Find the "Access personalized portal" button. It's in the 3rd card.
    // We can find it by text.
    const accessButton = page.locator('button.btn--qr', { hasText: 'Access personalized portal' });

    // console.error('Clicking access button...');
    await accessButton.click({ force: true });

    // Wait for the canvas to appear
    const canvasSelector = '.qrcode-container canvas';
    await page.waitForSelector(canvasSelector, { timeout: 15000 });

    // Wait for the canvas to be drawn
    await page.waitForTimeout(3000);

    // Get the data URL from the canvas
    const dataUrl = await page.$eval(canvasSelector, (canvas) => canvas.toDataURL());

    const buffer = Buffer.from(dataUrl.replace(/^data:image\/\w+;base64,/, ""), 'base64');
    const image = await Jimp.read(buffer);

    // Debug: Save the image
    await image.write('debug_qr.png');
    console.error(`Image dimensions: ${image.bitmap.width}x${image.bitmap.height}`);

    const code = jsQR(image.bitmap.data, image.bitmap.width, image.bitmap.height);

    if (code) {
      console.log(code.data);
    } else {
      console.error('Failed to decode QR code');
      process.exit(1);
    }

    await browser.close();
  } catch (error) {
    console.error('Error:', error);
    process.exit(1);
  }
})();
