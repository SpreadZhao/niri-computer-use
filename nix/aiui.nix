{
  lib,
  stdenvNoCC,
  makeWrapper,
  python3,
  niri,
  grim,
  wtype,
  ydotool,
  xdotool,
  fuzzel,
  libnotify,
  procps,
  foot,
  jq,
}:

stdenvNoCC.mkDerivation {
  pname = "niri-computer-use-aiui";
  version = lib.removeSuffix "\n" (builtins.readFile ../VERSION);

  src = ../overlay/spreadconfig/scripts/default/aiui;

  nativeBuildInputs = [ makeWrapper ];

  dontConfigure = true;
  dontBuild = true;

  installPhase = ''
    runHook preInstall

    install -Dm755 aiui "$out/libexec/aiui/aiui"
    install -Dm644 policy.json "$out/libexec/aiui/policy.json"

    makeWrapper ${python3}/bin/python3 "$out/bin/aiui" \
      --add-flags "$out/libexec/aiui/aiui" \
      --prefix PATH : ${
        lib.makeBinPath [
          niri
          grim
          wtype
          ydotool
          xdotool
          fuzzel
          libnotify
          procps
          foot
          jq
        ]
      }

    runHook postInstall
  '';

  meta = {
    description = "Audited Niri/Wayland computer-use control surface";
    mainProgram = "aiui";
    platforms = lib.platforms.linux;
  };
}
