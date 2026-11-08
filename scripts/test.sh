#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
test_dir="$(mktemp -d)"
trap 'rm -rf "$test_dir"' EXIT
clang -std=c11 -D_DARWIN_C_SOURCE -I Sources/RealtimeAudio/include Sources/RealtimeAudio/RealtimeAudio.c Tests/RealtimeTests.c -o "$test_dir/audio-tests"
"$test_dir/audio-tests"
swiftc Sources/QingChang/Library.swift Sources/QingChang/Singing.swift Tests/Singing/main.swift -o "$test_dir/singing-tests"
"$test_dir/singing-tests"
swiftc Sources/QingChang/Devices.swift Tests/Devices/main.swift -o "$test_dir/device-tests"
"$test_dir/device-tests"
swiftc Sources/QingChang/Library.swift Tests/Library/main.swift -o "$test_dir/import-tests"
"$test_dir/import-tests"
if [ "$#" -gt 0 ]; then
 swiftc Sources/QingChang/Library.swift Tests/main.swift -o "$test_dir/library-tests"
 "$test_dir/library-tests" "$1"
fi
