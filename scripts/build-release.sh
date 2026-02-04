#!/bin/bash
set -e

# MPF Release Build Script
# Downloads and assembles all components

VERSION="${1:-latest}"
OUTPUT_DIR="${2:-./dist}"
QT_VERSION="${QT_VERSION:-6.8.3}"

echo "=========================================="
echo "MPF Release Build"
echo "=========================================="
echo "Version: $VERSION"
echo "Output:  $OUTPUT_DIR"
echo ""

mkdir -p "$OUTPUT_DIR"/{bin,lib,plugins,qml,config}

# Base URL for releases
BASE_URL="https://github.com/dyzdyz010"

# Download function
download_and_extract() {
    local repo=$1
    local artifact=$2
    local url="$BASE_URL/$repo/releases/$VERSION/download/$artifact"
    
    echo "Downloading $artifact..."
    if [[ "$artifact" == *.zip ]]; then
        curl -L -o /tmp/$artifact "$url"
        unzip -o /tmp/$artifact -d /tmp/extract_$$
    else
        curl -L -o /tmp/$artifact "$url"
        mkdir -p /tmp/extract_$$
        tar -xzf /tmp/$artifact -C /tmp/extract_$$
    fi
    
    # Merge into output directory
    cp -r /tmp/extract_$$/* "$OUTPUT_DIR/" 2>/dev/null || true
    rm -rf /tmp/extract_$$ /tmp/$artifact
}

# Detect platform
if [[ "$OSTYPE" == "msys" || "$OSTYPE" == "win32" ]]; then
    PLATFORM="windows-x64"
    EXT="zip"
else
    PLATFORM="linux-x64"
    EXT="tar.gz"
fi

echo "Platform: $PLATFORM"
echo ""

# Download components
download_and_extract "mpf-sdk" "mpf-sdk-$PLATFORM.$EXT"
download_and_extract "mpf-http-client" "mpf-http-client-$PLATFORM.$EXT"
download_and_extract "mpf-ui-components" "mpf-ui-components-$PLATFORM.$EXT"
download_and_extract "mpf-host" "mpf-host-$PLATFORM.$EXT"
download_and_extract "mpf-plugin-orders" "mpf-plugin-orders-$PLATFORM.$EXT"
download_and_extract "mpf-plugin-rules" "mpf-plugin-rules-$PLATFORM.$EXT"

# Create default config
cat > "$OUTPUT_DIR/config/paths.json" << 'CONFIG'
{
  "pluginPath": "../plugins",
  "extraQmlPaths": [
    "../qml"
  ]
}
CONFIG

echo ""
echo "=========================================="
echo "Build complete: $OUTPUT_DIR"
echo "=========================================="
echo ""
echo "Run with: $OUTPUT_DIR/bin/mpf-host"
