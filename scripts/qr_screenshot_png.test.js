import assert from 'node:assert/strict';
import test from 'node:test';
import { PNG } from 'pngjs';
import { decodeQrScreenshotPng } from './qr_screenshot_png.js';

function png() {
  return PNG.sync.write({ width: 2, height: 1, data: Buffer.from([1, 2, 3, 255, 10, 20, 30, 0]) });
}

function crc32(bytes) {
  let crc = 0xffffffff;
  for (const byte of bytes) {
    crc ^= byte;
    for (let bit = 0; bit < 8; bit++) crc = (crc >>> 1) ^ ((crc & 1) ? 0xedb88320 : 0);
  }
  return (crc ^ 0xffffffff) >>> 0;
}

test('PNG screenshot decoding preserves dimensions, RGBA bytes and transparency for jsQR', () => {
  const image = decodeQrScreenshotPng(png());
  assert.equal(image.width, 2);
  assert.equal(image.height, 1);
  assert.ok(image.data instanceof Uint8ClampedArray);
  assert.deepEqual([...image.data], [1, 2, 3, 255, 10, 20, 30, 0]);
});

test('malformed and corrupted PNG input never produces pixels', () => {
  const corrupted = png();
  corrupted[29] ^= 1; // IHDR CRC, not screenshot contents.
  for (const input of [Buffer.alloc(0), Buffer.from('not an image'), png().subarray(0, 32), corrupted]) {
    assert.throws(() => decodeQrScreenshotPng(input), { code: 'QR_IMAGE_FORMAT' });
  }
});

test('untrusted dimensions are refused before PNG decoding or pixel allocation', () => {
  for (const [width, height] of [[0, 1], [1, 0], [16385, 1], [1, 16385], [8192, 8192], [0xffffffff, 0xffffffff]]) {
    const input = png();
    input.writeUInt32BE(width, 16);
    input.writeUInt32BE(height, 20);
    // CRC is deliberately unchanged: format/decoder rejection would fail this
    // assertion instead of proving the resource admission boundary ran first.
    assert.throws(() => decodeQrScreenshotPng(input), { code: 'QR_IMAGE_LIMIT' });
  }
});

test('valid-CRC repeated headers and interlace cannot bypass predecode admission', () => {
  const original = png();
  const header = Buffer.from(original.subarray(8, 33));
  header.writeUInt32BE(0xffffffff, 8);
  header.writeUInt32BE(crc32(header.subarray(4, 21)), 21);
  const repeated = Buffer.concat([original.subarray(0, 33), header, original.subarray(33)]);
  const interlaced = Buffer.from(original);
  interlaced[28] = 1;
  interlaced.writeUInt32BE(crc32(interlaced.subarray(12, 29)), 29);
  const oversizedChunk = Buffer.from(original);
  oversizedChunk.writeUInt32BE(0xffffffff, 33);
  for (const input of [repeated, interlaced, oversizedChunk, Buffer.concat([original, Buffer.from([0])])]) {
    assert.throws(() => decodeQrScreenshotPng(input), { code: 'QR_IMAGE_PROFILE' });
  }
});
