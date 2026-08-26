{
  lib,
  stdenv,
  asar,
  fetchurl,
  addDriverRunpath,
  alsa-lib,
  atk,
  at-spi2-atk,
  at-spi2-core,
  autoPatchelfHook,
  cairo,
  cups,
  dbus,
  dpkg,
  expat,
  fontconfig,
  freetype,
  gdk-pixbuf,
  glib,
  graphite2,
  gtk3,
  libdrm,
  libgbm,
  libglvnd,
  libnotify,
  libsecret,
  libusb1,
  libx11,
  libxcb,
  libxcomposite,
  libxdamage,
  libxext,
  libxfixes,
  libxkbcommon,
  libxrandr,
  makeWrapper,
  nspr,
  nss,
  pango,
  qt5,
  qt6,
  systemd,
  tectonic-unwrapped,
  wrapGAppsHook3,
  xdg-utils,
}:

let
  source = import ./sources.nix;

  runtimeLibraries = [
    alsa-lib
    atk
    at-spi2-atk
    at-spi2-core
    cairo
    cups
    dbus
    expat
    fontconfig
    freetype
    gdk-pixbuf
    glib
    graphite2
    gtk3
    libdrm
    libgbm
    libglvnd
    libnotify
    libsecret
    libusb1
    libx11
    libxcb
    libxcomposite
    libxdamage
    libxext
    libxfixes
    libxkbcommon
    libxrandr
    nspr
    nss
    pango
    (lib.getLib qt5.qtbase)
    (lib.getLib qt6.qtbase)
    (lib.getLib stdenv.cc.cc)
    (lib.getLib systemd)
  ];
in
stdenv.mkDerivation (finalAttrs: {
  pname = "chatgpt";
  inherit (source) version;

  src = fetchurl {
    name = "chatgpt_${finalAttrs.version}_amd64.deb";
    inherit (source) url hash;
  };

  strictDeps = true;

  nativeBuildInputs = [
    autoPatchelfHook
    asar
    dpkg
    makeWrapper
    wrapGAppsHook3
  ];

  buildInputs = runtimeLibraries;

  runtimeDependencies = [
    (lib.getLib systemd)
  ];

  autoPatchelfIgnoreMissingDeps = [
    "libc.musl-x86_64.so.1"
  ];

  dontConfigure = true;
  dontBuild = true;
  dontStrip = true;
  dontWrapGApps = true;

  unpackPhase = ''
    runHook preUnpack

    dpkg-deb --fsys-tarfile "$src" | tar --extract

    runHook postUnpack
  '';

  installPhase = ''
    runHook preInstall

    mkdir -p "$out/bin"
    cp -a usr/lib usr/share "$out/"
    ln -s ../lib/chatgpt/codex-launcher "$out/bin/chatgpt"

    # patchelf moves PT_INTERP beyond detect-libc's 2 KiB probe, which makes
    # @parcel/watcher call process.report.getReport() and trip Electron's CFI.
    app_asar="$out/lib/chatgpt/resources/app.asar"
    (
      cd "$(mktemp -d)"
      asar extract-file "$app_asar" node_modules/@parcel/watcher/index.js
      old_hash=$(sha256sum index.js | cut -d ' ' -f 1)
      sed -i "s/const family = familySync();/const family='glibc'\/\*nix\*\/;/" index.js
      new_hash=$(sha256sum index.js | cut -d ' ' -f 1)
      grep -aFq "$old_hash" "$app_asar"
      sed -i \
        -e "s/const family = familySync();/const family='glibc'\/\*nix\*\/;/" \
        -e "s/$old_hash/$new_hash/g" \
        "$app_asar"
    )

    # The bundled Tectonic has a malformed ELF section table, so patchelf
    # cannot make it runnable on NixOS. Nixpkgs provides the same release.
    rm "$out/lib/chatgpt/resources/plugins/openai-bundled/plugins/latex/bin/tectonic"
    ln -s "${tectonic-unwrapped}/bin/tectonic" \
      "$out/lib/chatgpt/resources/plugins/openai-bundled/plugins/latex/bin/tectonic"

    substituteInPlace "$out/share/applications/chatgpt.desktop" \
      --replace-fail "Exec=chatgpt %U" "Exec=$out/bin/chatgpt %U"

    runHook postInstall
  '';

  postFixup = ''
    wrapProgram "$out/lib/chatgpt/ChatGPT" \
      "''${gappsWrapperArgs[@]}" \
      --prefix LD_LIBRARY_PATH : "${lib.makeLibraryPath runtimeLibraries}:${addDriverRunpath.driverLink}/lib" \
      --prefix PATH : "${lib.makeBinPath [ xdg-utils ]}" \
      --prefix XDG_DATA_DIRS : "${addDriverRunpath.driverLink}/share"
  '';

  meta = {
    description = "Official ChatGPT desktop application packaged for NixOS";
    homepage = "https://chatgpt.com/";
    downloadPage = source.url;
    license = lib.licenses.unfree;
    mainProgram = "chatgpt";
    platforms = [ "x86_64-linux" ];
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
  };
})
