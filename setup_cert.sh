#!/bin/bash
# setup_cert.sh — Run ONCE to create a self-signed code signing certificate.
# This is the ONLY fix for the -67050 TCC bug on macOS Sequoia.

set -e
CERT_NAME="SuperTranslatorDev"

# Check if already exists
if security find-identity -v -p codesigning 2>/dev/null | grep -q "${CERT_NAME}"; then
    echo "✅ Certificate '${CERT_NAME}' already exists:"
    security find-identity -v -p codesigning | grep "${CERT_NAME}"
    exit 0
fi

echo "╔══════════════════════════════════════════════════╗"
echo "║  Create a Code Signing Certificate               ║"
echo "║  (One-time setup — takes 30 seconds)              ║"
echo "╚══════════════════════════════════════════════════╝"
echo ""
echo "Keychain Access is opening now."
echo ""
echo "  1. Menu bar: Keychain Access → Certificate Assistant"
echo "     → Create a Certificate..."
echo "  2. Name:            ${CERT_NAME}"
echo "  3. Identity Type:   Self Signed Root"
echo "  4. Certificate Type: Code Signing"
echo "  5. Click Create → Done"
echo ""

open -a "Keychain Access"

echo "When done, run:  security find-identity -v -p codesigning"
echo "You should see '${CERT_NAME}' in the list."
