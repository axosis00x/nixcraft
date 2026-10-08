{ appimageTools, fetchurl }:

# Helium browser, packaged from the official AppImage (it isn't in nixpkgs).
# To update: bump `version`, then refresh `hash` with
#   nix store prefetch-file <url>
let
  pname = "helium";
  version = "0.18.3.1";

  src = fetchurl {
    url = "https://github.com/imputnet/helium-linux/releases/download/${version}/helium-${version}-x86_64.AppImage";
    hash = "sha256-xDrhTCq3FVWz/kC9Al3wBPcLxHlalhoaOlaXn6G4uYA=";
  };

  contents = appimageTools.extract { inherit pname version src; };
in
appimageTools.wrapType2 {
  inherit pname version src;

  # Ship the AppImage's own desktop entry and icon so Helium shows up in the
  # launcher, pointed at the wrapped binary.
  extraInstallCommands = ''
    desktop=$(find ${contents} -maxdepth 1 -name '*.desktop' | head -n1)
    if [ -n "$desktop" ]; then
      install -Dm444 "$desktop" $out/share/applications/helium.desktop
      substituteInPlace $out/share/applications/helium.desktop \
        --replace-quiet 'Exec=AppRun' 'Exec=${pname}'
      sed -i -E 's|^Exec=[^ ]+|Exec=${pname}|' $out/share/applications/helium.desktop
    fi
    if [ -d ${contents}/usr/share/icons ]; then
      mkdir -p $out/share
      cp -r ${contents}/usr/share/icons $out/share/
    else
      icon=$(find ${contents} -maxdepth 1 -name '*.png' | head -n1)
      [ -n "$icon" ] && install -Dm444 "$icon" $out/share/icons/hicolor/256x256/apps/helium.png
    fi
  '';
}
