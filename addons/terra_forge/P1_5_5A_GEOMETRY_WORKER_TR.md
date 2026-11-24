# P1.5.5a — Independent bounded geometry worker
> **GÜNCEL DEVİR — P1.5.5a (24 Kasım 2026):** Kod cb63d03b665feccab7aca7d64b56569ea7aed3df, [39/39 Godot Linux CI PASS](https://github.com/mehmetdem2005/FareOyunu/actions/runs/45443035828). [P1_5_5A_GEOMETRY_WORKER_TR.md](P1_5_5A_GEOMETRY_WORKER_TR.md). Isolated one-worker prototype, 14 exact array parity cases, owned dense input survives page eviction, bounded slots, stale neighbor/epoch/reopen rejection. No live preview integration yet; A default/B+C opt-in/D benchmark-only unchanged. **NEXT P1.5.5b:** audit worker ownership/lifetime, opt-in live integration with bounded publication and no duplicate outstanding tiles, test actual mesh/shape and failure/epoch/LOD isolation. Android/large-world and old EXP gates open. No painting/objects, P1.4 parked.

## Contract and implementation
`core/geometry_worker.gd`: one low-priority Thread, main-only start(source,cap=2), submit(source,key,lod,desired), poll(source,desired), stats(), close(). Cap 1..4 covers pending+inflight+finished. Binary wake ownership with mutex and semaphore; worker drains queue. Input prepared synchronously via verified tile lease and DENSE.build; release before enqueue. No external buffer handle, no reader/cache lease transferred; only four-neighbor levels and copied dense Float32 data. Worker calls existing pure G.generate with dictionary sampling (C), not D scalar. Never touches scene tree, Mesh resource or physics server (Mesh.ARRAY_* enum only). Caller owns delivered packed arrays after poll; caller-retained result bytes not covered by worker budget. Must close before losing worker reference; join can wait for in-flight build.
Reader instance ID + monotonic per-instance successful-open session_serial() + V2 snapshot digest bind worker context. TFM1 snapshot string empty, instance and serial still isolate reopen. Main _context reads current epoch, drops queued/finished old work and worker drops mismatched in-flight result once it returns. Source epoch is observed on submit/poll, not actively notified until then. Poll checks current requested LOD, four cardinal neighbor levels and epoch before transferring one result. Signature validates bounds and levels. No implicit fallback.
Payload accounting: max4900 input bytes + conservative output reservation 131072 bytes per slot; output count uses 24-byte Vector3/16-byte Vector2 allowance, Color16, index4, collision4. Slot reservation 135972 bytes, 2 slots 271944 bytes, 4 slots 543888 bytes. Not exact process RSS/heap; excludes container overhead, temporary allocation during geometry, caller-held arrays and existing mesh/physics. Actual result estimate checked after build. No claims of performance gain. C dense copy on main may offset worker gain. Worker is not live-connected; no runtime defaults changed.
## Evidence
39/39 Linux Godot 4.7.2 CI. 14 exact parity cases TFM1/2, 576² fixtures, same/mixed LOD0/1/2, edges, interior shard seams, evict source pages after submit. Queue capacity2 including completed-but-unpolled results; third submit ERR_BUSY. Stale neighbor signature two dropped, epoch two more dropped, delivered+discarded conservation, reopen same reader object rejects old result, stop releases worker. Missing resident data rejected before queue. Worker timings descriptive only; not benchmark against synchronous path.
```json
[
  {
    "format": 1,
    "parity_cases": 7,
    "stats_before_reopen": {
      "cap": 2,
      "delivered": 7,
      "dropped": 4,
      "epoch": 1,
      "finished": 0,
      "inflight": 0,
      "open": true,
      "payload_cap_bytes": 271944,
      "peak_slots": 2,
      "pending": 0,
      "reserved_payload_bytes": 0,
      "slots": 0,
      "submitted": 11
    },
    "worker_build_elapsed_sum_us": 8932
  },
  {
    "format": 2,
    "parity_cases": 7,
    "stats_before_reopen": {
      "cap": 2,
      "delivered": 7,
      "dropped": 4,
      "epoch": 1,
      "finished": 0,
      "inflight": 0,
      "open": true,
      "payload_cap_bytes": 271944,
      "peak_slots": 2,
      "pending": 0,
      "reserved_payload_bytes": 0,
      "slots": 0,
      "submitted": 11
    },
    "worker_build_elapsed_sum_us": 9353
  }
]
```
## Open risks and next P1.5.5b
Audit worker lifecycle: caller must close; no automatic destructor safety claim; late source epoch until next submit/poll, same-generation neighbor churn wastes compute; no deduplication in prototype (test deliberately uses duplicate jobs), no strict exact total heap cap. Consider reservation for consumer-held result before multi-result publication; never accumulate unbounded results. Add explicit opt-in preview worker flag default false, start/close order worker before reader; map one in-flight job per tile with job identity, clean reservation when dropped by epoch/signature, bounded publish count/time, do not erase pending until successful matching result, preserve last-good mesh/shape and block only failed tile. Revalidate identity immediately before publication. Test real ArrayMesh + HeightMapShape3D parity (including mixed seams), rapid camera and same-epoch LOD changes, queue cap, missing/corrupt page and cold shard, close/reopen, no stale meshes, actual worker/pump telemetry. Separate worker build time, main copy, queue wait, delivery and upload. Compare equal completed work and fixed trace; real raycast/render/FPS/RSS/device soak later. Keep experimental. D runtime and reusable topology/preallocation remain deferred in EXP-01; no implicit acceptance. 
