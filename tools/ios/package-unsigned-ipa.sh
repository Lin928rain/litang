#!/usr/bin/env bash
set -euo pipefail

# Run on macOS after `flutter build ios --release --no-codesign`.
repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
app_path="${1:-$repo_root/build/ios/iphoneos/Runner.app}"
output_dir="$repo_root/build/ios-ipa"

if [[ "$(uname -s)" != Darwin ]]; then
  echo 'Packaging requires macOS (ditto and Apple toolchain).' >&2
  exit 1
fi
if [[ ! -d "$app_path" || ! -f "$app_path/Info.plist" ]]; then
  echo "Device application bundle missing: $app_path" >&2
  exit 1
fi

plist_value() { /usr/libexec/PlistBuddy -c "Print :$1" "$app_path/Info.plist"; }
executable="$(plist_value CFBundleExecutable)"
platform="$(plist_value DTPlatformName)"
version="$(plist_value CFBundleShortVersionString)"
build_number="$(plist_value CFBundleVersion)"
bundle_id="$(plist_value CFBundleIdentifier)"
if [[ "$platform" != iphoneos ]]; then
  echo 'Refusing to package a simulator application as a device IPA.' >&2
  exit 1
fi
if [[ ! -f "$app_path/$executable" || ! -f "$app_path/Frameworks/App.framework/App" ]]; then
  echo 'Incomplete Flutter device bundle.' >&2
  exit 1
fi
if ! xcrun lipo -archs "$app_path/$executable" | grep -qw arm64; then
  echo 'The app executable must contain an arm64 device slice.' >&2
  exit 1
fi
# Version values are also used in filenames.
if [[ ! "$version" =~ ^[0-9]+(\.[0-9]+)*$ || ! "$build_number" =~ ^[0-9]+(\.[0-9]+)*$ ]]; then
  echo 'Unexpected bundle version format.' >&2
  exit 1
fi

mkdir -p "$output_dir"
staging="$(mktemp -d "${TMPDIR:-/tmp}/litang-ipa.XXXXXX")"
# mktemp above creates the exact directory removed by this trap.
trap 'rm -rf -- "$staging"' EXIT
mkdir -p "$staging/Payload"
ditto "$app_path" "$staging/Payload/Runner.app"
artifact="litang-ios-${version}-${build_number}-unsigned.ipa"
ditto -c -k --norsrc --keepParent "$staging/Payload" "$output_dir/$artifact"

(
  cd "$output_dir"
  shasum -a 256 "$artifact" > "$artifact.sha256"
)
export LITANG_IPA_PATH="$output_dir/$artifact"
export LITANG_BUNDLE_ID="$bundle_id"
python3 - "$repo_root" "$output_dir/build-info.json" <<'PY'
import hashlib
import json
import os
import pathlib
import subprocess
import sys

root, destination = sys.argv[1:]
def command(*args):
    return subprocess.check_output(args, cwd=root, text=True).strip()
artifact = pathlib.Path(os.environ['LITANG_IPA_PATH'])
with artifact.open('rb') as stream:
    digest = hashlib.sha256()
    for chunk in iter(lambda: stream.read(1024 * 1024), b''):
        digest.update(chunk)
    checksum = digest.hexdigest()
info = {
    'artifact': artifact.name,
    'signed': False,
    'platform': 'iphoneos',
    'bundleId': os.environ['LITANG_BUNDLE_ID'],
    'sha256': checksum,
    'commit': command('git', 'rev-parse', 'HEAD'),
    'flutter': json.loads(command('flutter', '--version', '--machine')),
    'xcode': command('xcodebuild', '-version'),
    'workflowRun': os.environ.get('GITHUB_RUN_ID'),
}
pathlib.Path(destination).write_text(json.dumps(info, ensure_ascii=False, indent=2) + '\n')
PY
echo "Created $output_dir/$artifact (unsigned; personal re-signing required)."
