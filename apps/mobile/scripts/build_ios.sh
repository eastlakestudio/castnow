#!/bin/bash

# CastNow iOS Build Script with Auto-Increment
# Usage: ./scripts/build_ios.sh

# Get the current version line from pubspec.yaml
VERSION_LINE=$(grep "version: " pubspec.yaml)
VERSION_PART=$(echo $VERSION_LINE | cut -d ' ' -f 2)
BASE_VERSION=$(echo $VERSION_PART | cut -d '+' -f 1)
BUILD_NUMBER=$(echo $VERSION_PART | cut -d '+' -f 2)

# Increment build number
NEW_BUILD_NUMBER=$((BUILD_NUMBER + 1))
NEW_VERSION="$BASE_VERSION+$NEW_BUILD_NUMBER"

echo "🚀 Incrementing build number: $VERSION_PART -> $NEW_VERSION"

# Update pubspec.yaml
# Using a temp file for safety across different sed versions (macOS vs Linux)
sed -e "s/version: .*/version: $NEW_VERSION/" pubspec.yaml > pubspec.yaml.tmp && mv pubspec.yaml.tmp pubspec.yaml

echo "📦 Running flutter build ipa..."
flutter build ipa --release

if [ $? -eq 0 ]; then
  echo "✅ Build successful! New version: $NEW_VERSION"
else
  echo "❌ Build failed. Please check the logs."
  exit 1
fi
