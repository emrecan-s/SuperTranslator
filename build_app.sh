#!/bin/bash
set -e

# ── Configuration ──────────────────────────────────
APP_NAME="SuperTranslator"
BUNDLE_ID="com.emre.SuperTranslator"
CERT_NAME="SuperTranslatorDev"
APP_BUNDLE="${APP_NAME}.app"
CONTENTS_DIR="${APP_BUNDLE}/Contents"
MACOS_DIR="${CONTENTS_DIR}/MacOS"
RESOURCES_DIR="${CONTENTS_DIR}/Resources"
ENTITLEMENTS="Sources/QuickTranslator/App-Entitlements.entitlements"

# ── Step 1: Find the signing certificate ───────────
CERT_SHA=$(security find-identity -v -p codesigning 2>/dev/null \
           | grep "${CERT_NAME}" | head -1 | awk '{print $2}')

if [ -z "${CERT_SHA}" ]; then
    echo "❌ Certificate '${CERT_NAME}' not found."
    echo "   Run './setup_cert.sh' first to create it."
    exit 1
fi
echo "✅ Certificate: ${CERT_NAME} (${CERT_SHA:0:8}...)"

# ── Step 2: Build ──────────────────────────────────
echo "Building in Release mode..."
swift build -c release

# ── Step 3: Assemble .app bundle ───────────────────
echo "Assembling ${APP_BUNDLE}..."
rm -rf "${APP_BUNDLE}"
mkdir -p "${MACOS_DIR}" "${RESOURCES_DIR}"

BINARY_DIR=$(swift build -c release --show-bin-path)
cp "${BINARY_DIR}/${APP_NAME}" "${MACOS_DIR}/"
cp Sources/QuickTranslator/App-Info.plist "${CONTENTS_DIR}/Info.plist"
plutil -convert xml1 "${CONTENTS_DIR}/Info.plist"
printf 'APPL????' > "${CONTENTS_DIR}/PkgInfo"
echo "SuperTranslator" > "${RESOURCES_DIR}/AppIcon.txt"

# ── Step 4: Clean extended attributes ──────────────
xattr -cr "${APP_BUNDLE}" 2>/dev/null

# ── Step 5: Sign with certificate ──────────────────
echo "Signing with certificate..."
codesign --force \
         --options runtime \
         --deep \
         --sign "${CERT_SHA}" \
         --entitlements "${ENTITLEMENTS}" \
         --identifier "${BUNDLE_ID}" \
         "${APP_BUNDLE}"

# ── Step 6: Verify ─────────────────────────────────
echo ""
codesign --verify --deep --strict --verbose=1 "${APP_BUNDLE}"

# Confirm it's NOT ad-hoc
SIG_TYPE=$(codesign -dvvv "${APP_BUNDLE}" 2>&1 | grep "Signature=" | head -1)
if echo "${SIG_TYPE}" | grep -q "adhoc"; then
    echo "❌ ERROR: Signature is ad-hoc. Certificate was not applied correctly."
    exit 1
fi
echo "✅ Signed with certificate (not ad-hoc)"
echo ""
echo "Run:  open ${APP_BUNDLE}"
echo "Grant Accessibility once → it will persist across all future rebuilds."
