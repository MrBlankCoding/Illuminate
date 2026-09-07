#!/bin/bash
#
# setup-sparkle-keys.sh
# Generate Sparkle EdDSA keys and configure Info.plist
#

# Check public key
#generate_keys -p

# Build release CLI
#cd release/cli && go build -o ../../release main.go

# Create release (interactive)
#./release

# Test locally
#python3 -m http.server 8080  # Serve appcast
# Then launch app and press ⌘U

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}╔═══════════════════════════════════════╗${NC}"
echo -e "${BLUE}║  Sparkle EdDSA Key Setup for Dev     ║${NC}"
echo -e "${BLUE}╚═══════════════════════════════════════╝${NC}"
echo ""

# Find generate_keys in DerivedData
echo -e "${YELLOW}Finding Sparkle tools...${NC}"

GENERATE_KEYS=""
DD_BASE="$HOME/Library/Developer/Xcode/DerivedData"

if [ -d "$DD_BASE" ]; then
    GENERATE_KEYS=$(find "$DD_BASE" -name "generate_keys" -path "*/artifacts/sparkle/Sparkle/bin/generate_keys" 2>/dev/null | head -n 1)
fi

if [ -z "$GENERATE_KEYS" ]; then
    echo -e "${RED}✗ generate_keys not found in DerivedData${NC}"
    echo ""
    echo "Please build your project in Xcode first (Sparkle will be downloaded)"
    echo "Then run this script again."
    exit 1
fi

echo -e "${GREEN}✓ Found: $GENERATE_KEYS${NC}"
echo ""

# Create keys directory
KEYS_DIR="$HOME/.sparkle"
mkdir -p "$KEYS_DIR"

PRIVATE_KEY="$KEYS_DIR/illuminate_dev_ed25519"
PUBLIC_KEY_FILE="$KEYS_DIR/illuminate_dev_ed25519.pub"

# Check if keys already exist
if [ -f "$PRIVATE_KEY" ]; then
    echo -e "${YELLOW}⚠ Development keys already exist${NC}"
    echo "Private key: $PRIVATE_KEY"
    echo ""
    
    if [ -f "$PUBLIC_KEY_FILE" ]; then
        PUBLIC_KEY=$(cat "$PUBLIC_KEY_FILE")
        echo -e "${GREEN}Public key:${NC}"
        echo "$PUBLIC_KEY"
    fi
    
    echo ""
    read -p "Regenerate keys? This will invalidate existing releases. [y/N]: " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Keeping existing keys."
        
        # Still update Info.plist if needed
        if [ -f "$PUBLIC_KEY_FILE" ] && [ -f "./Illuminate/Info.plist" ]; then
            PUBLIC_KEY=$(cat "$PUBLIC_KEY_FILE")
            if /usr/libexec/PlistBuddy -c "Print :SUPublicEDKey" "./Illuminate/Info.plist" &>/dev/null; then
                /usr/libexec/PlistBuddy -c "Set :SUPublicEDKey '$PUBLIC_KEY'" "./Illuminate/Info.plist"
                echo -e "${GREEN}✓ Info.plist is up to date${NC}"
            fi
        fi
        exit 0
    fi
fi

# Generate new keys
echo -e "${YELLOW}Generating new EdDSA key pair...${NC}"

# Use generate_keys tool
OUTPUT=$("$GENERATE_KEYS" 2>&1 || true)

# Extract keys from output (format: A public key has been generated and saved, and A private key has been generated and saved)
PUBLIC_KEY=$(echo "$OUTPUT" | grep -A 1 "public key" | tail -n 1 | xargs)
PRIVATE_KEY_VALUE=$(echo "$OUTPUT" | grep -A 1 "private key" | tail -n 1 | xargs)

if [ -z "$PUBLIC_KEY" ] || [ -z "$PRIVATE_KEY_VALUE" ]; then
    echo -e "${RED}✗ Failed to generate keys${NC}"
    echo "Output was:"
    echo "$OUTPUT"
    exit 1
fi

# Save keys
echo "$PRIVATE_KEY_VALUE" > "$PRIVATE_KEY"
chmod 600 "$PRIVATE_KEY"
echo "$PUBLIC_KEY" > "$PUBLIC_KEY_FILE"
chmod 644 "$PUBLIC_KEY_FILE"

echo -e "${GREEN}✓ Keys generated and saved${NC}"
echo ""
echo -e "${GREEN}Private key (keep secret):${NC} $PRIVATE_KEY"
echo -e "${GREEN}Public key:${NC} $PUBLIC_KEY"
echo ""

# Update Info.plist if it exists
INFO_PLIST="./Illuminate/Info.plist"

if [ -f "$INFO_PLIST" ]; then
    echo -e "${YELLOW}Updating Info.plist...${NC}"
    
    # Check if SUPublicEDKey already exists
    if /usr/libexec/PlistBuddy -c "Print :SUPublicEDKey" "$INFO_PLIST" &>/dev/null; then
        # Update existing key
        /usr/libexec/PlistBuddy -c "Set :SUPublicEDKey '$PUBLIC_KEY'" "$INFO_PLIST"
        echo -e "${GREEN}✓ Updated SUPublicEDKey in Info.plist${NC}"
    else
        # Add new key
        /usr/libexec/PlistBuddy -c "Add :SUPublicEDKey string '$PUBLIC_KEY'" "$INFO_PLIST" 2>/dev/null || true
        echo -e "${GREEN}✓ Added SUPublicEDKey to Info.plist${NC}"
    fi
    
    # Set feed URL for local development if not present
    if ! /usr/libexec/PlistBuddy -c "Print :SUFeedURL" "$INFO_PLIST" &>/dev/null; then
        /usr/libexec/PlistBuddy -c "Add :SUFeedURL string 'http://localhost:8080/appcast.xml'" "$INFO_PLIST" 2>/dev/null || true
        echo -e "${YELLOW}✓ Added local development SUFeedURL (localhost:8080)${NC}"
        echo "  Update this to your production URL before release"
    fi
else
    echo -e "${YELLOW}⚠ Info.plist not found at $INFO_PLIST${NC}"
    echo "Add this to your Info.plist manually:"
    echo ""
    echo "<key>SUPublicEDKey</key>"
    echo "<string>$PUBLIC_KEY</string>"
fi

echo ""
echo -e "${GREEN}╔═══════════════════════════════════════╗${NC}"
echo -e "${GREEN}║  Setup Complete! ✅                   ║${NC}"
echo -e "${GREEN}╚═══════════════════════════════════════╝${NC}"
echo ""
echo "Next steps:"
echo "1. Build and run your app in Xcode"
echo "2. The EdDSA deprecation warning should be gone"
echo "3. For releases, use: ./release (your Go CLI will use the private key)"
echo ""
echo -e "${BLUE}Keys saved to: $KEYS_DIR${NC}"
echo ""
