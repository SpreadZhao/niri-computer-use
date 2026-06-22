#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR="${PROJECT_DIR:-/home/spreadzhao/workspaces/niri-computer-use-spreadconfig-v2}"
SPREADCONFIG="${SPREADCONFIG:-/home/spreadzhao/workspaces/spreadconfig}"
GITHUB_OWNER="${GITHUB_OWNER:-SpreadZhao}"
REPO_NAME="${REPO_NAME:-niri-computer-use-spreadconfig-v2}"
VISIBILITY="${VISIBILITY:-public}" # public or private
BRANCH="${BRANCH:-main}"
INPUT_URL="${INPUT_URL:-github:${GITHUB_OWNER}/${REPO_NAME}}"
REMOTE_URL="https://github.com/${GITHUB_OWNER}/${REPO_NAME}.git"
HOSTS="${HOSTS:-}"
RUN_SWITCH="${RUN_SWITCH:-0}"
SKIP_PUSH="${SKIP_PUSH:-0}"

die() {
  printf 'error: %s\n' "$*" >&2
  exit 1
}

need_cmd() {
  command -v "$1" >/dev/null 2>&1 || die "missing command: $1"
}

run_python() {
  if command -v python3 >/dev/null 2>&1; then
    python3 "$@"
  else
    nix shell nixpkgs#python3 -c python3 "$@"
  fi
}

ensure_clean_spreadconfig() {
  local dirty
  dirty="$(git -C "$SPREADCONFIG" status --short -- flake.nix flake.lock)"
  if [[ -n "$dirty" ]]; then
    printf '%s\n' "$dirty" >&2
    die "spreadconfig flake.nix/flake.lock already have changes; commit, stash, or review them first"
  fi
}

make_project_git_command() {
  if git -C "$PROJECT_DIR" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    PROJECT_GIT=(git -C "$PROJECT_DIR")
  else
    TEMP_GIT_DIR="$(mktemp -d -t niri-computer-use-git.XXXXXX)"
    git --git-dir="$TEMP_GIT_DIR" --work-tree="$PROJECT_DIR" init --initial-branch="$BRANCH" >/dev/null
    PROJECT_GIT=(git --git-dir="$TEMP_GIT_DIR" --work-tree="$PROJECT_DIR")
  fi
}

commit_project() {
  "${PROJECT_GIT[@]}" add \
    CHANGES.md \
    README.md \
    TESTS.md \
    VERSION \
    flake.lock \
    flake.nix \
    nix \
    overlay \
    push-and-install.sh \
    tools \
    verify.sh

  if "${PROJECT_GIT[@]}" diff --cached --quiet; then
    printf 'Project git index has no changes to commit.\n'
  else
    "${PROJECT_GIT[@]}" commit -m "Package Niri computer use as a flake"
  fi
}

push_project() {
  [[ "$SKIP_PUSH" == "1" ]] && {
    printf 'Skipping GitHub push because SKIP_PUSH=1.\n'
    return
  }

  need_cmd gh
  gh auth status >/dev/null || gh auth login
  gh auth setup-git >/dev/null

  if gh repo view "${GITHUB_OWNER}/${REPO_NAME}" >/dev/null 2>&1; then
    printf 'GitHub repository already exists: %s/%s\n' "$GITHUB_OWNER" "$REPO_NAME"
  else
    case "$VISIBILITY" in
      public) gh repo create "${GITHUB_OWNER}/${REPO_NAME}" --public --description "Audited Niri computer-use runtime packaged as a Nix flake" ;;
      private) gh repo create "${GITHUB_OWNER}/${REPO_NAME}" --private --description "Audited Niri computer-use runtime packaged as a Nix flake" ;;
      *) die "VISIBILITY must be public or private" ;;
    esac
  fi

  if git ls-remote --heads "$REMOTE_URL" "$BRANCH" | grep -q "refs/heads/${BRANCH}$"; then
    die "remote branch ${BRANCH} already exists at ${REMOTE_URL}; refusing to overwrite it"
  fi

  "${PROJECT_GIT[@]}" remote remove origin >/dev/null 2>&1 || true
  "${PROJECT_GIT[@]}" remote add origin "$REMOTE_URL"
  "${PROJECT_GIT[@]}" push -u origin "$BRANCH"
}

edit_spreadconfig_flake() {
  local flake="$SPREADCONFIG/flake.nix"
  [[ -f "$flake" ]] || die "missing spreadconfig flake: $flake"

  local backup="$flake.bak.$(date +%Y%m%d-%H%M%S)"
  cp "$flake" "$backup"
  printf 'Backup: %s\n' "$backup"

  run_python - "$flake" "$INPUT_URL" <<'PY'
from pathlib import Path
import sys

path = Path(sys.argv[1])
input_url = sys.argv[2]
text = path.read_text(encoding="utf-8")
changed = False

def replace_once(old: str, new: str, description: str) -> None:
    global text, changed
    count = text.count(old)
    if count != 1:
        raise SystemExit(f"expected exactly one {description}, found {count}")
    text = text.replace(old, new, 1)
    changed = True

if "niri-computer-use =" not in text:
    replace_once(
        "  inputs = {\n",
        "  inputs = {\n"
        "    niri-computer-use = {\n"
        f'      url = "{input_url}";\n'
        '      inputs.nixpkgs.follows = "nixpkgs";\n'
        "    };\n",
        "inputs block",
    )

if "inputs.niri-computer-use.nixosModules.default" not in text:
    replace_once(
        "            home-manager.nixosModules.home-manager\n",
        "            home-manager.nixosModules.home-manager\n"
        "            inputs.niri-computer-use.nixosModules.default\n",
        "NixOS module import anchor",
    )

if "services.niri-computer-use" not in text:
    replace_once(
        "            {\n              home-manager.useGlobalPkgs = true;\n",
        "            {\n"
        "              services.niri-computer-use = {\n"
        "                enable = true;\n"
        '                user = "spreadzhao";\n'
        "              };\n\n"
        "              home-manager.useGlobalPkgs = true;\n",
        "home-manager NixOS module attrs anchor",
    )

if "inputs.niri-computer-use.homeManagerModules.default" not in text:
    replace_once(
        "                  inputs.nixvim.homeModules.nixvim\n",
        "                  inputs.nixvim.homeModules.nixvim\n"
        "                  inputs.niri-computer-use.homeManagerModules.default\n",
        "Home Manager imports anchor",
    )

if "programs.niri-computer-use" not in text:
    replace_once(
        '                  (hostDir + "/home.nix")\n'
        "                ];\n"
        "              };\n",
        '                  (hostDir + "/home.nix")\n'
        "                ];\n"
        "                programs.niri-computer-use = {\n"
        "                  enable = true;\n"
        '                  scriptsDir = "/home/spreadzhao/scripts";\n'
        "                  skillDirectories = [\n"
        '                    ".agents/skills"\n'
        '                    ".claude/skills"\n'
        '                    "workspaces/spreadconfig/.agents/skills"\n'
        '                    "workspaces/spreadconfig/.claude/skills"\n'
        "                  ];\n"
        "                };\n"
        "              };\n",
        "Home Manager user attrs anchor",
    )

if changed:
    path.write_text(text, encoding="utf-8")
    print(f"Updated {path}")
else:
    print(f"{path} already contains the niri-computer-use integration")
PY

  if command -v nixfmt >/dev/null 2>&1; then
    nixfmt "$flake"
  fi
}

lock_and_eval_spreadconfig() {
  nix flake lock "$SPREADCONFIG"

  if [[ -z "$HOSTS" ]]; then
    case "$(hostname)" in
      thinkbook|zephyrus-m16) HOSTS="$(hostname)" ;;
      *) HOSTS="thinkbook zephyrus-m16" ;;
    esac
  fi

  for host in $HOSTS; do
    printf 'Evaluating NixOS host: %s\n' "$host"
    nix eval --raw --no-eval-cache \
      "${SPREADCONFIG}#nixosConfigurations.${host}.config.system.build.toplevel.drvPath" >/dev/null
  done
}

main() {
  need_cmd git
  need_cmd nix

  [[ -d "$PROJECT_DIR" ]] || die "missing project directory: $PROJECT_DIR"
  [[ -d "$SPREADCONFIG" ]] || die "missing spreadconfig directory: $SPREADCONFIG"

  ensure_clean_spreadconfig
  make_project_git_command
  commit_project
  push_project
  edit_spreadconfig_flake
  lock_and_eval_spreadconfig

  printf '\nDone. spreadconfig changes:\n'
  git -C "$SPREADCONFIG" status --short -- flake.nix flake.lock
  git -C "$SPREADCONFIG" diff -- flake.nix

  if [[ "$RUN_SWITCH" == "1" ]]; then
    "$HOME/scripts/nix/sns_until" switch
  else
    printf '\nSwitch was not run. To apply after reviewing:\n'
    printf '  cd %q\n' "$SPREADCONFIG"
    printf '  ~/scripts/nix/sns_until switch\n'
  fi
}

main "$@"
