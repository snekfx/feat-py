#!/bin/bash
set -e

# Configuration
SNAKE_BIN_DIR="$HOME/.local/bin/snek"

# Resolve repository root from bin/
ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"

# Extract version from feat.py or default
VERSION=$(grep -E "^__version__|^VERSION\s*=" "$ROOT_DIR/feat.py" | head -1 | cut -d'"' -f2 2>/dev/null || echo "2.0.0-dev")

# Display deployment ceremony
echo "╔════════════════════════════════════════════════╗"
echo "║              FEAT DEPLOYMENT                   ║"
echo "╠════════════════════════════════════════════════╣"
echo "║ Package: Feature Documentation Tool            ║"
echo "║ Version: v$VERSION                             ║"
echo "║ Target:  $SNAKE_BIN_DIR/                       ║"
echo "╚════════════════════════════════════════════════╝"
echo ""

# Deploy Feat tool
echo "📋 Deploying Feat tool..."
mkdir -p "$SNAKE_BIN_DIR"

FEAT_SOURCE="$ROOT_DIR/feat.py"
FEAT_TARGET="$SNAKE_BIN_DIR/feat"

if [ -f "$FEAT_SOURCE" ]; then
    # Deploy as feat
    if ! cp "$FEAT_SOURCE" "$FEAT_TARGET"; then
        echo "❌ Failed to copy feat to $FEAT_TARGET"
        exit 1
    fi

    if ! chmod +x "$FEAT_TARGET"; then
        echo "❌ Failed to make feat executable"
        exit 1
    fi

    echo "✅ Feat tool deployed to $FEAT_TARGET"

    # Test the deployment
    echo "🧪 Testing feat deployment..."
    if command -v feat >/dev/null 2>&1; then
        echo "✅ feat is available in PATH"
    else
        echo "⚠️  Warning: feat not found in PATH (may need to restart shell)"
    fi
else
    echo "❌ Error: feat.py not found at $FEAT_SOURCE"
    exit 1
fi

echo ""
echo "╔════════════════════════════════════════════════╗"
echo "║          DEPLOYMENT SUCCESSFUL!                ║"
echo "╚════════════════════════════════════════════════╝"
echo "  Deployed: Feat v$VERSION                       "
echo "  Location: $FEAT_TARGET                         "
echo ""
echo "📋 Feat documentation commands:"
echo "   feat init                   # Generate .spec.toml config"
echo "   feat list                   # List discovered features"
echo "   feat scan <feature>         # Inspect feature surface"
echo "   feat docs <feature>         # Display feature documentation"
echo "   feat update <feature>       # Update feature documentation"
echo "   feat sync                   # Update all feature docs"
echo "   feat check                  # Validate configuration"
echo "   feat --help                 # Full command reference"
echo ""
echo "🚀 Ready to document your project features!"
