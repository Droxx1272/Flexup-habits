#!/usr/bin/env bash
# Type-check every Swift file in FlexUp/ on Linux, against the stand-in
# Apple frameworks in Stubs/. Catches wrong names, types and arguments in
# app code (and real parser problems); it is not a substitute for building
# in Xcode. Usage:
#   SWIFTC=/path/to/swiftc tools/ios-typecheck/typecheck.sh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SWIFTC="${SWIFTC:-swiftc}"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

cp "$ROOT"/tools/ios-typecheck/Stubs/*.swift "$WORK/"

python3 -I - "$ROOT" "$WORK" <<'PY'
import pathlib, re, sys
root, work = pathlib.Path(sys.argv[1]), pathlib.Path(sys.argv[2])
apple = re.compile(r"^import (SwiftUI|UIKit|UserNotifications|CoreLocation|CryptoKit|DeviceCheck|Security|ImageIO|Charts|MapKit|PhotosUI|AuthenticationServices|AVFoundation|Speech|Combine|AlarmKit|Observation|UniformTypeIdentifiers|Vision|LocalAuthentication)$", re.M)
for path in sorted((root / "FlexUp").rglob("*.swift")):
    text = path.read_text()
    text = apple.sub("", text)
    # Objective-C selectors don't exist on Linux.
    text = text.replace(
        "UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)",
        "UIApplication.shared.endEditingStub()")
    # #Preview is an Xcode macro; turn each into a plain function.
    count = 0
    def preview(_m):
        global count
        count += 1
        return f"@MainActor @ViewBuilder func __preview_{path.stem.replace('+', '_')}_{count}() -> some View {{"
    text = re.sub(r"#Preview(\([^)]*\))?\s*\{", preview, text)
    name = "__".join(path.relative_to(root / "FlexUp").parts)
    (work / name).write_text("import Foundation\n" + text)
PY

cd "$WORK"
"$SWIFTC" -typecheck -swift-version 5 ./*.swift
echo "Type-check passed: $(ls "$WORK"/*.swift | wc -l) files."
