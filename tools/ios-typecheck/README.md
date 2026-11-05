# iOS type-check on Linux

Cloud sessions have no Xcode. This checks that every file in `FlexUp/`
type-checks against stand-in Apple frameworks (`Stubs/`), using a stock
Swift toolchain. It catches wrong names, types and arguments, and code the
compiler can't type-check in reasonable time. It does not replace an Xcode
build: AlarmKit code behind `#if canImport(AlarmKit)` isn't checked, and
the stubs are permissive about view modifiers.

```
# once per machine (about 900 MB)
curl -sSL -o swift.tar.gz https://download.swift.org/swift-6.1.2-release/ubuntu2404/swift-6.1.2-RELEASE/swift-6.1.2-RELEASE-ubuntu24.04.tar.gz
mkdir -p ~/swift && tar -xzf swift.tar.gz -C ~/swift --strip-components=1

SWIFTC=~/swift/usr/bin/swiftc tools/ios-typecheck/typecheck.sh
```

When the app uses an Apple API the stubs don't have, the error names it:
add it to `Stubs/` with Apple's signature, never change app code to suit
the stubs. Prove a pass is real by planting an error (for example
`Text(store.notAThing)` in a view body) and watching it fail.
