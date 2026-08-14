# ChatGPT for NixOS: design

## Goal

Package OpenAI's official x86_64 Linux `.deb` so it can be installed with
`nix profile`, launched as `chatgpt`, and updated automatically when the
official `latest` download changes.

## Approach

The package directly extracts the official archive and uses Nixpkgs'
`autoPatchelfHook` to bind its dynamically linked executables to Nix store
libraries. This is preferable to an FHS container because it produces a normal
profile package, avoids a runtime sandbox, and keeps dependency resolution
visible in the derivation.

The upstream URL is mutable, so `sources.nix` pins both the Debian package
version and its SHA-256 hash. A scheduled GitHub workflow checks the same
official URL every six hours, updates the pin, builds the package, and commits
only a successfully verified update.

## Supported platform

- `x86_64-linux` only, matching the architecture published by OpenAI at the
  supplied official URL.

## Verification

- Nix evaluation and build succeed.
- The profile output contains the launcher, desktop entry, and icon.
- The main executable uses a Nix store ELF interpreter.
- The bundled malformed Tectonic helper is replaced with the same Tectonic
  release from Nixpkgs and executes successfully.
- The desktop entry is valid and points to the packaged launcher.
- The update script rejects unexpected package names or architectures.
