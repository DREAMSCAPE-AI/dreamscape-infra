# Dreamscape Infra CI/CD

## Quick Overview

This document describes the active CI/CD model used by the Dreamscape repositories.
It replaces the old `repository_dispatch` plus `unified-cicd.yml` architecture.

Current deployment source of truth:
- `dreamscape-infra/.github/workflows/bigpods-cd.yml`

Current trigger model:
- `dreamscape-frontend` and `dreamscape-services` run local CI on push and pull request
- on `push` to `main`, they call `actions.createWorkflowDispatch`
- the dispatched infra workflow is `bigpods-cd.yml`
- `dreamscape-tests` remains CI-only and does not deploy infra

## Goals

- Keep CI close to each source repository
- Keep deployment orchestration centralized in infra
- Remove duplicate central workflows and legacy dispatch chains
- Make staging deployment happen from a single workflow entrypoint

## Active Workflows

| Repository | Workflow | Role | Trigger |
|---|---|---|---|
| `dreamscape-infra` | `.github/workflows/bigpods-cd.yml` | Build and deploy Big Pods | `push` on `main`, `workflow_dispatch` |
| `dreamscape-infra` | `.github/workflows/bigpods-ci.yml` | Validate Big Pods scripts and config | infra `push` / `pull_request` |
| `dreamscape-infra` | `.github/workflows/bigpods-release.yml` | Release management | tag push, release, `workflow_dispatch` |
| `dreamscape-infra` | `.github/workflows/ci.yml` | Infra code quality checks | infra `push` / `pull_request` / manual |
| `dreamscape-frontend` | `.github/workflows/ci-trigger.yml` | Frontend CI + infra CD trigger | `push`, `pull_request` |
| `dreamscape-services` | `.github/workflows/ci-trigger.yml` | Services CI + infra CD trigger | `push`, `pull_request` |
| `dreamscape-services` | `.github/workflows/ci.yml` | Services CI + test fan-out | `push`, `pull_request` |
| `dreamscape-tests` | `.github/workflows/branch-testing.yml` | Multi-repo test orchestration | `push`, `pull_request`, `repository_dispatch` |

## Runtime Architecture

```text
push main on frontend/services
        |
        v
local CI in source repo
        |
        v
createWorkflowDispatch(bigpods-cd.yml, environment=staging)
        |
        v
dreamscape-infra / bigpods-cd.yml
  1. pre-deployment validation
  2. build and push pod images
  3. deploy staging or production
  4. post-deployment validation
```

```text
push or PR on tests repo
        |
        v
dreamscape-tests / branch-testing.yml
  1. clone frontend/services when needed
  2. run unit / integration / e2e flows
  3. publish test summary
  4. no infra deployment
```

## Cross-Repository Contract

### Frontend and services to infra

The source repositories dispatch infra only when all of the following are true:

- event is `push`
- branch is `main`
- `DISPATCH_TOKEN` exists

The dispatch payload currently uses:

```text
workflow_id: bigpods-cd.yml
environment: staging
version: <short source sha>
deployment_strategy: rolling
force_deployment: false
```

### Services to tests

`dreamscape-services/.github/workflows/ci.yml` can still send:

```text
repository_dispatch
event_type: test-request
```

That event is consumed by:

- `dreamscape-tests/.github/workflows/branch-testing.yml`

This is test orchestration only. It is not part of infra deployment.

## Branch and Event Behavior

| Source | Event | Expected result |
|---|---|---|
| frontend/services | push `main` | local CI + dispatch infra staging deployment |
| frontend/services | push non-main | local CI only |
| frontend/services | pull request | local CI only |
| tests | push `main`, `dev`, `develop` | tests CI runs |
| tests | pull request to `main`, `dev`, `develop` | tests CI runs |
| services | `test-request` dispatch | tests CI runs in `dreamscape-tests` |
| infra | push `main` | `bigpods-cd.yml` can run directly |
| infra | manual dispatch | operator-triggered deployment |

## What `bigpods-cd.yml` Actually Does

High-level job flow:

1. `pre-deployment`
   - resolve environment
   - resolve version
   - resolve deployment strategy
   - validate prerequisites
2. `build-and-push`
   - checkout infra
   - clone frontend and services dependencies
   - build and push pod images to GHCR
3. `deploy-staging` or `deploy-production`
   - prepare environment
   - configure Kubernetes access
   - update image tags in bootstrap manifests
   - bootstrap Kubernetes resources
4. `post-deployment-validation`
   - summarize deployment
   - notify
   - cleanup

## Important Implementation Notes

### Deployment version input

The `version` passed by frontend or services is used as the deployment version in `bigpods-cd.yml`.
It is not a strict source checkout pin for frontend or services code.

Today, `bigpods-cd.yml` clones frontend and services with `git clone --depth 1` from the remote repository default branch.
That means:

- the deployment is tagged with the source repo short SHA
- the actual build input is "latest remote default branch at build time"
- if strict source-to-image traceability is required, the workflow still needs a follow-up change

This is not introduced by the doc/scripts cleanup. It is an existing behavior in `bigpods-cd.yml`.

### Tests repository scope

`dreamscape-tests` is now intentionally CI-only.
No test workflow should trigger infra deployment.

## Secrets

### Source repositories

Required in:
- `dreamscape-frontend`
- `dreamscape-services`

Secret:
- `DISPATCH_TOKEN`

Purpose:
- allows `actions.createWorkflowDispatch` on `dreamscape-infra`

### Infra repository

Referenced by `bigpods-cd.yml`:

- `K3S_HOST`
- `K3S_SSH_KEY`
- `JWT_SECRET`
- `JWT_REFRESH_SECRET`
- `DATABASE_URL`
- `REDIS_URL`
- `STRIPE_SECRET_KEY`
- `OPENAI_API_KEY`
- `SLACK_WEBHOOK_URL`

Implicit GitHub secret:
- `GITHUB_TOKEN`

## Quick Start

### 1. Verify the current architecture

From `dreamscape-infra`:

```bash
./scripts/QUICK_DEPLOY_COMMANDS.sh check
```

What it verifies:
- local infra workflow files exist
- remote workflow files exist in frontend, services, tests, and infra
- legacy `unified-cicd.yml` is not still present locally

### 2. Configure dispatch token in source repositories

```bash
./scripts/QUICK_DEPLOY_COMMANDS.sh setup-secrets
```

### 3. Trigger a staging deployment manually

```bash
./scripts/QUICK_DEPLOY_COMMANDS.sh trigger-staging
```

Or with an explicit version:

```bash
./scripts/QUICK_DEPLOY_COMMANDS.sh trigger-staging manual-20260306
```

### 4. Inspect recent deployment runs

```bash
./scripts/QUICK_DEPLOY_COMMANDS.sh status
```

## Verification Checklist

Use this after a real source-repo push or a manual infra dispatch.

1. In the source repo, confirm local CI actually ran lint, typecheck, or build steps.
2. In the source repo, confirm the dispatch job succeeded and targeted `bigpods-cd.yml`.
3. In infra, confirm a `bigpods-cd.yml` run started with event `workflow_dispatch` or `push`.
4. Confirm image build logs show the expected pod image tags.
5. Confirm staging or production bootstrap manifests were updated during the deploy job.
6. Confirm rollout or Kubernetes apply steps completed without fallback warnings.
7. Confirm the staging endpoint or health endpoint reflects the new deployment.

## Troubleshooting

### Dispatch succeeds but deployed code is not the expected source commit

Check the current `bigpods-cd.yml` clone behavior.
It clones remote frontend/services default branches rather than checking out a source SHA passed by dispatch.

### Deployment did not start from frontend or services

Check:
- event was `push`
- branch was `main`
- `DISPATCH_TOKEN` is configured
- the source workflow did not skip because of `skip_reason`

### Tests are green but you suspect a soft pass

Check the actual logs in `dreamscape-tests/.github/workflows/branch-testing.yml`.
Some test steps may still use non-blocking patterns in the current implementation.

### `check` fails locally

`check` validates:
- local infra workflow files
- remote workflow files via `gh`

If local infra files are present but remote checks fail:
- confirm `gh auth status`
- confirm the target repositories exist under `DREAMSCAPE-AI`

## Legacy Files

These files are retained only as historical context for the removed architecture:

- `UNIFIED_CICD_VALIDATION.md`
- `docs/CICD_SETUP.md`
- `docs/MIGRATION_GUIDE.md`
- `docs/REPOSITORY-DISPATCH-SETUP.md`
- `docs/REPOSITORY-DISPATCH-TESTING.md`
- `docs/CI-CD-PIPELINE.md`

Do not use them as the implementation reference for current behavior.

## Current Risks and Follow-Ups

- `dreamscape-services` still has two CI workflows, which can create duplicated CI activity.
- `dreamscape-tests` still deserves stricter failure semantics in some jobs if you want to eliminate soft-pass cases.
- `bigpods-cd.yml` still lacks strict source SHA pinning for frontend/services dependency clones.
- legacy workflow references have been cleaned from operational docs and helper scripts, but archived docs remain for history.
