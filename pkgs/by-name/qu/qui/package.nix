{
  lib,
  buildGo126Module,
  fetchFromGitHub,
  stdenvNoCC,
  nixosTests,
  nix-update-script,
  nodejs-slim_26,
  pnpm_11,
  fetchPnpmDeps,
  pnpmConfigHook,
  typescript,
  versionCheckHook,
}:
let
  pnpm = pnpm_11.override {
    # nodejs_24 on Darwin fails to build
    nodejs-slim = nodejs-slim_26;
  };
in
buildGo126Module (finalAttrs: {
  pname = "qui";
  version = "1.19.0";
  src = fetchFromGitHub {
    owner = "autobrr";
    repo = "qui";
    tag = "v${finalAttrs.version}";
    hash = "sha256-h6GmxwOxqh88Zy7tFD/GFQ8NrpBcanFPBXGUmfoIe3I=";
  };

  qui-web = stdenvNoCC.mkDerivation (finalAttrs': {
    pname = "${finalAttrs.pname}-web";
    inherit (finalAttrs) src version;

    nativeBuildInputs = [
      nodejs-slim_26
      pnpmConfigHook
      pnpm
      typescript
    ];

    sourceRoot = "${finalAttrs.src.name}/web";

    pnpmDeps = fetchPnpmDeps {
      inherit (finalAttrs')
        pname
        version
        src
        sourceRoot
        ;
      inherit pnpm;
      fetcherVersion = 3;
      hash = "sha256-OEr5uyMnwP1TkSxRFNaopB9AAx2OVE7lNEzGyQwF6kc=";
    };

    postBuild = ''
      pnpm run build
    '';

    installPhase = ''
      cp -r dist $out
    '';
  });

  vendorHash = "sha256-pkktl+0dBSbUuxZ1ycTV0HZl/wO79LtmNaamyZ+Z9lY=";

  preBuild = ''
    cp -r ${finalAttrs.qui-web}/* web/dist
  '';

  ldflags = [
    "-X github.com/autobrr/qui/internal/buildinfo.Version=${finalAttrs.version}"
    "-X main.PolarOrgID="
  ];

  nativeInstallCheckInputs = [
    versionCheckHook
  ];
  versionCheckProgramArg = "version";
  doInstallCheck = true;

  # Required for tests on Darwin
  __darwinAllowLocalNetworking = true;

  passthru = {
    updateScript = nix-update-script {
      extraArgs = [
        "--subpackage"
        "qui-web"
      ];
    };
    tests.testService = nixosTests.qui;
  };

  meta = {
    description = "Modern alternative webUI for qBittorrent, with multi-instance support";
    license = lib.licenses.gpl2Plus;
    homepage = "https://github.com/autobrr/qui";
    changelog = "https://github.com/autobrr/qui/releases/tag/v${finalAttrs.version}";
    maintainers = with lib.maintainers; [
      pta2002
      tmarkus
    ];
    mainProgram = "qui";
    platforms = lib.platforms.unix;
  };
})
