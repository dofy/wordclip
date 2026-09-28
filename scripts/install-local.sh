#!/bin/bash
#
# Build the macOS app and install it to /Applications under a stable local
# signing identity.
#
# Two reasons not to build and copy by hand:
#
# 1. project.yml pins CODE_SIGN_IDENTITY to an Apple Development certificate by
#    hash. That certificate does not exist on a fresh machine, so the build
#    fails outright. Signing is disabled during the build and done explicitly
#    below instead, which leaves project.yml alone for real distribution builds.
#
# 2. Signing ad-hoc instead would make TCC pin the grant to the binary's cdhash,
#    the only thing an ad-hoc signature offers. Accessibility then breaks on
#    every rebuild, and the failure is silent and misleading: the System
#    Settings toggle stays on and the TCC row keeps auth_value 2, but the app
#    can no longer read selected text. A self-signed certificate makes TCC pin
#    the certificate, so the grant survives rebuilds.
#
# Usage: ./scripts/install-local.sh

set -euo pipefail

readonly project_root="$(cd "$(dirname "$0")/.." && pwd)"
readonly derived_data="${TMPDIR%/}/wordclip-local/DerivedData"
# Package checkouts live outside DerivedData so wiping a build does not throw
# them away. Resolving GRDB and KeyboardShortcuts needs the network and is by
# far the slowest and least reliable step; this way it happens once.
readonly source_packages="$HOME/Library/Caches/xyz.phpz.app.wordclip/SourcePackages"
readonly app_name="WordClip.app"
readonly built_app="$derived_data/Build/Products/Release/$app_name"
readonly installed_app="/Applications/$app_name"
readonly bundle_identifier="xyz.phpz.app.wordclip"
readonly entitlements="WordClip/Resources/WordClip-macOS.entitlements"
readonly signing_identity="WordClip Local Development"
readonly login_keychain="$HOME/Library/Keychains/login.keychain-db"

ensure_signing_identity() {
    if security find-certificate -c "$signing_identity" "$login_keychain" >/dev/null 2>&1; then
        return
    fi

    (
        local temporary_directory
        local pkcs12_password
        local pkcs12_legacy
        temporary_directory="$(mktemp -d)"
        pkcs12_password="$(openssl rand -hex 24)"
        trap 'rm -rf -- "$temporary_directory"' EXIT

        # OpenSSL 3 defaults PKCS#12 to AES/PBKDF2, which `security import`
        # rejects, so it needs -legacy. The openssl shipped with macOS is
        # LibreSSL, which already writes the older algorithms and has no
        # -legacy option at all — passing it there aborts with a usage dump.
        # Probe instead of assuming which one is on PATH.
        pkcs12_legacy=()
        if openssl pkcs12 -help 2>&1 | grep -q -- '-legacy'; then
            pkcs12_legacy=(-legacy)
        fi

        openssl req -x509 -newkey rsa:2048 -sha256 -nodes -days 3650 \
            -subj "/CN=$signing_identity/O=Local Development" \
            -addext "keyUsage=critical,digitalSignature" \
            -addext "extendedKeyUsage=codeSigning" \
            -keyout "$temporary_directory/private-key.pem" \
            -out "$temporary_directory/certificate.pem" >/dev/null 2>&1

        openssl pkcs12 -export ${pkcs12_legacy[@]+"${pkcs12_legacy[@]}"} \
            -inkey "$temporary_directory/private-key.pem" \
            -in "$temporary_directory/certificate.pem" \
            -name "$signing_identity" \
            -passout "pass:$pkcs12_password" \
            -out "$temporary_directory/identity.p12"

        security import "$temporary_directory/identity.p12" \
            -k "$login_keychain" \
            -P "$pkcs12_password" \
            -T /usr/bin/codesign \
            -T /usr/bin/security >/dev/null
    )
}

ensure_signing_identity

cd "$project_root"
xcodegen generate

mkdir -p "$source_packages"

# -onlyUsePackageVersionsFromResolvedFile: take the pins in
# WordClipKit/Package.resolved as given and skip the remote version check.
# Without it every build reaches out to GitHub, which on a flaky connection
# fails the whole build with "Could not resolve package dependencies" even
# though the checkouts are already on disk.
xcodebuild \
    -project WordClip.xcodeproj \
    -scheme WordClip-macOS \
    -configuration Release \
    -derivedDataPath "$derived_data" \
    -clonedSourcePackagesDirPath "$source_packages" \
    -onlyUsePackageVersionsFromResolvedFile \
    CODE_SIGNING_ALLOWED=NO \
    build

codesign --force --deep --sign "$signing_identity" \
    --identifier "$bundle_identifier" \
    --entitlements "$entitlements" \
    "$built_app"
codesign --verify --deep --strict --verbose=2 "$built_app"

pkill -x WordClip 2>/dev/null || true
ditto "$built_app" "$installed_app"
# ditto preserves the source's timestamps, so the copied bundle keeps whatever
# mtime the build gave it, and replacing files inside Contents/ does not advance
# it. IconServices decides whether to re-read an app's icon from that mtime, so
# a changed icon keeps rendering from the cache; the lsregister below does not
# dislodge it, only the touch does.
touch "$installed_app"
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister \
    -f -R -trusted "$installed_app"

codesign --verify --deep --strict --verbose=2 "$installed_app"
# No `open -n`: that forces a second instance, so a failed pkill above would
# leave two WordClip processes, each with its own window and hotkey handler.
open "$installed_app"

cat <<'NOTE'

Installed. If this was the first install under this signing identity, grant
Accessibility once in System Settings → Privacy & Security → Accessibility
(⌥⌘C capture needs it; ⌥⌘O OCR also needs Screen Recording). Later rebuilds
keep the grant.
NOTE
