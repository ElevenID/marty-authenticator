#!/bin/bash
# Build script for SSI Python bindings

set -e

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd "$SCRIPT_DIR"

echo "=========================================="
echo "Building SSI Python Bindings"
echo "=========================================="
echo ""

# Check if Rust is installed
if ! command -v cargo &> /dev/null; then
    echo "ERROR: Rust is not installed!"
    echo "Please install Rust from: https://rustup.rs/"
    exit 1
fi

echo "✓ Rust found: $(rustc --version)"

# Check if Python is installed
if ! command -v python3 &> /dev/null; then
    echo "ERROR: Python 3 is not installed!"
    exit 1
fi

echo "✓ Python found: $(python3 --version)"

# Install maturin if not present
if ! command -v maturin &> /dev/null; then
    echo ""
    echo "Installing maturin..."
    pip3 install maturin
fi

echo "✓ Maturin found: $(maturin --version)"
echo ""

# Build the extension
echo "Building Rust extension..."
echo ""

# Development build (faster, includes debug symbols)
if [ "$1" = "--release" ]; then
    echo "Building in RELEASE mode..."
    maturin develop --release
else
    echo "Building in DEVELOPMENT mode..."
    maturin develop
fi

echo ""
echo "=========================================="
echo "✓ Build complete!"
echo "=========================================="
echo ""
echo "The ssi_python module is now available in your Python environment."
echo ""
echo "Test it with:"
echo "  python3 -c 'import ssi_python; print(\"Success!\")'"
echo ""
echo "Or run the example:"
echo "  python3 ../plugins/custom-tokens/mdoc_token.py"
echo ""
