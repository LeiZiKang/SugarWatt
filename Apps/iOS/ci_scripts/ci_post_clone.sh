#!/bin/sh
set -e

# Xcode Cloud post-clone hook for SugarWatt (iOS & watchOS).
# Injects git-ignored signing settings from Xcode Cloud environment variables
# and auto-increments CFBundleVersion from CI_BUILD_NUMBER so every TestFlight
# and App Store build has a monotonically increasing build number.

APP_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$APP_ROOT"

defaults write com.apple.dt.Xcode IDESkipMacroFingerprintValidation -bool YES
defaults write com.apple.dt.Xcode IDESkipPackagePluginFingerprintValidatation -bool YES

TEAM_ID="${KC_DEVELOPMENT_TEAM:-${CI_TEAM_ID:-}}"
BUNDLE_PREFIX="${KC_BUNDLE_ID_PREFIX:-io.github.leizikang}"
BUILD_NUM="${CI_BUILD_NUMBER:-2}"

if [ -z "$TEAM_ID" ]; then
  echo "error: KC_DEVELOPMENT_TEAM is not set. Add KC_DEVELOPMENT_TEAM in Xcode Cloud Workflow -> Environment." >&2
  exit 1
fi

cat > Config/Local.xcconfig <<EOF
DEVELOPMENT_TEAM = ${TEAM_ID}
BUNDLE_ID_PREFIX = ${BUNDLE_PREFIX}
CODE_SIGN_STYLE = Automatic
IOS_CODE_SIGN_STYLE = Automatic
CURRENT_PROJECT_VERSION = ${BUILD_NUM}
EOF

echo "Configured Config/Local.xcconfig for Xcode Cloud iOS/watchOS build #${BUILD_NUM} (${BUNDLE_PREFIX}.kangcharge)."

if command -v xcodegen >/dev/null 2>&1; then
  xcodegen generate
fi
