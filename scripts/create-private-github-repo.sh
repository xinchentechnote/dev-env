#!/usr/bin/env bash

set -Eeuo pipefail
IFS=$'\n\t'

PROJECT_DIR="."
PROJECT_DIR_SET=false
REPOSITORY_NAME=""
OWNER=""
DESCRIPTION=""
REMOTE_NAME="origin"
COMMIT_MESSAGE="chore: initialize repository"
ASSUME_YES=false
REUSE_EXISTING=false
ALLOW_SECRET_FINDINGS=false
DRY_RUN=false

usage() {
  cat <<'EOF'
Create a private GitHub repository from a local project and push it safely.

Usage:
  create-private-github-repo.sh [options] [project-directory]

Options:
  --repo NAME                 GitHub repository name. Defaults to the directory name.
  --owner OWNER               GitHub user or organization. Defaults to the active gh user.
  --description TEXT          GitHub repository description.
  --remote NAME               Git remote name. Defaults to origin.
  --commit-message TEXT       Message used when local changes need a commit.
                               Defaults to "chore: initialize repository".
  --reuse-existing            Reuse an existing private GitHub repository with the same name.
                               Intended for resuming a partially completed run.
  --allow-secret-findings     Continue despite the heuristic secret scan finding candidates.
  --yes                       Skip the final interactive confirmation.
  --dry-run                   Run read-only checks and print the plan without changing state.
  -h, --help                  Show this help.

Safety behavior:
  - The GitHub repository is always private.
  - An existing repository is never reused unless --reuse-existing is explicit.
  - An existing local remote is never replaced when it points elsewhere.
  - Pushes never use --force.
  - Authentication tokens are managed by GitHub CLI and are never embedded in this script.
  - A heuristic scan checks common secret filenames and token/key patterns before publishing.

Examples:
  scripts/create-private-github-repo.sh ~/workspace/my-project
  scripts/create-private-github-repo.sh --repo my-project --description "Internal notes" .
  scripts/create-private-github-repo.sh --owner my-org --yes ~/workspace/my-project
  scripts/create-private-github-repo.sh --reuse-existing ~/workspace/my-project
EOF
}

log() {
  printf '%s\n' "$*"
}

warn() {
  printf 'warning: %s\n' "$*" >&2
}

die() {
  printf 'error: %s\n' "$*" >&2
  exit 1
}

require_value() {
  local option_name=$1
  local option_value=${2:-}
  [[ -n "$option_value" ]] || die "$option_name requires a value"
}

require_command() {
  command -v "$1" >/dev/null 2>&1 || die "required command not found: $1"
}

confirm() {
  local reply

  if [[ "$ASSUME_YES" == true ]]; then
    return 0
  fi

  printf 'Continue? [y/N] '
  IFS= read -r reply
  case "$reply" in
    y|Y|yes|YES|Yes) return 0 ;;
    *) die "cancelled by user" ;;
  esac
}

remote_matches_target() {
  local remote_url=$1
  local full_name=$2

  [[ "$remote_url" == "https://github.com/$full_name" ||
     "$remote_url" == "https://github.com/$full_name.git" ||
     "$remote_url" == "git@github.com:$full_name" ||
     "$remote_url" == "git@github.com:$full_name.git" ||
     "$remote_url" == "ssh://git@github.com/$full_name" ||
     "$remote_url" == "ssh://git@github.com/$full_name.git" ]]
}

scan_for_secret_candidates() {
  local project_root=$1
  local content_pattern
  local filename_pattern
  local content_matches
  local filename_matches
  local scan_status
  local found=false

  # Strong signatures reduce false positives. This remains a heuristic guardrail.
  content_pattern='-----BEGIN [A-Z0-9 ]*PRIVATE KEY-----|github_pat_[A-Za-z0-9_]{20,}|gh[pousr]_[A-Za-z0-9]{20,}|AKIA[0-9A-Z]{16}|ASIA[0-9A-Z]{16}|AIza[0-9A-Za-z_-]{30,}|xox[baprs]-[0-9A-Za-z-]{20,}|Authorization:[[:space:]]*Bearer[[:space:]]+[A-Za-z0-9._~+/-]{16,}'
  filename_pattern='(^|/)(\.env($|\.)|id_(rsa|dsa|ecdsa|ed25519)(\.pub)?$|credentials?($|\.)|secrets?($|\.)|.*\.(pem|p12|pfx|key|keystore)$)'

  set +e
  content_matches=$(rg -l --hidden --no-ignore --glob '!**/.git/**' -- "$content_pattern" "$project_root" 2>/dev/null)
  scan_status=$?
  set -e
  if [[ $scan_status -gt 1 ]]; then
    die "content secret scan failed"
  fi

  set +e
  filename_matches=$(rg --files --hidden --no-ignore --glob '!**/.git/**' "$project_root" 2>/dev/null | grep -E "$filename_pattern")
  scan_status=$?
  set -e
  if [[ $scan_status -gt 1 ]]; then
    die "filename secret scan failed"
  fi

  if [[ -n "$content_matches" ]]; then
    found=true
    warn "possible secret content found in these files (matched values are not printed):"
    printf '%s\n' "$content_matches" >&2
  fi

  if [[ -n "$filename_matches" ]]; then
    found=true
    warn "sensitive-looking filenames found:"
    printf '%s\n' "$filename_matches" >&2
  fi

  if [[ "$found" == true && "$ALLOW_SECRET_FINDINGS" != true ]]; then
    die "secret scan found candidates; review them or rerun with --allow-secret-findings after confirming they are safe"
  fi

  if [[ "$found" == true ]]; then
    warn "continuing because --allow-secret-findings was supplied"
  else
    log "Secret scan: no common key/token signatures or sensitive filenames found."
  fi
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --repo)
      require_value "$1" "${2:-}"
      REPOSITORY_NAME=$2
      shift 2
      ;;
    --repo=*)
      REPOSITORY_NAME=${1#*=}
      require_value "--repo" "$REPOSITORY_NAME"
      shift
      ;;
    --owner)
      require_value "$1" "${2:-}"
      OWNER=$2
      shift 2
      ;;
    --owner=*)
      OWNER=${1#*=}
      require_value "--owner" "$OWNER"
      shift
      ;;
    --description)
      require_value "$1" "${2:-}"
      DESCRIPTION=$2
      shift 2
      ;;
    --description=*)
      DESCRIPTION=${1#*=}
      require_value "--description" "$DESCRIPTION"
      shift
      ;;
    --remote)
      require_value "$1" "${2:-}"
      REMOTE_NAME=$2
      shift 2
      ;;
    --remote=*)
      REMOTE_NAME=${1#*=}
      require_value "--remote" "$REMOTE_NAME"
      shift
      ;;
    --commit-message)
      require_value "$1" "${2:-}"
      COMMIT_MESSAGE=$2
      shift 2
      ;;
    --commit-message=*)
      COMMIT_MESSAGE=${1#*=}
      require_value "--commit-message" "$COMMIT_MESSAGE"
      shift
      ;;
    --reuse-existing)
      REUSE_EXISTING=true
      shift
      ;;
    --allow-secret-findings)
      ALLOW_SECRET_FINDINGS=true
      shift
      ;;
    --yes)
      ASSUME_YES=true
      shift
      ;;
    --dry-run)
      DRY_RUN=true
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    --)
      shift
      if [[ $# -gt 1 ]]; then
        die "only one project directory may be supplied"
      fi
      if [[ $# -eq 1 ]]; then
        if [[ "$PROJECT_DIR_SET" == true ]]; then
          die "only one project directory may be supplied"
        fi
        PROJECT_DIR=$1
        PROJECT_DIR_SET=true
      fi
      break
      ;;
    -*)
      die "unknown option: $1"
      ;;
    *)
      if [[ "$PROJECT_DIR_SET" == true ]]; then
        die "only one project directory may be supplied"
      fi
      PROJECT_DIR=$1
      PROJECT_DIR_SET=true
      shift
      ;;
  esac
done

require_command git
require_command gh
require_command rg
require_command grep
require_command awk

[[ -d "$PROJECT_DIR" ]] || die "project directory does not exist: $PROJECT_DIR"
PROJECT_DIR=$(cd "$PROJECT_DIR" && pwd -P)

if [[ -z "$REPOSITORY_NAME" ]]; then
  REPOSITORY_NAME=$(basename "$PROJECT_DIR")
fi

[[ "$REPOSITORY_NAME" =~ ^[A-Za-z0-9._-]+$ ]] || die "invalid repository name: $REPOSITORY_NAME"
[[ "$REMOTE_NAME" =~ ^[A-Za-z0-9._-]+$ ]] || die "invalid remote name: $REMOTE_NAME"

if ! gh auth status --hostname github.com >/dev/null 2>&1; then
  die "GitHub CLI is not authenticated. Run: gh auth login --hostname github.com --git-protocol https --web"
fi

if [[ -z "$OWNER" ]]; then
  OWNER=$(gh api user --jq .login)
fi
[[ "$OWNER" =~ ^[A-Za-z0-9-]+$ ]] || die "invalid GitHub owner: $OWNER"

FULL_NAME="$OWNER/$REPOSITORY_NAME"
EXPECTED_REMOTE_URL="https://github.com/$FULL_NAME.git"
TARGET_EXISTS=false
TARGET_IS_PRIVATE=""

if TARGET_IS_PRIVATE=$(gh repo view "$FULL_NAME" --json isPrivate --jq .isPrivate 2>/dev/null); then
  TARGET_EXISTS=true
fi

if [[ "$TARGET_EXISTS" == true ]]; then
  [[ "$TARGET_IS_PRIVATE" == true ]] || die "existing repository is not private: $FULL_NAME"
  [[ "$REUSE_EXISTING" == true ]] || die "repository already exists: $FULL_NAME (use --reuse-existing only when resuming intentionally)"
fi

LOCAL_REPOSITORY=false
CURRENT_BRANCH="main"
if [[ -e "$PROJECT_DIR/.git" ]]; then
  LOCAL_REPOSITORY=true
  LOCAL_ROOT=$(git -C "$PROJECT_DIR" rev-parse --show-toplevel 2>/dev/null) || die "invalid local Git repository: $PROJECT_DIR"
  LOCAL_ROOT=$(cd "$LOCAL_ROOT" && pwd -P)
  [[ "$LOCAL_ROOT" == "$PROJECT_DIR" ]] || die "project directory is not the Git repository root: $PROJECT_DIR"

  if CURRENT_BRANCH_VALUE=$(git -C "$PROJECT_DIR" symbolic-ref --quiet --short HEAD 2>/dev/null); then
    CURRENT_BRANCH=$CURRENT_BRANCH_VALUE
  else
    die "local repository is in detached HEAD state"
  fi

  if git -C "$PROJECT_DIR" remote get-url "$REMOTE_NAME" >/dev/null 2>&1; then
    EXISTING_REMOTE_URL=$(git -C "$PROJECT_DIR" remote get-url "$REMOTE_NAME")
    remote_matches_target "$EXISTING_REMOTE_URL" "$FULL_NAME" || die "remote '$REMOTE_NAME' already points elsewhere: $EXISTING_REMOTE_URL"
  fi
elif git -C "$PROJECT_DIR" rev-parse --show-toplevel >/dev/null 2>&1; then
  warn "project is nested inside another Git repository; a new nested repository will be initialized at $PROJECT_DIR"
fi

scan_for_secret_candidates "$PROJECT_DIR"

log ""
log "Plan:"
log "  Local directory: $PROJECT_DIR"
log "  GitHub target:  $FULL_NAME"
log "  Visibility:     PRIVATE"
log "  Branch:         $CURRENT_BRANCH"
log "  Remote:         $REMOTE_NAME"
if [[ "$LOCAL_REPOSITORY" == true ]]; then
  log "  Local Git:      reuse existing repository"
else
  log "  Local Git:      initialize a new repository"
fi
if [[ "$TARGET_EXISTS" == true ]]; then
  log "  GitHub repo:    reuse existing private repository"
else
  log "  GitHub repo:    create new private repository"
fi
if [[ -n "$DESCRIPTION" ]]; then
  log "  Description:    $DESCRIPTION"
fi

if [[ "$LOCAL_REPOSITORY" == true ]]; then
  log ""
  log "Local changes that will be included in the commit, if any:"
  LOCAL_STATUS=$(git -C "$PROJECT_DIR" status --short)
  if [[ -n "$LOCAL_STATUS" ]]; then
    printf '%s\n' "$LOCAL_STATUS"
  else
    log "  (working tree clean; the existing HEAD will be pushed)"
  fi
fi

if [[ "$DRY_RUN" == true ]]; then
  log ""
  log "Dry run complete. No files, Git state, GitHub repositories, or remotes were changed."
  exit 0
fi

log ""
confirm

if [[ "$LOCAL_REPOSITORY" != true ]]; then
  git -C "$PROJECT_DIR" init
  git -C "$PROJECT_DIR" symbolic-ref HEAD refs/heads/main
  CURRENT_BRANCH="main"
fi

git -C "$PROJECT_DIR" add -A

if ! git -C "$PROJECT_DIR" diff --cached --quiet; then
  GIT_USER_NAME=$(git -C "$PROJECT_DIR" config user.name || true)
  GIT_USER_EMAIL=$(git -C "$PROJECT_DIR" config user.email || true)
  [[ -n "$GIT_USER_NAME" && -n "$GIT_USER_EMAIL" ]] ||
    die "Git author identity is not explicitly configured. Set user.name and user.email globally or for this repository, then rerun the script"
  git -C "$PROJECT_DIR" commit -m "$COMMIT_MESSAGE"
elif ! git -C "$PROJECT_DIR" rev-parse --verify HEAD >/dev/null 2>&1; then
  die "there are no files to commit and no existing commit to push"
else
  log "No local changes to commit; using the existing HEAD."
fi

CURRENT_BRANCH=$(git -C "$PROJECT_DIR" symbolic-ref --quiet --short HEAD)
LOCAL_SHA=$(git -C "$PROJECT_DIR" rev-parse HEAD)

if [[ "$TARGET_EXISTS" != true ]]; then
  CREATE_ARGS=(repo create "$FULL_NAME" --private)
  if [[ -n "$DESCRIPTION" ]]; then
    CREATE_ARGS+=(--description "$DESCRIPTION")
  fi
  gh "${CREATE_ARGS[@]}"
fi

if git -C "$PROJECT_DIR" remote get-url "$REMOTE_NAME" >/dev/null 2>&1; then
  EXISTING_REMOTE_URL=$(git -C "$PROJECT_DIR" remote get-url "$REMOTE_NAME")
  remote_matches_target "$EXISTING_REMOTE_URL" "$FULL_NAME" || die "remote '$REMOTE_NAME' changed unexpectedly: $EXISTING_REMOTE_URL"
else
  git -C "$PROJECT_DIR" remote add "$REMOTE_NAME" "$EXPECTED_REMOTE_URL"
fi

gh auth setup-git
git -C "$PROJECT_DIR" push --set-upstream "$REMOTE_NAME" "$CURRENT_BRANCH"

VERIFY_PRIVATE=$(gh repo view "$FULL_NAME" --json isPrivate --jq .isPrivate)
VERIFY_URL=$(gh repo view "$FULL_NAME" --json url --jq .url)
REMOTE_SHA=$(git -C "$PROJECT_DIR" ls-remote "$REMOTE_NAME" "refs/heads/$CURRENT_BRANCH" | awk 'NR == 1 { print $1 }')

[[ "$VERIFY_PRIVATE" == true ]] || die "verification failed: GitHub repository is not private"
[[ -n "$REMOTE_SHA" ]] || die "verification failed: remote branch was not found"
[[ "$LOCAL_SHA" == "$REMOTE_SHA" ]] || die "verification failed: local HEAD and remote branch differ"

log ""
log "Success:"
log "  Repository: $VERIFY_URL"
log "  Visibility: PRIVATE"
log "  Branch:     $CURRENT_BRANCH"
log "  Commit:     $LOCAL_SHA"
log "  Upstream:   $REMOTE_NAME/$CURRENT_BRANCH"
