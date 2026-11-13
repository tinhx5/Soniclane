#!/bin/sh

# Fail this script if any subcommand fails
set -e

# The default execution directory of this script is the ci_scripts directory.
cd $CI_PRIMARY_REPOSITORY_PATH

# Clone Flutter stable branch
git clone https://github.com/flutter/flutter.git --depth 1 -b stable "$HOME/flutter"
export PATH="$PATH:$HOME/flutter/bin"

# Pre-cache iOS engine artifacts
flutter precache --ios

# Install Flutter dependencies
flutter pub get

# Install CocoaPods dependencies
cd ios
pod install

exit 0
