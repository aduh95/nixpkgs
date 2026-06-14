{
  lib,
  stdenv,
  fetchFromGitHub,
  rustPlatform,
  rust-cbindgen,
  nix-update-script,
  testers,
  pkg-config,
  validatePkgConfig,
  fetchurl,
  fetchpatch2,
}:

rustPlatform.buildRustPackage (finalAttrs: {
  pname = "milo";
  version = "0.6.0";

  src = fetchFromGitHub {
    owner = "ShogunPanda";
    repo = "milo";
    tag = "v${finalAttrs.version}";
    hash = "sha256-ZsB2HAg1uBognSSew0iKeVEJKHJQY3rzxORSkoSGhz4=";
  };

  prePatch = "cp ${
    fetchurl {
      url = "https://github.com/ShogunPanda/milo/raw/1c28b75424d3918d8d0e31905e6dea1a45876597/scripts/postbuild-cpp.sh";
      hash = "sha256-jnR+Q9WpwWRB6YIr6uO1FYHTwifuoxeinWDfnXFBy7s=";
    }
  } scripts/postbuild-cpp.sh";
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

  cargoRoot = "parser";
  buildAndTestSubdir = "parser";
  cargoHash = "sha256-PcG4G7SYQhz73shhtLRQnUJ97hnHSPvRTKE/VzM53PI=";

  nativeBuildInputs = [
    rust-cbindgen
    validatePkgConfig
  ];

  postPatch = lib.optionalString (stdenv.hostPlatform.isStatic) ''
    substituteInPlace parser/Cargo.toml --replace-fail '"cdylib",' ""
  '';

  postBuild = ''
    bash scripts/postbuild-cpp.sh $out/include/milo.h
  '';

  postInstall = ''
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

  doCheck = true;
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
