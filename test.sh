#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"

SOURCE_VERSION=$(sed -n 's/.*kAppVersion[[:space:]]*=[[:space:]]*"\([^"]*\)".*/\1/p' main.swift)
SHORT_VERSION=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' Info.plist)
BUNDLE_VERSION=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' Info.plist)
[ -n "$SOURCE_VERSION" ]
[ "$SOURCE_VERSION" = "$SHORT_VERSION" ]
[ "$SOURCE_VERSION" = "$BUNDLE_VERSION" ]

plutil -lint Info.plist >/dev/null
bash -n build.sh
bash -n update.sh

for language in en fr es ar zh hi bn ru pt ur; do
    test -s "WidgetLocalizations/$language.lproj/Localizable.strings"
    plutil -lint "WidgetLocalizations/$language.lproj/Localizable.strings" >/dev/null
done

grep -q 'source-manifest.json' build.sh
grep -q 'Never introduce a Qur.an web view' AGENTS.md

echo "Smoke checks passed for Salat Time $SOURCE_VERSION"
