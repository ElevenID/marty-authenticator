#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint marty_authenticator_bridge.podspec` to validate before publishing.
#
Pod::Spec.new do |s|
  s.name             = 'marty_authenticator_bridge'
  s.version          = '0.0.1'
  s.summary          = 'Builds the governed Marty wallet Rust bridge.'
  s.description      = <<-DESC
Builds the governed Marty wallet Rust bridge.
                       DESC
  s.homepage         = 'https://github.com/ElevenID/marty-authenticator'
  s.license          = { :file => '../../LICENSE' }
  s.author           = 'ElevenID'

  # This will ensure the source files in Classes/ are included in the native
  # builds of apps using this FFI plugin. Podspec does not support relative
  # paths, so Classes contains a forwarder C file that relatively imports
  # `../src/*` so that the C sources can be shared among all target platforms.
  s.source           = { :path => '.' }
  s.source_files = 'Classes/**/*'
  s.dependency 'Flutter'
  # The Rust archive includes the native ONNX Runtime C++ objects.
  s.libraries = 'c++'
  s.platform = :ios, '11.0'

  # Flutter.framework does not contain a i386 slice.
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386' }
  s.swift_version = '5.0'

  s.script_phase = {
    :name => 'Build Rust library',
    # First argument is relative path to the `rust` folder, second is name of rust library
    :script => 'sh "$PODS_TARGET_SRCROOT/../cargokit/build_pod.sh" ../../rust marty_authenticator_bridge',
    :execution_position => :before_compile,
    :input_files => ['${BUILT_PRODUCTS_DIR}/cargokit_phony'],
    :output_files => [
      "${BUILT_PRODUCTS_DIR}/libmarty_authenticator_bridge.a",
      "${BUILT_PRODUCTS_DIR}/marty_authenticator_bridge.ffi-link.rsp",
    ],
  }
  s.pod_target_xcconfig = {
    'DEFINES_MODULE' => 'YES',
    # Flutter.framework does not contain a i386 slice.
    'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386',
    'OTHER_LDFLAGS' => %q{"${BUILT_PRODUCTS_DIR}/libmarty_authenticator_bridge.a" "-Wl,@${BUILT_PRODUCTS_DIR}/marty_authenticator_bridge.ffi-link.rsp"},
  }
end
