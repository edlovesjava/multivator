# RFP: Request Queue with Rate Limiting

## Problem Statement

We need a request queue that sits in front of our third-party API calls. Currently we're hitting rate limits unpredictably and dropping requests. We need something that buffers requests, respects rate limits, retries on transient failures, and gives callers visibility into queue state.

This is used in a Node.js service handling ~500 req/min at peak, calling two different external APIs with different rate limits (100/min and 30/min respectively).

## Requirements

### Must Have
- [ ] Queue incoming requests and dispatch within rate limit windows
- [ ] Per-API rate limit configuration (requests/minute)
- [ ] Retry with exponential backoff on 429 and 5xx responses
- [ ] Caller gets a Promise that resolves/rejects when their request completes
- [ ] TypeScript, strict mode

### Should Have
- [ ] Queue depth and wait-time observable (for metrics/logging)
- [ ] Request prioritization (high/normal/low)
- [ ] Graceful shutdown (drain queue before exit)

### Must Not
- [ ] Must not lose requests silently
- [ ] Must not block the event loop
- [ ] Must not require Redis or any external state store — in-process only

## Evaluation Priorities

- [x] **Correctness** — rate limits must not be exceeded under concurrent load
- [x] **Test confidence** — this is infrastructure code, tests matter a lot
- [x] **Operational simplicity** — easy to debug when something goes wrong
- [ ] **Performance** — throughput matters but correctness comes first
- [ ] **Innovation** — open to novel approaches
- [ ] **Minimal footprint** — some dependencies acceptable if they earn their place

## Open Design Decisions

1. Sliding window vs token bucket vs fixed window rate limiting algorithm
2. Whether to expose an EventEmitter interface, a callback interface, or Promises-only
3. Whether priority queuing uses a heap or a simpler structure
4. How to handle queue overflow (drop oldest? reject new? backpressure?)

## Constraints

### Hard Constraints
- Language/runtime: Node.js 22 / TypeScript strict
- In-process only — no Redis, no DB
- Must work as a drop-in around an `async (request: T) => Promise<R>` function signature

### Soft Constraints
- Prefer: no new dependencies unless they meaningfully simplify the implementation
- Avoid if possible: complex class hierarchies

## Definition of Done

- [ ] All existing tests pass
- [ ] Unit tests cover: rate limit enforcement, retry behavior, priority ordering, graceful shutdown, queue overflow
- [ ] Load test demonstrates correct behavior at 2x peak throughput

## Context

### Relevant files / modules
- `src/api/client.ts` — current naive API call wrapper (no queuing)
- `src/config/apis.ts` — API config including current rate limit constants

### Prior art / failed approaches
- We tried `p-queue` but it doesn't support per-queue rate limiting natively
- A simple `setInterval` dispatch loop caused thundering herd on window reset

### External references
- https://docs.api-a.example.com/rate-limits
- https://docs.api-b.example.com/rate-limits
