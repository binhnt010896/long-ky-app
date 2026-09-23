# EXECUTION PLAN

> **Workflow:** sessions split into **PLANNING** (draft the spec, this file) and
> **EXECUTION** (build it). This file is **rewritten in full** every planning
> cycle and describes only the *current* target.

**Status: IDLE — nothing queued.**

The last plan (move era media off the app binary onto Cloudflare R2) is fully
executed, verified (validate:content 31 eras · analyze clean · 95 tests ·
manifest --check clean) and committed to `main`. The R2 bucket
(`long-ky-content`) is synced (58 stray files removed, 517 referenced files
live). App bundle: 3.2 GB → 87 MB. Run a PLANNING session to populate the
next target here — either the remaining cloud-content-architecture work
(remote JSON, splash gate, stale-while-revalidate) or the next era of the
chronicle.
