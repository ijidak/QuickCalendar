#!/bin/zsh
set -euo pipefail

script_dir=${0:A:h}
build_dir="$script_dir/build"
app_dir="$build_dir/Quick Calendar.app"
contents_dir="$app_dir/Contents"
output_dir="${OUTPUT_DIR:-$script_dir/dist}"
module_cache="$script_dir/.module-cache"
sdk_path="${SDK_PATH:-$(xcrun --show-sdk-path --sdk macosx 2>/dev/null || true)}"

if [[ -z "$sdk_path" || ! -d "$sdk_path" ]]; then
  print -u2 "error: could not locate the macOS SDK."
  print -u2 "Install the Xcode Command Line Tools with 'xcode-select --install',"
  print -u2 "or set SDK_PATH to an SDK directory."
  exit 1
fi

rm -rf "$build_dir"
mkdir -p "$contents_dir/MacOS" "$contents_dir/Resources" "$build_dir/AppIcon.iconset" "$module_cache" "$output_dir"

swiftc -sdk "$sdk_path" -target arm64-apple-macosx13.0 -module-cache-path "$module_cache" -O -framework AppKit \
  "$script_dir/Sources/main.swift" \
  -o "$contents_dir/MacOS/QuickCalendar"

cp "$script_dir/Info.plist" "$contents_dir/Info.plist"

swift -sdk "$sdk_path" -module-cache-path "$module_cache" "$script_dir/Sources/IconMaker.swift" "$build_dir/AppIcon-1024.png"
for icon_size in 16 32 128 256 512; do
  sips -z "$icon_size" "$icon_size" "$build_dir/AppIcon-1024.png" --out "$build_dir/AppIcon.iconset/icon_${icon_size}x${icon_size}.png" >/dev/null
  retina_size=$((icon_size * 2))
  sips -z "$retina_size" "$retina_size" "$build_dir/AppIcon-1024.png" --out "$build_dir/AppIcon.iconset/icon_${icon_size}x${icon_size}@2x.png" >/dev/null
done
swift -sdk "$sdk_path" -module-cache-path "$module_cache" "$script_dir/Sources/ICNSMaker.swift" \
  "$build_dir/AppIcon.iconset" "$contents_dir/Resources/AppIcon.icns"

codesign --force --deep --sign - "$app_dir"

rm -f "$output_dir/Quick Calendar.dmg" "$output_dir/Quick Calendar.zip"
if hdiutil create -volname "Quick Calendar" -srcfolder "$app_dir" -ov -format UDZO "$output_dir/Quick Calendar.dmg" >/dev/null 2>&1; then
  echo "$output_dir/Quick Calendar.dmg"
elif mkdir -p "$build_dir/dmg-root" && ditto "$app_dir" "$build_dir/dmg-root/Quick Calendar.app" && \
  hdiutil makehybrid -hfs -hfs-volume-name "Quick Calendar" -o "$output_dir/Quick Calendar.dmg" "$build_dir/dmg-root" >/dev/null 2>&1; then
  echo "$output_dir/Quick Calendar.dmg"
else
  ditto -c -k --sequesterRsrc --keepParent "$app_dir" "$output_dir/Quick Calendar.zip"
  echo "$output_dir/Quick Calendar.zip"
fi
