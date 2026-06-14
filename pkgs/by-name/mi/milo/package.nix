{
  lib,
  stdenv,
  rustPlatform,
  rustc,
  cargo-make,
  pnpm_11,
  pnpmConfigHook,
  fetchPnpmDeps,
  cargo,
  rust-cbindgen,
  nodejs-slim_26,
  fetchFromGitHub,
  nix-update-script,
  testers,
  pkg-config,
  validatePkgConfig,
  fetchpatch2,
}:

let
  nodejs-slim = nodejs-slim_26;
  pnpm = pnpm_11.override {
    inherit nodejs-slim;
  };
in
stdenv.mkDerivation (finalAttrs: {
  pname = "milo";
  version = "0.6.0";

  src = fetchFromGitHub {
    owner = "ShogunPanda";
    repo = "milo";
    tag = "v${finalAttrs.version}";
    hash = "sha256-ZsB2HAg1uBognSSew0iKeVEJKHJQY3rzxORSkoSGhz4=";
  };

  patches = [
    (fetchpatch2 {
      url = "https://github.com/ShogunPanda/milo/pull/17.patch";
      hash = "sha256-CqHukUzMRjzzbGbs/1YVCRrYffQtTNsLAPVQHPk47Wc=";
    })
    (fetchpatch2 {
      url = "https://github.com/ShogunPanda/milo/pull/18.patch";
      hash = "sha256-RQ1PUiiN2evGjWTJD+mTZUNU0s5hWN9oRq8YO49NUEg=";
    })
  ];

  pnpmDeps = fetchPnpmDeps {
    inherit (finalAttrs) pname version src;
    inherit pnpm;
    fetcherVersion = 4;
    hash = "sha256-gp6i175r+GAMhf2pPP6dfdx4RN868fLduCD0/FkdnpM=";
  };

  cargoRoot = "parser";
  buildAndTestSubdir = "parser";
  cargoBuildType = "release";
  cargoDeps = rustPlatform.fetchCargoVendor {
    inherit (finalAttrs)
      pname
      version
      src
      cargoRoot
      ;
    hash = "sha256-PcG4G7SYQhz73shhtLRQnUJ97hnHSPvRTKE/VzM53PI=";
  };

  __structuredAttrs = true;
  strictDeps = true;

  nativeBuildInputs = [
    cargo
    rustPlatform.cargoSetupHook
    rustPlatform.cargoBuildHook
    rustPlatform.cargoInstallHook
    rustc
    cargo-make
    rust-cbindgen
    nodejs-slim
    pnpm
    pnpmConfigHook
    validatePkgConfig
  ];

  postPatch = lib.optionalString (stdenv.hostPlatform.isStatic) ''
    substituteInPlace parser/Cargo.toml --replace-fail '"cdylib",' ""
  '';

  postBuild = ''
    makers --cwd parser cpp:headers
    mkdir -p dist/cpp/release
    cp parser/target/headers/milo.h dist/cpp/release/.
    node scripts/postbuild-cpp.js release
  '';

  postInstall = ''
    install -Dm644 -t $out/include \
      dist/cpp/release/*.h

    mkdir $out/lib/pkgconfig
    cat -> $out/lib/pkgconfig/milo_parser.pc <<EOF
    prefix=$out
    exec_prefix=\''${prefix}
    libdir=\''${exec_prefix}/lib
    includedir=\''${prefix}/include

    Name: milo_parser
    Description: ${finalAttrs.meta.description}
    Version: ${finalAttrs.version}
    Libs: -L\''${libdir} -lmilo_parser
    Cflags: -I\''${includedir}
    EOF
  '';

  doInstallCheck = true;
  nativeInstallCheckInputs = [
    stdenv.cc
    pkg-config
  ];
  installCheckPhase = ''
    runHook preInstallCheck

    FLAGS=$(PKG_CONFIG_PATH="$out/lib/pkgconfig" pkg-config --cflags --libs milo_parser)
    c++ $FLAGS references/cpp/src/main.cc -o cpp_test
    ./cpp_test

    runHook postInstallCheck
  '';

  passthru.tests = {
    pkg-config = testers.hasPkgConfigModules {
      package = finalAttrs.finalPackage;
    };
    updateScript = nix-update-script { };
  };

  meta = {
    description = "Fast and embeddable HTTP/1.1 parser";
    homepage = "https://github.com/ShogunPanda/milo";
    changelog = "https://github.com/ShogunPanda/milo/blob/${finalAttrs.src.rev}/CHANGELOG.md";
    license = lib.licenses.isc;
    maintainers = with lib.maintainers; [ aduh95 ];
    pkgConfigModules = [ "milo_parser" ];
    mainProgram = "milo_parser";
  };
})
