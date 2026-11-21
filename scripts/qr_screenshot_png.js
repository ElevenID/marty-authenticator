import { PNG } from 'pngjs';

const MAXIMUM_BYTES = 64 * 1024 * 1024;
const MAXIMUM_PIXELS = 16 * 1024 * 1024;
const MAXIMUM_DIMENSION = 16384;
const SIGNATURE = Buffer.from([137, 80, 78, 71, 13, 10, 26, 10]);

function rejected(code) {
  const error = new Error('QR screenshot PNG is invalid or exceeds the supported size');
  error.code = code;
  return error;
}

// Both callers produce PNG through Playwright screenshot/canvas APIs. Keep the
// existing pngjs decoder used by Jimp, without unrelated image-editing plugins
// or their vulnerable schema dependency. Bound dimensions before decoding.
export function decodeQrScreenshotPng(bytes) {
  if (!Buffer.isBuffer(bytes) || bytes.length < 33 ||
      !bytes.subarray(0, 8).equals(SIGNATURE) ||
      bytes.readUInt32BE(8) !== 13 || bytes.toString('ascii', 12, 16) !== 'IHDR') {
    throw rejected('QR_IMAGE_FORMAT');
  }
  const width = bytes.readUInt32BE(16);
  const height = bytes.readUInt32BE(20);
  if (bytes.length > MAXIMUM_BYTES || width === 0 || height === 0 ||
      width > MAXIMUM_DIMENSION || height > MAXIMUM_DIMENSION ||
      width * height > MAXIMUM_PIXELS) {
    throw rejected('QR_IMAGE_LIMIT');
  }
  // Browser screenshots/canvas PNGs are non-interlaced. pngjs accepts repeated
  // IHDR chunks and uses an unbounded inflate path for interlaced images, so
  // close both paths before it sees any compressed input.
  if (bytes[24] !== 8 || ![2, 6].includes(bytes[25]) ||
      bytes[26] !== 0 || bytes[27] !== 0 || bytes[28] !== 0) {
    throw rejected('QR_IMAGE_PROFILE');
  }
  let offset = 8;
  let sawData = false;
  let endedData = false;
  let ended = false;
  while (offset < bytes.length) {
    if (bytes.length - offset < 12) throw rejected('QR_IMAGE_PROFILE');
    const length = bytes.readUInt32BE(offset);
    if (length > bytes.length - offset - 12) throw rejected('QR_IMAGE_PROFILE');
    const type = bytes.toString('ascii', offset + 4, offset + 8);
    if (!/^[A-Za-z]{4}$/.test(type) || (type === 'IHDR' && offset !== 8)) {
      throw rejected('QR_IMAGE_PROFILE');
    }
    if (type === 'IDAT') {
      if (endedData) throw rejected('QR_IMAGE_PROFILE');
      sawData = true;
    } else if (sawData) {
      endedData = true;
    }
    offset += length + 12;
    if (type === 'IEND') {
      if (length !== 0 || !sawData || offset !== bytes.length) throw rejected('QR_IMAGE_PROFILE');
      ended = true;
      break;
    }
  }
  if (!ended) throw rejected('QR_IMAGE_PROFILE');
  try {
    const image = PNG.sync.read(bytes, { checkCRC: true });
    if (image.width !== width || image.height !== height || image.data.length !== width * height * 4) {
      throw rejected('QR_IMAGE_FORMAT');
    }
    return {
      width,
      height,
      data: new Uint8ClampedArray(image.data.buffer, image.data.byteOffset, image.data.byteLength),
    };
  } catch {
    throw rejected('QR_IMAGE_FORMAT');
  }
}
