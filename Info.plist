#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")"

if ! command -v xcodebuild >/dev/null 2>&1; then
  echo "xcodebuild is required. Build this project on macOS with Xcode installed." >&2
  exit 1
fi

if ! command -v xcodegen >/dev/null 2>&1; then
  echo "xcodegen is required. Install with: brew install xcodegen" >&2
  exit 1
fi

xcode_version="$(xcodebuild -version | awk '/Xcode/ { print $2 }')"
xcode_major="${xcode_version%%.*}"
if [[ "${xcode_major:-0}" -lt 26 ]]; then
  echo "Warning: App Store Connect uploads currently require Xcode 26 or later with the iOS 26 SDK." >&2
fi

team_args=()
if [[ -n "${DEVELOPMENT_TEAM:-}" ]]; then
  team_args+=(DEVELOPMENT_TEAM="$DEVELOPMENT_TEAM")
else
  echo "Warning: DEVELOPMENT_TEAM is not set. Xcode automatic signing must already be configured." >&2
fi

auth_args=()
if [[ -n "${ASC_KEY_PATH:-}" && -n "${ASC_KEY_ID:-}" && -n "${ASC_ISSUER_ID:-}" ]]; then
  auth_args+=(
    -authenticationKeyPath "$ASC_KEY_PATH"
    -authenticationKeyID "$ASC_KEY_ID"
    -authenticationKeyIssuerID "$ASC_ISSUER_ID"
  )
fi

signing_args=(CODE_SIGN_STYLE="${CODE_SIGN_STYLE:-Automatic}")
if [[ -n "${PROVISIONING_PROFILE_SPECIFIER:-}" ]]; then
  signing_args+=(PROVISIONING_PROFILE_SPECIFIER="$PROVISIONING_PROFILE_SPECIFIER")
fi
if [[ -n "${CODE_SIGN_IDENTITY:-}" ]]; then
  signing_args+=(CODE_SIGN_IDENTITY="$CODE_SIGN_IDENTITY")
fi

scheme="${SCHEME:-DesertTycoon}"
configuration="${CONFIGURATION:-Release}"
archive_path="${ARCHIVE_PATH:-build/DesertTycoon.xcarchive}"
export_path="${EXPORT_PATH:-build/export}"
export_options="${EXPORT_OPTIONS_PLIST:-ExportOptions.plist}"

xcodegen generate
rm -rf "$archive_path" "$export_path"

xcodebuild \
  -project "DesertTycoon.xcodeproj" \
  -scheme "$scheme" \
  -configuration "$configuration" \
  -destination "generic/platform=iOS" \
  -archivePath "$archive_path" \
  -allowProvisioningUpdates \
  "${auth_args[@]}" \
  "${team_args[@]}" \
  "${signing_args[@]}" \
  archive

xcodebuild -exportArchive \
  -archivePath "$archive_path" \
  -exportOptionsPlist "$export_options" \
  -exportPath "$export_path" \
  -allowProvisioningUpdates \
  "${auth_args[@]}"

echo "IPA output: $export_path"
