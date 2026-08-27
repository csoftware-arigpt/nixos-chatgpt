#!/usr/bin/env bash
set -euo pipefail

readonly source_url="https://persistent.oaistatic.com/codex-app-prod/linux/deb/latest/chatgpt_amd64.deb"
repository_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly repository_root
temporary_directory="$(mktemp -d)"
readonly temporary_directory
readonly deb="$temporary_directory/chatgpt_amd64.deb"

cleanup() {
  rm -rf "$temporary_directory"
}
trap cleanup EXIT

curl --fail --location --retry 3 --silent --show-error --output "$deb" "$source_url"

package=$(dpkg-deb --field "$deb" Package)
version=$(dpkg-deb --field "$deb" Version)
architecture=$(dpkg-deb --field "$deb" Architecture)

[[ $package == chatgpt ]] || {
  printf 'unexpected Debian package: %s\n' "$package" >&2
  exit 1
}
[[ $architecture == amd64 ]] || {
  printf 'unexpected Debian architecture: %s\n' "$architecture" >&2
  exit 1
}
[[ $version =~ ^[0-9]+([.][0-9]+)+$ ]] || {
  printf 'unexpected Debian version: %s\n' "$version" >&2
  exit 1
}

hash=$(nix hash file --type sha256 "$deb")
new_source="$temporary_directory/sources.nix"
new_readme="$temporary_directory/README.md"

cat >"$new_source" <<EOF
{
  version = "$version";
  url = "$source_url";
  hash = "$hash";
}
EOF

if cmp --silent "$new_source" "$repository_root/sources.nix"; then
  updated_at=$(sed -n "s/^Last package update: \`\\(.*\\)\`\\.\$/\\1/p" \
    "$repository_root/README.md")
  [[ -n $updated_at ]] || updated_at=$(date -u +'%Y-%m-%dT%H:%M:%SZ')
else
  updated_at=$(date -u +'%Y-%m-%dT%H:%M:%SZ')
fi

awk -v version="$version" -v updated_at="$updated_at" '
  /^Current packaged version:/ {
    print "Current packaged version: `" version "`."
    print "Last package update: `" updated_at "`."
    next
  }
  /^Last package update:/ { next }
  { print }
' "$repository_root/README.md" >"$new_readme"

if cmp --silent "$new_source" "$repository_root/sources.nix" \
  && cmp --silent "$new_readme" "$repository_root/README.md"; then
  printf 'ChatGPT %s is already pinned.\n' "$version"
  exit 0
fi

mv "$new_source" "$repository_root/sources.nix"
mv "$new_readme" "$repository_root/README.md"
printf 'Pinned ChatGPT %s (%s).\n' "$version" "$hash"
