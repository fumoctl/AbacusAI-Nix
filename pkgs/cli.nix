{
  lib,
  stdenv,
  fetchurl,
}:
let
  pname = "abacusai-cli";

  versions = builtins.fromJSON (builtins.readFile ../artifacts/versions.json);
  system = stdenv.hostPlatform.system;

  platformInfo = versions."AbacusAI CLI".${system} or (throw "Unsupported system for AbacusAI CLI: ${system}");

  # Extract version from URL
  version = let
    match = builtins.match ".*/releases/([0-9.]+)/.*" platformInfo.url;
  in if match != null then builtins.elemAt match 0 else "unknown";
in
stdenv.mkDerivation {
  inherit pname version;

  src = fetchurl {
    inherit (platformInfo) url;
    sha256 = platformInfo.hash;
  };

  # We do not use autoPatchelfHook here because it modifies the ELF structure
  # and shifts sections, which corrupts the Bun-appended JS payload offset.
  # Instead, we run the raw binary via the target system's dynamic interpreter.
  nativeBuildInputs = [];

  sourceRoot = ".";

  dontBuild = true;
  dontConfigure = true;
  dontStrip = true;
  dontPatchELF = true;

  installPhase = ''
    runHook preInstall

    # Install the unwrapped binary
    mkdir -p $out/libexec
    cp abacusai $out/libexec/abacusai
    chmod +x $out/libexec/abacusai

    # Generate a wrapper that invokes the interpreter directly
    mkdir -p $out/bin
    cat <<EOF > $out/bin/abacusai
#!/bin/sh
exec ${stdenv.cc.bintools.dynamicLinker} --library-path "${lib.makeLibraryPath [ stdenv.cc.libc stdenv.cc.cc.lib ]}" $out/libexec/abacusai "\$@"
EOF
    chmod +x $out/bin/abacusai

    runHook postInstall
  '';

  meta = with lib; {
    description = "AbacusAI CLI - Command line interface for Abacus AI";
    homepage = "https://static.abacus.ai/cli/install.sh";
    license = licenses.unfree;
    platforms = [ "x86_64-linux" "aarch64-linux" ];
    mainProgram = "abacusai";
  };
}
