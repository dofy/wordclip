#!/bin/bash
#
# Package WordClip for macOS as a DMG that can be handed to someone else.
#
# Reading the selection in another app needs the Accessibility API, which the
# sandbox forbids, so the macOS build cannot ship on the Mac App Store and has
# to be handed out directly. That leaves a Developer ID signature with
# notarization, or a self-signed one. This script does the second by default and
# accepts the first through SIGNING_IDENTITY.
#
# Pro is unlocked in this build. A directly distributed copy has no App Store
# receipt, so StoreKitEntitlement would report "not purchased" forever and OCR
# capture and dictionary import would be locked with no transaction available to
# complete. The ReleaseDirect configuration therefore defines
# WORDCLIP_DIRECT_DISTRIBUTION, which swaps in UnlockedEntitlement — see
# WordClip/App/AppEntitlement.swift. The App Store build is unaffected: it is
# plain Release, without that flag.
#
# Why a certificate rather than an ad-hoc signature: TCC pins the grant to the
# signing certificate, so the Accessibility and Screen Recording grants survive
# updates only as long as every build is signed by the same one. Keep the
# certificate; see the note printed at the end.
#
# Usage:
#   ./scripts/package-release.sh
#   SIGNING_IDENTITY="Developer ID Application: Name (TEAMID)" ./scripts/package-release.sh

set -euo pipefail

readonly project_root="$(cd "$(dirname "$0")/.." && pwd)"
readonly app_name="WordClip.app"
readonly bundle_identifier="xyz.phpz.app.wordclip"
readonly derived_data="${TMPDIR%/}/wordclip-package/DerivedData"
# ReleaseDirect rather than Release: the same release settings, plus the
# compilation condition that unlocks Pro. See `configs:` in project.yml for why
# it is a configuration and not a command-line setting.
readonly build_configuration="ReleaseDirect"
readonly built_app="$derived_data/Build/Products/$build_configuration/$app_name"
readonly login_keychain="$HOME/Library/Keychains/login.keychain-db"
readonly default_identity="WordClip Distribution"
readonly signing_identity="${SIGNING_IDENTITY:-$default_identity}"

# A Developer ID signature needs a secure timestamp and the hardened runtime, or
# notarization rejects it. A self-signed one needs neither, and the timestamp
# server call would only make the build require a network.
if [[ "$signing_identity" == "$default_identity" ]]; then
    readonly signing_options=(--timestamp=none)
    readonly is_self_signed=true
else
    readonly signing_options=(--timestamp --options runtime)
    readonly is_self_signed=false
fi

# stderr, not stdout: build_dmg's result is read through a command substitution,
# so anything this writes to stdout would be appended to the path it returns.
log() {
    printf '\n==> %s\n' "$1" >&2
}

# Reads MARKETING_VERSION out of project.yml so the DMG name and the volume name
# cannot drift from the version the app reports about itself.
read_marketing_version() {
    local version
    version="$(sed -n 's/^[[:space:]]*MARKETING_VERSION:[[:space:]]*"\{0,1\}\([^"]*\)"\{0,1\}[[:space:]]*$/\1/p' \
        "$project_root/project.yml" | head -1)"

    if [[ -z "$version" ]]; then
        echo "error: could not read MARKETING_VERSION from project.yml" >&2
        exit 1
    fi

    printf '%s' "$version"
}

ensure_signing_identity() {
    if [[ "$is_self_signed" == false ]]; then
        if ! security find-identity -v -p codesigning | grep -qF "$signing_identity"; then
            echo "error: no codesigning identity named '$signing_identity' in the keychain" >&2
            exit 1
        fi
        return
    fi

    if security find-certificate -c "$signing_identity" "$login_keychain" >/dev/null 2>&1; then
        return
    fi

    log "Creating the self-signed certificate '$signing_identity'"
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
            -subj "/CN=$signing_identity/O=WordClip" \
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

# A silently dropped compilation condition would ship a build whose Pro features
# are locked with no purchase available, and nothing in the build output would
# say so. Check the setting as xcodebuild resolves it for this exact scheme and
# configuration, before spending several minutes on a universal build.
verify_direct_distribution_flag() {
    local conditions
    conditions="$(xcodebuild \
        -project WordClip.xcodeproj \
        -scheme WordClip-macOS \
        -configuration "$build_configuration" \
        -showBuildSettings 2>/dev/null \
        | sed -n 's/^[[:space:]]*SWIFT_ACTIVE_COMPILATION_CONDITIONS = //p')"

    if [[ " $conditions " != *" WORDCLIP_DIRECT_DISTRIBUTION "* ]]; then
        echo "error: the $build_configuration configuration does not define" >&2
        echo "       WORDCLIP_DIRECT_DISTRIBUTION (resolved to: ${conditions:-<empty>})." >&2
        echo "       Pro would be locked with nothing to buy. See configs: in project.yml." >&2
        exit 1
    fi
    log "$build_configuration defines WORDCLIP_DIRECT_DISTRIBUTION"
}

build_universal_app() {
    log "Building $app_name ($build_configuration, universal, Pro unlocked)"
    rm -rf "$derived_data"

    xcodegen generate
    verify_direct_distribution_flag

    # CODE_SIGN_* overrides: project.yml pins the macOS target to Manual signing
    # with a specific Apple Development certificate hash, which is not on every
    # machine. Signing happens explicitly below, so the build does not need any
    # identity at all.
    #
    # ARCHS is forced and then checked: an arm64-only binary would leave every
    # Intel Mac unable to open the app.
    xcodebuild \
        -project WordClip.xcodeproj \
        -scheme WordClip-macOS \
        -configuration "$build_configuration" \
        -derivedDataPath "$derived_data" \
        ARCHS="x86_64 arm64" \
        ONLY_ACTIVE_ARCH=NO \
        CODE_SIGNING_ALLOWED=NO \
        CODE_SIGN_IDENTITY="" \
        CODE_SIGN_STYLE=Automatic \
        build

    local architectures
    architectures="$(lipo -archs "$built_app/Contents/MacOS/WordClip")"
    for architecture in x86_64 arm64; do
        if [[ " $architectures " != *" $architecture "* ]]; then
            echo "error: the binary is missing the $architecture slice (got: $architectures)" >&2
            exit 1
        fi
    done
    log "Architectures: $architectures"

    # No symbol check on the built binary: UnlockedEntitlement lives in the
    # statically linked WordClipKit, so its name is in the binary whether or not
    # the flag took effect — measured at 2 occurrences in plain Release against 4
    # in ReleaseDirect. The guard that does work runs before the build, on the
    # setting as xcodebuild resolves it.
}

sign_app() {
    log "Signing with '$signing_identity'"
    codesign --force --deep --sign "$signing_identity" \
        --identifier "$bundle_identifier" \
        "${signing_options[@]}" \
        "$built_app"
    codesign --verify --deep --strict --verbose=2 "$built_app"
}

write_first_run_note() {
    # macOS quarantines anything that arrives over a download, AirDrop or a
    # messaging app. For a build that Apple has not notarized, Gatekeeper then
    # refuses it outright, and on macOS 15 and later the old right-click-Open
    # shortcut no longer clears it — the only route is Privacy & Security.
    # Without this file the app looks broken rather than unapproved.
    cat > "$1" <<'NOTE'
WordClip — opening it the first time
===================================

This build is signed, but not notarized by Apple, so macOS blocks it until you
approve it once.

1. Drag WordClip to the Applications folder in this window.
2. Open it. macOS will say it cannot verify the developer.
3. Open System Settings > Privacy & Security, scroll to Security, and click
   "Open Anyway" next to WordClip.
4. Open WordClip again and confirm.

Two permissions, both in System Settings > Privacy & Security:

  Accessibility     — to read the word you select in other apps (⌥⌘C)
  Screen Recording  — only if you use OCR capture (⌥⌘O)

Everything else works offline: the dictionary and the word packs ship inside
the app, and nothing is sent anywhere.

Every feature is unlocked in this build, including OCR capture and dictionary
import. There is nothing to buy and no purchase screen.

Closing the window with ⌘W also hides the Dock icon — WordClip keeps running
in the menu bar and the capture shortcuts keep working. Reopen it from the menu
bar icon, or turn that off under Settings > General.


WordClip — 第一次打开
=====================

这个版本有签名，但没有经过 Apple 公证，所以 macOS 会先拦一次。

1. 把 WordClip 拖到这个窗口里的「应用程序」文件夹。
2. 打开它。macOS 会提示无法验证开发者。
3. 打开「系统设置 > 隐私与安全性」，滚到「安全性」，点 WordClip 旁边的「仍要打开」。
4. 再次打开 WordClip 并确认。

要开两个权限，都在「系统设置 > 隐私与安全性」里：

  辅助功能  — 读取你在其他 App 里选中的单词（⌥⌘C）
  屏幕录制  — 只有用 OCR 取词时才需要（⌥⌘O）

其余功能全部离线：词典和词包都打包在 App 里，不向任何地方发送数据。

这个版本所有功能都已解锁，包括 OCR 取词和词典导入。没有需要购买的东西，也没有付费页。

按 ⌘W 关闭窗口时 Dock 图标会一起消失 —— WordClip 继续在状态栏运行，取词快捷键照常
工作。从状态栏图标重新打开，或在「设置 > 通用」里关掉这个行为。


WordClip — 第一次開啟
=====================

這個版本有簽名，但沒有經過 Apple 公證，所以 macOS 會先擋一次。

1. 把 WordClip 拖到這個視窗裡的「應用程式」檔案夾。
2. 開啟它。macOS 會提示無法驗證開發者。
3. 開啟「系統設定 > 隱私權與安全性」，滾到「安全性」，點 WordClip 旁邊的「仍要打開」。
4. 再次開啟 WordClip 並確認。

要開兩個權限，都在「系統設定 > 隱私權與安全性」裡：

  輔助使用  — 讀取你在其他 App 裡選取的單字（⌥⌘C）
  螢幕錄製  — 只有用 OCR 取詞時才需要（⌥⌘O）

其餘功能全部離線：字典和詞包都打包在 App 裡，不向任何地方傳送資料。

這個版本所有功能都已解鎖，包括 OCR 取詞和字典匯入。沒有需要購買的東西，也沒有付費頁。

按 ⌘W 關閉視窗時 Dock 圖示會一起消失 —— WordClip 繼續在狀態列執行，取詞快速鍵照常
運作。從狀態列圖示重新開啟，或在「設定 > 一般」裡關掉這個行為。
NOTE
}

build_dmg() {
    local version="$1"
    local output_directory="$project_root/dist"
    local dmg_path="$output_directory/WordClip-$version.dmg"
    local staging_directory

    log "Building $(basename "$dmg_path")"
    staging_directory="$(mktemp -d)"
    trap 'rm -rf -- "$staging_directory"' RETURN

    ditto "$built_app" "$staging_directory/$app_name"
    ln -s /Applications "$staging_directory/Applications"
    write_first_run_note "$staging_directory/READ ME FIRST.txt"

    mkdir -p "$output_directory"
    rm -f "$dmg_path"

    # HFS+ rather than APFS: an APFS image will not mount on macOS versions
    # older than the one that wrote it, and the app itself runs on macOS 15.
    hdiutil create \
        -volname "WordClip $version" \
        -srcfolder "$staging_directory" \
        -fs HFS+ \
        -format UDZO \
        -quiet \
        "$dmg_path"

    codesign --force --sign "$signing_identity" "${signing_options[@]}" "$dmg_path"

    printf '%s' "$dmg_path"
}

main() {
    cd "$project_root"

    local version
    version="$(read_marketing_version)"

    ensure_signing_identity
    build_universal_app
    sign_app

    local dmg_path
    dmg_path="$(build_dmg "$version")"

    log "Done"
    printf '  %s\n' "$dmg_path"
    printf '  %s\n' "$(du -h "$dmg_path" | cut -f1)"
    shasum -a 256 "$dmg_path" | awk '{printf "  sha256 %s\n", $1}'

    if [[ "$is_self_signed" == true ]]; then
        cat <<NOTE

  Signed by the self-signed certificate '$signing_identity'.

  Back that certificate up, and sign every future build with it. If it is lost,
  new builds get a different certificate, macOS stops recognising them as the
  same app, and everyone has to grant Accessibility again:

    security export -k "$login_keychain" -t identities -f pkcs12 \\
        -o wordclip-distribution.p12

  Recipients have to approve the app once in System Settings; "READ ME FIRST.txt"
  inside the DMG walks them through it. A Developer ID certificate plus
  notarization removes that step — pass it as SIGNING_IDENTITY once you have one.

  This DMG has Pro unlocked. Do not use it for an App Store submission: that
  build is the one without WORDCLIP_DIRECT_DISTRIBUTION. See docs/RELEASE-iOS.md
  for the store path.
NOTE
    fi
}

main "$@"
