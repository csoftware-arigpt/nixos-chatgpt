#!/usr/bin/env bash
set -euo pipefail

usage="usage: package-smoke.sh PACKAGE_PATH EXPECTED_VERSION EXPECTED_TECTONIC_VERSION"
package=${1:?"$usage"}
expected_version=${2:?"$usage"}
expected_tectonic_version=${3:?"$usage"}
tectonic="$package/lib/chatgpt/resources/plugins/openai-bundled/plugins/latex/bin/tectonic"
app_asar="$package/lib/chatgpt/resources/app.asar"

test -x "$package/bin/chatgpt"
test -x "$package/lib/chatgpt/ChatGPT"
test -x "$tectonic"
test -f "$package/share/applications/chatgpt.desktop"
test -f "$package/share/pixmaps/chatgpt.png"
grep -aFq -- '-xdg-open/bin' "$package/lib/chatgpt/ChatGPT"
grep -aFq "const family='glibc'/*nix*/;" "$app_asar"
if grep -aFq "const family = familySync();" "$app_asar"; then
  exit 1
fi

grep -Fqx "Exec=$package/bin/chatgpt %U" \
  "$package/share/applications/chatgpt.desktop"
desktop-file-validate "$package/share/applications/chatgpt.desktop"

for binary in \
  "$package/lib/chatgpt/ChatGPT" \
  "$package/lib/chatgpt/.ChatGPT-wrapped"; do
  interpreter=$(patchelf --print-interpreter "$binary")
  [[ $interpreter == /nix/store/*/lib/ld-linux-x86-64.so.2 ]]
  patchelf --print-rpath "$binary" | grep -q /nix/store/
done

test_home=$(mktemp -d)
[[ $(HOME="$test_home" XDG_DATA_HOME="$test_home/share" \
  "$package/bin/chatgpt" --version) == "$expected_version" ]]
test -L "$test_home/share/applications/chatgpt.desktop"
grep -Fq 'x-scheme-handler/codex=chatgpt.desktop;' \
  "$test_home/share/applications/mimeinfo.cache"
[[ $("$tectonic" --version) == "Tectonic $expected_tectonic_version" ]]
