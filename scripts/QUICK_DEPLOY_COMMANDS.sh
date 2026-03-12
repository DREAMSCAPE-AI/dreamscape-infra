#!/usr/bin/env bash

set -euo pipefail

ORG="${ORG:-DREAMSCAPE-AI}"
INFRA_REPO="${INFRA_REPO:-dreamscape-infra}"
SOURCE_REPOS=(dreamscape-frontend dreamscape-services)

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
infra_root="$(cd "${script_dir}/.." && pwd)"

require_gh() {
  if ! command -v gh >/dev/null 2>&1; then
    echo "ERROR: gh CLI is required. Install: https://cli.github.com/"
    exit 1
  fi
  if ! gh auth status >/dev/null 2>&1; then
    echo "ERROR: gh CLI is not authenticated. Run: gh auth login"
    exit 1
  fi
}

usage() {
  cat <<'EOF'
Quick deployment helper (current Big Pods architecture)

Usage:
  ./scripts/QUICK_DEPLOY_COMMANDS.sh <command> [args]

Commands:
  check
      Validate local infra files and remote repository workflow presence.

  setup-secrets
      Set DISPATCH_TOKEN in source repos (frontend/services).
      Uses DISPATCH_TOKEN env var if set, otherwise prompts.

  trigger-staging [version]
      Trigger dreamscape-infra/.github/workflows/bigpods-cd.yml
      with environment=staging.
      If version is omitted, uses UTC timestamp.

  status
      Show recent runs for bigpods-cd.yml.

  all
      Run: check, setup-secrets, trigger-staging.

  help
      Show this help.
EOF
}

check_local_files() {
  local required=(
    "${infra_root}/.github/workflows/bigpods-cd.yml"
    "${infra_root}/.github/workflows/bigpods-ci.yml"
    "${infra_root}/.github/workflows/bigpods-release.yml"
    "${infra_root}/.github/workflows/ci.yml"
  )

  local missing=0
  for path in "${required[@]}"; do
    if [[ -f "${path}" ]]; then
      echo "OK: ${path}"
    else
      echo "MISSING: ${path}"
      missing=1
    fi
  done

  if [[ -f "${infra_root}/.github/workflows/unified-cicd.yml" ]]; then
    echo "WARNING: legacy workflow still present: .github/workflows/unified-cicd.yml"
    missing=1
  fi

  if [[ "${missing}" -ne 0 ]]; then
    echo "Check failed."
    exit 1
  fi
}

check_remote_workflows() {
  require_gh

  local checks=(
    "dreamscape-frontend:.github/workflows/ci-trigger.yml"
    "dreamscape-services:.github/workflows/ci-trigger.yml"
    "dreamscape-tests:.github/workflows/branch-testing.yml"
    "dreamscape-infra:.github/workflows/bigpods-cd.yml"
  )

  local missing=0
  local item=""
  local repo=""
  local path=""

  for item in "${checks[@]}"; do
    repo="${item%%:*}"
    path="${item#*:}"
    if gh api "repos/${ORG}/${repo}/contents/${path}" >/dev/null 2>&1; then
      echo "OK: remote ${ORG}/${repo}/${path}"
    else
      echo "MISSING: remote ${ORG}/${repo}/${path}"
      missing=1
    fi
  done

  if [[ "${missing}" -ne 0 ]]; then
    echo "Remote workflow check failed."
    exit 1
  fi
}

setup_dispatch_token() {
  require_gh

  local token="${DISPATCH_TOKEN:-}"
  if [[ -z "${token}" ]]; then
    read -r -s -p "Enter DISPATCH_TOKEN value: " token
    echo
  fi
  if [[ -z "${token}" ]]; then
    echo "ERROR: DISPATCH_TOKEN is empty."
    exit 1
  fi

  for repo in "${SOURCE_REPOS[@]}"; do
    echo "Setting DISPATCH_TOKEN in ${ORG}/${repo}"
    gh secret set DISPATCH_TOKEN --repo "${ORG}/${repo}" --body "${token}"
  done
}

trigger_staging() {
  require_gh

  local version="${1:-}"
  if [[ -z "${version}" ]]; then
    version="manual-$(date -u +%Y%m%d%H%M%S)"
  fi

  echo "Triggering ${ORG}/${INFRA_REPO}:bigpods-cd.yml (staging, version=${version})"
  gh workflow run bigpods-cd.yml \
    --repo "${ORG}/${INFRA_REPO}" \
    --ref main \
    -f environment=staging \
    -f version="${version}" \
    -f deployment_strategy=rolling \
    -f force_deployment=false
}

show_status() {
  require_gh
  gh run list \
    --repo "${ORG}/${INFRA_REPO}" \
    --workflow bigpods-cd.yml \
    --limit 10
}

main() {
  local cmd="${1:-help}"
  case "${cmd}" in
    check)
      check_local_files
      check_remote_workflows
      ;;
    setup-secrets)
      setup_dispatch_token
      ;;
    trigger-staging)
      trigger_staging "${2:-}"
      ;;
    status)
      show_status
      ;;
    all)
      check_local_files
      setup_dispatch_token
      trigger_staging "${2:-}"
      ;;
    help|-h|--help)
      usage
      ;;
    *)
      echo "ERROR: unknown command '${cmd}'"
      usage
      exit 1
      ;;
  esac
}

main "$@"
