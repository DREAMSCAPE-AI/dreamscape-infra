# Dreamscape Infra CI/CD

This repository keeps the active workflows and helper scripts for infrastructure operations.

The detailed CI/CD documentation now lives in the documentation repository:

- `dreamscape-docs/infrastructure/cicd/bigpods-cicd.md`
- `dreamscape-docs/guides/setup/CICD_SETUP.md`

Current active entrypoints in this repository:

- `.github/workflows/bigpods-cd.yml`
- `scripts/QUICK_DEPLOY_COMMANDS.sh`
- `scripts/setup-dispatch-architecture.sh`

Current runtime model:

- `dreamscape-frontend` and `dreamscape-services` run local CI in their own repositories
- a `push` to `main` can dispatch `bigpods-cd.yml` with `workflow_dispatch`
- `dreamscape-tests` remains CI-only
- `unified-cicd.yml` is no longer part of the active deployment path

Use this file only as a local pointer. The source of truth for CI/CD documentation is `dreamscape-docs`.
