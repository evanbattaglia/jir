{ruby, bundlerEnv, stdenv, ...}:
  let
    defaultInstallPhase = ''
      mkdir -p $out
      cp -R ./* $out
    '';

    # This function takes some ruby configurations and returns a derivation which
    #   contains a symlink to the `bin/{name}` file, with the actual sources
    #   in an underlying derivation, so they're not exposed.
    mkSourcesPkg = {gemdir, src, name, dontPatchShebangs ? false, patches ? [], buildInputs ? [], installPhase ? defaultInstallPhase}:
      let
        gems = bundlerEnv {
          name = "${name}-env";
          inherit ruby gemdir;
        };
        sources = stdenv.mkDerivation {
          name = "${name}-sources";
          inherit installPhase src patches dontPatchShebangs;
          buildInputs = [gems gems.wrappedRuby] ++ buildInputs;
        };
      in stdenv.mkDerivation {
        inherit name;
        dontUnpack = true;
        installPhase = ''
          mkdir -p $out/bin
          ln -s ${sources}/bin/${name} $out/bin/${name}
        '';
      };
in {
  inherit mkSourcesPkg;
}
