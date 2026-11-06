#!/bin/bash
# AEK Hub — άνοιγμα στο Xcode (Mac). Χρήση: διπλό κλικ ή στο Τερματικό: bash mac.sh
set -e
cd "$(dirname "$0")"
if ! command -v xcodegen >/dev/null 2>&1; then
  if ! command -v brew >/dev/null 2>&1; then
    echo "➜ Χρειάζεται το Homebrew. Άνοιξε το https://brew.sh, αντέγραψε την εντολή που δίνει στο Τερματικό και ξανατρέξε αυτό."
    exit 1
  fi
  echo "➜ Εγκατάσταση XcodeGen…"
  brew install xcodegen
fi
echo "➜ Δημιουργία του project…"
xcodegen generate
echo "➜ Άνοιγμα στο Xcode…"
open AEKHub.xcodeproj
echo "✓ Έτοιμο. Συνέχισε με τα βήματα στο Xcode (Signing → Team)."
