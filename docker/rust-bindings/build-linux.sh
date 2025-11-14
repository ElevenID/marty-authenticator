#!/bin/bash
# Build SSI Python bindings for Linux (manylinux) using Docker
set -e

echo "Building SSI Python bindings for Linux..."
echo "This will create a manylinux wheel that can be used in Docker containers."
echo ""

# Check if Docker is available
if ! command -v docker &> /dev/null; then
    echo "Error: Docker is not installed or not in PATH"
    exit 1
fi

# Build directory
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd "$SCRIPT_DIR"

# Use the official maturin image to build for Linux
echo "Using maturin Docker image to build Linux wheel..."
docker run --rm \
    -v "$(pwd)":/io \
    -w /io \
    ghcr.io/pyo3/maturin:latest \
    build --release --strip --compatibility manylinux2014

echo ""
echo "✓ Build complete!"
echo "Linux wheel created in: target/wheels/"
ls -lh target/wheels/*.whl | tail -1
