#!/usr/bin/env bash

set -euo pipefail

ORG="${ORG:-DREAMSCAPE-AI}"
INFRA_REPO="${INFRA_REPO:-dreamscape-infra}"
FRONTEND_REPO="${FRONTEND_REPO:-dreamscape-frontend}"
SERVICES_REPO="${SERVICES_REPO:-dreamscape-services}"
TESTS_REPO="${TESTS_REPO:-dreamscape-tests}"

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
Setup script for current cross-repo dispatch architecture.

This script validates and bootstraps the Big Pods dispatch model:
  - frontend/services dispatch infra bigpods-cd.yml on push main
  - tests repo remains CI-only

Usage:
  ./scripts/setup-dispatch-architecture.sh <command>

Commands:
  validate
      Validate repositories and required workflow files.

  setup-secrets
      Set DISPATCH_TOKEN in frontend/services repositories.
      Uses DISPATCH_TOKEN env var if set, otherwise prompts.

  test-dispatch [version]
      Trigger infra bigpods-cd.yml manually with staging inputs.

  full [version]
      Run validate, setup-secrets, test-dispatch.

  help
      Show this help.
EOF
}

repo_exists() {
  local repo="$1"
  gh repo view "${ORG}/${repo}" >/dev/null 2>&1
}

file_exists_in_repo() {
  local repo="$1"
  local path="$2"
  gh api "repos/${ORG}/${repo}/contents/${path}" >/dev/null 2>&1
}

validate_architecture() {
  require_gh

  local repos=("${INFRA_REPO}" "${FRONTEND_REPO}" "${SERVICES_REPO}" "${TESTS_REPO}")
  for repo in "${repos[@]}"; do
    if repo_exists "${repo}"; then
      echo "OK: repo ${ORG}/${repo}"
    else
      echo "ERROR: repo not found ${ORG}/${repo}"
      exit 1
    fi
  done

  local checks=(
    "${INFRA_REPO}:.github/workflows/bigpods-cd.yml"
    "${INFRA_REPO}:.github/workflows/bigpods-ci.yml"
    "${FRONTEND_REPO}:.github/workflows/ci-trigger.yml"
    "${SERVICES_REPO}:.github/workflows/ci-trigger.yml"
    "${TESTS_REPO}:.github/workflows/branch-testing.yml"
  )

  local failed=0
  for item in "${checks[@]}"; do
    local repo="${item%%:*}"
    local path="${item#*:}"
    if file_exists_in_repo "${repo}" "${path}"; then
      echo "OK: ${repo}/${path}"
    else
      echo "MISSING: ${repo}/${path}"
      failed=1
    fi
  done

  if file_exists_in_repo "${INFRA_REPO}" ".github/workflows/unified-cicd.yml"; then
    echo "WARNING: legacy workflow still present in infra: .github/workflows/unified-cicd.yml"
  fi

  if [[ "${failed}" -ne 0 ]]; then
    echo "Validation failed."
    exit 1
  fi

  echo "Validation succeeded."
}

setup_secrets() {
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

  local targets=("${FRONTEND_REPO}" "${SERVICES_REPO}")
  for repo in "${targets[@]}"; do
    echo "Setting DISPATCH_TOKEN in ${ORG}/${repo}"
    gh secret set DISPATCH_TOKEN --repo "${ORG}/${repo}" --body "${token}"
  done
}

test_dispatch() {
  require_gh

  local version="${1:-manual-$(date -u +%Y%m%d%H%M%S)}"
  echo "Triggering ${ORG}/${INFRA_REPO}:bigpods-cd.yml with version=${version}"

  gh workflow run bigpods-cd.yml \
    --repo "${ORG}/${INFRA_REPO}" \
    --ref main \
    -f environment=staging \
    -f version="${version}" \
    -f deployment_strategy=rolling \
    -f force_deployment=false

  echo "Dispatch sent. Check: https://github.com/${ORG}/${INFRA_REPO}/actions/workflows/bigpods-cd.yml"
}

main() {
  local cmd="${1:-validate}"
  case "${cmd}" in
    validate)
      validate_architecture
      ;;
    setup-secrets)
      setup_secrets
      ;;
    test-dispatch)
      test_dispatch "${2:-}"
      ;;
    full)
      validate_architecture
      setup_secrets
      test_dispatch "${2:-}"
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
