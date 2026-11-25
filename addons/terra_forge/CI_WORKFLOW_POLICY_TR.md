# TerraForge CI — çalışma düzeni ve devir kuralı

## Problem
On 25 Nov 2026 development merge 5d53e17 run 45686058282 and docs commit 91aa984 run 45686118380 were cancelled by later documentation pushes; 2a3e276 run 45687232339 was in progress when this change was prepared. These are cancellations, not failing engine tests. Repeated docs pushes used the same workflow concurrency group.

## Proposed policy (effective only after verified merge)
- Development push: ignore only the seven named non-runtime handoff/decision/roadmap files in terraforge-ci.yml. Mixed code+docs commits still run full CI. JSON data/fixtures and other files are NOT globally ignored.
- Development integration runs are not preempted by subsequent commits; GitHub concurrency can still replace a queued (not running) run. Confirm exact latest relevant code tree and workflow SHA. Never label a cancelled run PASS.
- PR checks retain original trigger and three-shard full regression suite; stale runs on the same experiment PR may be cancelled. Manual workflow_dispatch remains available.
- Docs-only push intentionally has no new regression run. Validate changes by exact diff against latest verified code/workflow tree, not merely a previous green status. If runtime files changed, require new CI.
- Batch accepted nonconflicting changes and handoff/ledger updates; avoid repeated intermediate integration pushes. Wait for exact combined CI before announcing verified integration. Record experiment conclusions after CI in the named handoff/ledger files, without restarting tests.
- This workflow change itself must pass all three regression jobs on a PR and after merge. Do not change regression tests, permissions, engine version, or default motor. If branch protection requires a push check on every docs SHA, use manual dispatch or revert the filter; PR required checks are retained.
