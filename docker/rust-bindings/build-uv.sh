#!/bin/bash
# Build and install SSI Python bindings using UV

set -e

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd "$SCRIPT_DIR"

echo "=========================================="
echo "Building SSI Python Bindings with UV"
echo "=========================================="
echo ""

# Check if Rust is installed
if ! command -v cargo &> /dev/null; then
    echo "ERROR: Rust is not installed!"
    echo "Please install Rust from: https://rustup.rs/"
    exit 1
fi

echo "✓ Rust found: $(rustc --version)"

# Check if UV is installed
if ! command -v uv &> /dev/null; then
    echo ""
    echo "UV not found. Installing UV..."
    curl -LsSf https://astral.sh/uv/install.sh | sh

    # Add UV to PATH for this session
    export PATH="$HOME/.cargo/bin:$PATH"

    if ! command -v uv &> /dev/null; then
        echo "ERROR: UV installation failed!"
        exit 1
    fi
fi

echo "✓ UV found: $(uv --version)"
echo ""

# Create virtual environment if it doesn't exist
if [ ! -d ".venv" ]; then
    echo "Creating virtual environment with UV..."
    uv venv
    echo "✓ Virtual environment created"
    echo ""
fi

# Activate virtual environment
source .venv/bin/activate

# Install maturin in the virtual environment
echo "Installing maturin..."
uv pip install maturin

echo "✓ Maturin installed"
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
echo "The ssi_python module is now available in the virtual environment."
echo ""
echo "To use it:"
echo "  1. Activate the virtual environment:"
echo "     source .venv/bin/activate"
echo ""
echo "  2. Test the module:"
echo "     python -c 'import ssi_python; print(\"Success!\")'"
echo ""
echo "  3. Run the example:"
echo "     python ../plugins/custom-tokens/mdoc_token.py"
echo ""
echo "To deactivate the virtual environment:"
echo "  deactivate"
echo ""
