{ python ? "python3.7" }:
let
  pkgs = import ./nix;
  drv =
    { poetry2nix
    , python
    , lib
    , sqlite
    , stdenv
    }:

    poetry2nix.mkPoetryApplication {
      inherit python;

      pyproject = ./pyproject.toml;
      poetrylock = ./poetry.lock;
      src = lib.cleanSource ./.;

      buildInputs = [ sqlite ];

      overrides = pkgs.poetry2nix.overrides.withDefaults (_: super: {
        llvmlite = super.llvmlite.overridePythonAttrs (_: {
          preConfigure = ''
            export LLVM_CONFIG=${pkgs.llvm.dev}/bin/llvm-config
          '';
        });
      });

      checkPhase = ''
        runHook preCheck
        pytest --benchmark-disable
        runHook postCheck
      '';
      # pytestCheckHook fails due to colliding versions of pytest and its
      # transitive dependencies
      pytestFlags = [ "--benchmark-disable" ];

      # see https://github.com/nix-community/poetry2nix/issues/244
      # the newer wheel generated by pipInstallPhase are incompatible
      # with the version of pip that poetry2nix pins
      # poetry2nix pins pip because of an upstream failure in nixpkgs
      # caused by a newer version of pip failing to find dependencies
      preInstall = lib.optionalString stdenv.isLinux ''
        mv ./dist/*.whl $(echo ./dist/*.whl | sed s/'manylinux_[0-9]*_[0-9]*'/'manylinux2014'/)
      '';

      pythonImportsCheck = [ "slumba" ];
    };
in
pkgs.callPackage drv {
  python = pkgs.${builtins.replaceStrings [ "." ] [ "" ] python};
}