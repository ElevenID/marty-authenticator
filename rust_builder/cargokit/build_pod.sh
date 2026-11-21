#!/bin/sh
set -e

BASEDIR=$(dirname "$0")

# Workaround for https://github.com/dart-lang/pub/issues/4010
BASEDIR=$(cd "$BASEDIR" ; pwd -P)

# Remove XCode SDK from path. Otherwise this breaks tool compilation when building iOS project
NEW_PATH=`echo $PATH | tr ":" "\n" | grep -v "Contents/Developer/" | tr "\n" ":"`

export PATH=${NEW_PATH%?} # remove trailing :


# Platform name (macosx, iphoneos, iphonesimulator)
export CARGOKIT_DARWIN_PLATFORM_NAME=$PLATFORM_NAME

# Arctive architectures (arm64, armv7, x86_64), space separated.
export CARGOKIT_DARWIN_ARCHS=$ARCHS

# Current build configuration (Debug, Release)
export CARGOKIT_CONFIGURATION=$CONFIGURATION

# Path to directory containing Cargo.toml.
export CARGOKIT_MANIFEST_DIR=$PODS_TARGET_SRCROOT/$1

# Temporary directory for build artifacts.
export CARGOKIT_TARGET_TEMP_DIR=$TARGET_TEMP_DIR

# Output directory for final artifacts.
export CARGOKIT_OUTPUT_DIR=$PODS_CONFIGURATION_BUILD_DIR/$PRODUCT_NAME

# Directory to store built tool artifacts.
export CARGOKIT_TOOL_TEMP_DIR=$TARGET_TEMP_DIR/build_tool

# Directory inside root project. Not necessarily the top level directory of root project.
export CARGOKIT_ROOT_PROJECT_DIR=$SRCROOT

FLUTTER_EXPORT_BUILD_ENVIRONMENT=(
  "$PODS_ROOT/../Flutter/ephemeral/flutter_export_environment.sh" # macOS
  "$PODS_ROOT/../Flutter/flutter_export_environment.sh" # iOS
)

for path in "${FLUTTER_EXPORT_BUILD_ENVIRONMENT[@]}"
do
  if [[ -f "$path" ]]; then
    source "$path"
  fi
done

sh "$BASEDIR/run_build_tool.sh" build-pod "$@"

case "$PLATFORM_NAME" in
  iphoneos|iphonesimulator)
    # Force references only to the dynamically looked-up Rust/Dart bridge.
    # Force-loading the entire archive loads duplicate ONNX protobuf objects.
    archive="$CARGOKIT_OUTPUT_DIR/lib$2.a"
    # Inspect compiler_builtins with the LLVM version that produced its bitcode.
    host_libdir=$(cd "$CARGOKIT_MANIFEST_DIR" && rustc --print target-libdir)
    llvm_nm="$(dirname "$host_libdir")/bin/llvm-nm"
    if [ ! -x "$llvm_nm" ]; then
      echo "Rust llvm-tools-preview is required to link the iOS bridge" >&2
      exit 1
    fi
    symbols=$("$llvm_nm" -gUj "$archive")
    symbols=$(printf '%s\n' "$symbols" | LC_ALL=C sort -u)
    printf '%s\n' "$symbols" | grep -q '^_frbgen_'
    printf '%s\n' "$symbols" | grep -q '^_frb_init_frb_dart_api_dl$'
    printf '%s\n' "$symbols" | awk '/^_(frb_|frbgen_|Dart_)[A-Za-z0-9_]+$/ || /^_(dummy_method_to_enforce_bundling|store_dart_post_cobject)$/ {
      print "-u", $0
    }' > "$CARGOKIT_OUTPUT_DIR/$2.ffi-link.rsp"
    ;;
esac

# Make a symlink from built framework to phony file, which will be used as input to
# build script. This should force rebuild (podspec currently doesn't support alwaysOutOfDate
# attribute on custom build phase)
ln -fs "$OBJROOT/XCBuildData/build.db" "${BUILT_PRODUCTS_DIR}/cargokit_phony"
ln -fs "${BUILT_PRODUCTS_DIR}/${EXECUTABLE_PATH}" "${BUILT_PRODUCTS_DIR}/cargokit_phony_out"
