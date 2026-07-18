import 'package:camera/camera.dart';
import 'package:camera_platform_interface/camera_platform_interface.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:marty_authenticator/services/liveness_camera_image_converter.dart';

CameraImage image(int format, {int planes = 1}) =>
    CameraImage.fromPlatformInterface(
      CameraImageData(
        format: CameraImageFormat(ImageFormatGroup.unknown, raw: format),
        height: 2,
        width: 2,
        planes: List.generate(
          planes,
          (_) => CameraImagePlane(
            bytes: Uint8List.fromList([1, 2, 3, 4]),
            bytesPerPixel: 1,
            bytesPerRow: 2,
            height: 2,
            width: 2,
          ),
        ),
      ),
    );

const front = CameraDescription(
  name: 'front',
  lensDirection: CameraLensDirection.front,
  sensorOrientation: 90,
);
const back = CameraDescription(
  name: 'back',
  lensDirection: CameraLensDirection.back,
  sensorOrientation: 90,
);

void main() {
  test('converts supported Android and iOS camera buffers', () {
    for (final camera in [front, back]) {
      for (final orientation in DeviceOrientation.values) {
        expect(
          LivenessCameraImageConverter.convert(
            image: image(17),
            camera: camera,
            deviceOrientation: orientation,
            platform: TargetPlatform.android,
          ),
          isNotNull,
        );
      }
    }
    expect(
      LivenessCameraImageConverter.convert(
        image: image(1111970369),
        camera: front,
        deviceOrientation: DeviceOrientation.portraitUp,
        platform: TargetPlatform.iOS,
      ),
      isNotNull,
    );
  });

  test('rejects unsupported platforms, formats, and multi-plane images', () {
    for (final candidate in [
      (platform: TargetPlatform.linux, buffer: image(17)),
      (platform: TargetPlatform.android, buffer: image(35)),
      (platform: TargetPlatform.android, buffer: image(17, planes: 2)),
      (platform: TargetPlatform.iOS, buffer: image(17)),
    ]) {
      expect(
        LivenessCameraImageConverter.convert(
          image: candidate.buffer,
          camera: front,
          deviceOrientation: DeviceOrientation.portraitUp,
          platform: candidate.platform,
        ),
        isNull,
      );
    }
  });
}
