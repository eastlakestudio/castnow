#!/bin/bash
set -e

# Define paths
PROJECT_DIR="/Users/minghualiu/personal/EastlakeStudio/castnow/apps/mobile_pro"
ARCHIVE_PATH="$PROJECT_DIR/build/ios/archive/Runner.xcarchive"
EXPORT_PATH="$PROJECT_DIR/build/ios/ipa"
PLIST_PATH="$PROJECT_DIR/ios/ExportOptions.plist"

echo "------------------------------------------------"
echo "Phase 1: Building Archive..."
echo "------------------------------------------------"
cd "$PROJECT_DIR"
flutter build ipa --release --no-codesign

echo "------------------------------------------------"
echo "Phase 2: Exporting IPA..."
echo "Archive: $ARCHIVE_PATH"
echo "Export Options: $PLIST_PATH"
echo "------------------------------------------------"

# Ensure export directory exists
mkdir -p "$EXPORT_PATH"

# Run xcodebuild export
xcodebuild -exportArchive \
    -archivePath "$ARCHIVE_PATH" \
    -exportPath "$EXPORT_PATH" \
    -exportOptionsPlist "$PLIST_PATH" \
    -allowProvisioningUpdates

echo "------------------------------------------------"
echo "IPA Export Success!"
echo "Destination: $EXPORT_PATH"
echo "------------------------------------------------"

# Rename the IPA to castnow_pro_mobile.ipa
for f in "$EXPORT_PATH"/*.ipa; do if [ -f "$f" ]; then mv "$f" "$EXPORT_PATH/castnow_pro_mobile.ipa"; break; fi; done

ls -lh "$EXPORT_PATH"
