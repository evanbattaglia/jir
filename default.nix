{ lib, makeWrapper, httpie, gopass, pass, callPackage, ... }:
let
  ruby-utils = callPackage ./nix/utils/ruby-utils.nix {};
in ruby-utils.mkSourcesPkg {
  name = "jir";
  gemdir = ./.;
  src = ./.;
  buildInputs = [makeWrapper];
  installPhase = ''
    mkdir -p $out
    cp -R ./nix/bin $out/bin/
    cp -R ./lib $out
    cp -R ./tabry $out

    wrapProgram $out/bin/jir \
      --set PATH ${lib.makeBinPath [
        httpie
        gopass
        pass
      ]}
'';
}
