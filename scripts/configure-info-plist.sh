#!/bin/bash
#
# configure-info-plist.sh
# Configure Xcode to use custom Info.plist with Sparkle settings
#

set -e

PROJECT_FILE="/Users/ethanhall/Desktop/Illuminate/Illuminate.xcodeproj/project.pbxproj"

echo "Configuring Xcode project to use Illuminate-Info.plist..."

# Backup the project file
cp "$PROJECT_FILE" "$PROJECT_FILE.backup"

# Replace GENERATE_INFOPLIST_FILE = YES with INFOPLIST_FILE path
# This needs to be done for both Debug and Release configurations
sed -i '' 's/GENERATE_INFOPLIST_FILE = YES;/INFOPLIST_FILE = Illuminate\/Illuminate-Info.plist;/' "$PROJECT_FILE"

echo "✓ Project configured to use Illuminate-Info.plist"
echo ""
echo "Please rebuild your project in Xcode."
