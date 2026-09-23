# EXECUTION PLAN

> **Workflow:** sessions split into **PLANNING** (draft the spec, this file) and
> **EXECUTION** (build it). This file is **rewritten in full** every planning
> cycle and describes only the *current* target.

**Status: IDLE — nothing queued.**

The last plan (Phase A: WebP media + background prefetch + splash warm-up;
Phase B: remote content packs over the OTA seam) is fully executed, verified
(validate:content 31 eras · analyze clean · 121 tests · manifest --check
clean) and committed to `main`. A real content pack is live on R2
(`long-ky-content`), end-to-end tested (a live edit was published, picked up
by a running app with no rebuild, then reverted and republished) along with
a bad-hash rejection test. Four ad-hoc UI fixes also landed this session
(date format, Global Timeline sliver app bar + period art mask, app display
name, Home era-scene legibility mask). Run a PLANNING session to populate
the next target here — candidates: the next chronicle period (Thống nhất &
Đổi Mới, 1975 onward), or a content-editing CMS now that publishing content
doesn't need an app release.
