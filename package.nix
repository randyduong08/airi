{
  lib,
  stdenv,
  stdenvNoCC,
  rustPlatform,

  autoPatchelfHook,
  cargo-tauri,
  pkg-config,
  pnpm,
  wrapGAppsHook3,

  alsa-lib,
  atk,
  cacert,
  glib,
  libayatana-appindicator,
  nodejs,
  onnxruntime,
  openssl,
  webkitgtk_4_1,

  debugBuild ? false,
}:

rustPlatform.buildRustPackage (final: {
  pname = "airi";
  version = "0.7.0-beta.1";

  src = ./.;

  cargoLock.lockFile = ./Cargo.lock;

  pnpmDeps = pnpm.fetchDeps {
    inherit (final) pname version src;
    fetcherVersion = 1;
    hash = "sha256-i4HEZM79g12xzxMDWXyVXWAu4DFnOqtE9aXTEON+uco="; # To update, set it to ""
  };

  # Cache of assets downloaded during vite build
  assets = stdenvNoCC.mkDerivation {
    pname = "${final.pname}-assets";
    inherit (final) version src pnpmDeps;

    nativeBuildInputs = [
      cacert # For network request
      nodejs
      pnpm.configHook
    ];

    buildPhase = ''
      runHook preBuild

      pnpm run build:packages
      pnpm -F @proj-airi/stage-tamagotchi run build

      runHook postBuild
    '';

    installPhase = ''
      runHook preInstall

      mkdir -p $out
      cp -r apps/stage-tamagotchi/.cache/assets $out

      runHook postInstall
    '';

    outputHashMode = "recursive";
    # To update, set it to lib.fakeHash
    outputHash = "sha256-QDGx5sWlWwgMWvG/umkNY+Ct9i5zl+eKEJnvA2whPkY=";
  };

  nativeBuildInputs = [
    cargo-tauri.hook
    nodejs
    pkg-config
    pnpm.configHook
  ]
  ++ lib.optionals stdenv.isLinux [
    wrapGAppsHook3
    autoPatchelfHook
  ];

  buildInputs = [
    glib # Used by glib-sys
    onnxruntime # Used by ort-sys
    openssl # Used by openssl-sys
  ]
  ++ lib.optionals stdenv.isLinux [
    alsa-lib # Used by alsa-sys
    atk # Used by atk-sys
    libayatana-appindicator # Used by libappindicator-sys
    webkitgtk_4_1
  ];

  configurePhase = ''
    runHook preConfigure

    echo Setting up asset cache
    mkdir apps/stage-tamagotchi/.cache
    cp -r $assets/assets apps/stage-tamagotchi/.cache

    runHook postConfigure
  '';

  preBuild = ''
    pnpm run build:packages
  '';

  buildAndTestSubdir = "apps/stage-tamagotchi";
  buildType = if debugBuild then "debug" else "release";

  postInstall =
    lib.optionalString stdenv.isLinux ''
      mv $out/bin/app $out/bin/airi
    ''
    + lib.optionalString stdenv.isDarwin ''
      mkdir -p "$out/bin"
      ln -sf "$out/Applications/AIRI.app/Contents/MacOS/app" "$out/bin/airi"
    '';

  # Add missing runtime dependency
  preFixup = lib.optionalString stdenv.isLinux ''
    patchelf --add-needed libayatana-appindicator3.so.1 $out/bin/airi
  '';

  meta = {
    description = "Self-hostable AI waifu / companion / VTuber";
    longDescription = ''
      AIRI is a container of souls of AI waifu / virtual characters to bring them into our worlds,
      wishing to achieve Neuro-sama's altitude, completely LLM and AI driven, capable of realtime
      voice chat, Minecraft playing, Factorio playing. It can be run in Browser or Desktop.
    '';
    homepage = "https://github.com/moeru-ai/airi";
    changelog = "https://github.com/moeru-ai/airi/releases/tag/v${final.version}";
    # While airi itself is licensed under MIT, it uses the nonfree Cubism SDK. Whether it's
    # redistributable remains a question, so we say it's not.
    license = lib.licenses.unfree;
    platforms = [
      "x86_64-linux"
      "aarch64-linux"
      "x86_64-darwin"
      "aarch64-darwin"
    ];
    mainProgram = "airi";
    maintainers = with lib.maintainers; [ weathercold ];
  };
})
