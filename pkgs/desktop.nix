{
  lib,
  stdenv,
  fetchurl,
  appimageTools,
  makeDesktopItem,
}:
let
  pname = "abacusai-desktop";

  versions = builtins.fromJSON (builtins.readFile ../artifacts/versions.json);
  system = stdenv.hostPlatform.system;

  platformInfo = versions."AbacusAI Desktop".${system} or (throw "Unsupported system for AbacusAI Desktop: ${system}");

  version = let
    match = builtins.match ".*/download/([0-9.]+)/.*" platformInfo.url;
  in if match != null then builtins.elemAt match 0 else "unknown";

  src = fetchurl {
    inherit (platformInfo) url;
    sha256 = platformInfo.hash;
  };

  appimageContents = appimageTools.extractType2 {
    inherit pname version src;
  };

  desktopItem = makeDesktopItem {
    name = "abacusai-desktop";
    exec = "abacusai-desktop %U";
    icon = "abacusai-desktop";
    desktopName = "AbacusAI Desktop";
    comment = "AbacusAI Desktop Application";
    categories = [ "Utility" "Development" ];
    startupWMClass = "AbacusAI Desktop";
    mimeTypes = [ "x-scheme-handler/abacusai" ];
  };
in
appimageTools.wrapType2 {
  inherit pname version src;

  extraInstallCommands = ''
    # Install icons extracted by extractType2
    mkdir -p $out/share
    if [ -d ${appimageContents}/usr/share/icons ]; then
      cp -r ${appimageContents}/usr/share/icons $out/share/
    fi

    # Fallback pixmap icon
    if [ -f ${appimageContents}/abacusai-desktop.png ]; then
      mkdir -p $out/share/pixmaps
      cp ${appimageContents}/abacusai-desktop.png $out/share/pixmaps/abacusai-desktop.png
    fi

    # Install the desktop file
    mkdir -p $out/share/applications
    cp ${desktopItem}/share/applications/*.desktop $out/share/applications/
  '';

  meta = with lib; {
    description = "AbacusAI Desktop Application";
    homepage = "https://github.com/abacusai/deepagent-releases";
    license = licenses.unfree;
    platforms = [ "x86_64-linux" "aarch64-linux" ];
    mainProgram = "abacusai-desktop";
  };
}
