# Design: Adversarial TDD Sub-Team

## Status: Draft

## Problem

The RFP → bidder profiles → competing implementations flow produces strong designs and locked-choice implementations, but each implementor is still a *single* agent doing everything: writing tests, writing code, refactoring, and judging its own work. This collapses three distinct perspectives into one head:

- **"Does it work for the cases that matter?"** (testing mindset)
- **"Can I make this specific failing case pass?"** (coding mindset)
- **"Does this still fit the design?"** (architecture mindset)

When one agent holds all three roles, it tends to write tests it already knows it can pass, stops probing once the happy path works, and rationalizes drift from the design as "pragmatic adaptation." The divergence we spent so much effort engineering at the bidding and ADR stages gets quietly re-converged inside the implementor.

TDD with real humans works partly because the person writing the test is *trying to make the coder's life hard*, the coder is *trying to do as little as possible*, and the reviewer is *trying to protect the design*. These goals are in productive tension. A single agent playing all three parts can't produce that tension honestly.

## Goal

Inside each implementation scope, run an **adversarial TDD sub-team** of three agents with distinct, partially opposed goals, sharing the same code and specification but with strictly separated authority over what they may edit:

- **Tester** — tries to break the system. Writes failing tests within the bounds of the spec, design, and current task scope. Owns test code.
- **Coder** — tries to make the failing test pass with the minimum change possible. Owns production code.
- **Reviewer** (the architect voice) — protects the design. Flags drift, enforces architectural constraints, decides when the sub-team is done.

The sub-team loops until the reviewer is satisfied. The loop is deliberately narrow: the tester cannot write production code to "help," the coder cannot weaken a test to make it pass, and the reviewer cannot bypass the loop by editing directly.

---

## How It Relates to the Existing Flow

```
RFP                                  (spec)
 |
 v
Bidder Profiles                      (philosophy divergence)
 |
 v
Judge → Winning Design               (architecture + plan)
 |
 v
Competing Implementations            (ADR / choice divergence)
 |    each permutation locks a combo of choices
 |
 v
 +-- [NEW] Adversarial TDD sub-team  (implementation-level divergence of role)
 |      Tester ⟷ Coder ⟷ Reviewer
 |           loop per task in scope
 v
Working Code + Tests (per permutation)
 |
 v
Evaluation / Verdict
```

The layers answer progressively narrower questions:

| Layer | Question | Divergence axis |
|---|---|---|
| RFP | What problem are we solving? | — (user-defined) |
| Bidder profiles | What should we build? | Philosophy |
| ADR permutations | Which specific technologies? | Choice |
| **Adversarial TDD** | **Does this specific task actually work?** | **Role / intent** |

The first three layers diverge *between* agent runs. The adversarial TDD layer diverges *within* a single implementation run — three agents, same codebase, different jobs.

---

## Shared Context vs. Owned Artifacts

The sub-team's productivity comes from sharing what must be shared and separating what must be separated.

### Shared (read-only to all three roles)

- **The RFP / spec** — the original requirements, unchanged
- **The design** — the winning `APPROACH.md` from the bidding phase
- **The ADR assignment** — the locked choices for this permutation
- **The project plan / task scope** — the narrow slice of work this TDD loop is addressing right now

None of the three agents may modify these. They are the external constraints the loop operates within.

### Shared (read-write, but with role-specific authority)

- **Production code** — the coder owns it; the tester and reviewer read it
- **Test code** — the tester owns it; the coder and reviewer read it
- **A running transcript of the loop** — who said what, which tests were added, which code changes were made, what the reviewer flagged

Write authority is enforced by role, not by filesystem permissions. Each agent's prompt is explicit: "You may only edit files under `tests/`" or "You may only edit files under `src/`." Violations are surfaced by the reviewer.

### Role-exclusive artifacts

- **Tester**: `COVERAGE-NOTES.md` — why these tests, what invariants they defend, what they deliberately do not cover
- **Coder**: `CHANGE-NOTES.md` — what the minimum change was for each failing test, and why no more
- **Reviewer**: `REVIEW-LOG.md` — running architectural observations, drift warnings, refactor requests, and the final "satisfied" signal

---

## The Three Roles

### Tester

**Goal**: Find the gaps. Build confidence the system actually behaves as the spec and design say it should.

**Authority**:
- Writes and edits files under `tests/`
- Cannot edit production code
- May request that the coder refactor, but only after asserting coverage is sufficient to catch regressions

**Scope constraints**:
- Tests must be justifiable against the *spec* or the *design*. A test that probes behavior the spec doesn't require is out of scope — flag it as a discovered gap instead of silently asserting it.
- Tests must be within the *current task's* slice. If the tester discovers something interesting outside the task, it goes in a `DISCOVERED.md` backlog for the architect/Team Lead, not into the current test suite.
- Edge cases, adversarial inputs, boundary conditions, and failure modes are all in scope. "Happy path only" is a failure of the tester's role.

**Workflow per loop iteration**:
1. Read the current code and design.
2. Identify a behavior that should hold but isn't yet verified (or a suspected weakness).
3. Write one failing test that expresses that behavior.
4. Confirm the test fails for the *right* reason (not a syntax error, not a missing import).
5. Hand off to the coder.

**What success looks like**: When the reviewer asks "are we confident this implementation holds?", the answer is "yes, because the tests would catch it if it didn't" — and the reviewer believes the tester.

### Coder

**Goal**: Make the failing test pass. Nothing more.

**Authority**:
- Writes and edits files under `src/` (production code)
- Cannot edit tests (except during an explicit refactor step, see below)
- Cannot introduce features the failing test doesn't require

**Scope constraints**:
- Minimum viable change. If the failing test can be passed with three lines, three lines. No speculative generality, no "while I'm here" cleanups.
- Must stay within the design's architectural envelope. If making the test pass seems to require violating the design, stop and escalate to the reviewer — don't quietly reshape the architecture.
- No weakening the test to make it pass. No adding a guard that makes the assertion trivially true. The reviewer watches for this.

**Workflow per loop iteration**:
1. Read the failing test and the current code.
2. Make the smallest change that causes the test to pass without breaking other tests.
3. Run the full test suite to confirm no regressions.
4. Hand off to the reviewer.

**What success looks like**: The diff for each iteration is boring and obvious. The reviewer can read the change in thirty seconds and say "yes, that's the minimum."

### Reviewer (Architect)

**Goal**: Keep the implementation faithful to the design and efficient under the architecture's constraints. Decide when the sub-team is done.

**Authority**:
- Reads everything; edits nothing directly
- May request refactors (formal refactor step — see below)
- May reject tests as out-of-scope with a reason
- May reject code changes as design-violating with a reason
- Is the only role that can say "done"

**Scope constraints**:
- The reviewer enforces *design* fidelity, not personal taste. A disagreement with the design itself is escalated to the Team Lead / bidding layer, not fought in the TDD loop.
- Big-picture focus: cohesion, coupling, separation of concerns, adherence to ADR choices, operational viability. Not line-level style.

**Workflow per loop iteration**:
1. Read the new test, the code change, and the running transcript.
2. Check: does the test fit the spec and the current task's scope?
3. Check: is the code change minimal and inside the design envelope?
4. Check: is anything drifting — architectural creep, test suite rotting, minimum-change dogma producing an incoherent whole?
5. Decide: `CONTINUE` (hand back to tester for next case), `REFACTOR` (start a refactor sub-loop), `ESCALATE` (something is wrong above this loop's pay grade), or `DONE` (the task is satisfied).

**What success looks like**: At the end of the loop, the reviewer can point at the design doc and say "every requirement on this page is exercised by a test, every test is justified by this page, and the code is the simplest thing that reconciles them."

---

## The Refactor Sub-Loop

Minimum-change TDD produces correct code but not always *clean* code. Refactoring is a first-class step with its own ordering, because it's the place where both role boundaries and safety nets get tested.

The rule: **refactor is only safe when coverage is known to be sufficient first.** The tester owns the safety net; the coder (or tester) swings the hammer; the reviewer signs off.

```
Reviewer requests refactor
        |
        v
Tester: confirm coverage is sufficient for the planned refactor
  (add tests if not — these are safety-net tests, not new behavior)
        |
        v
Coder (or tester): perform the refactor
  (structural change only — no new behavior)
        |
        v
Tester: all tests still pass, coverage still holds
        |
        v
Reviewer: verify the refactor achieved the architectural goal
        |
        +-- satisfied → return to main loop
        +-- not satisfied → another refactor pass or ESCALATE
```

Notes:

- **Tester goes first**, always. Refactoring without a safety net is the failure mode this structure exists to prevent.
- **Either the coder or the tester may execute the refactor**, because refactors are behavior-preserving structural edits — they don't require the coder's "minimum change to pass a failing test" discipline. The tester performing a refactor does not violate role separation, because no new test is being written and no new behavior is being introduced.
- **The reviewer cannot perform the refactor itself.** Keeping the reviewer's hands off the code preserves the review role's independence.

---

## Loop Termination

The reviewer is the only role that can declare the sub-team done. Termination criteria:

1. **Spec coverage**: every requirement in the current task's slice of the spec is exercised by at least one passing test.
2. **Design coverage**: every architectural constraint relevant to this task is either tested or explicitly noted as "enforced structurally by X" in the reviewer's log.
3. **No outstanding refactor requests**: the reviewer has no pending concerns about the code's shape.
4. **No drift flags**: nothing in the transcript is marked as "out of scope — escalate."

If the loop runs longer than a configured budget (iteration count or token count) without termination, the reviewer writes a `STUCK.md` summarizing what's blocking and escalates to the Team Lead. Better to surface the stall than to let the loop grind.

---

## Escalation Channels

The adversarial TDD loop operates inside a narrow scope. Things that are outside that scope must exit the loop cleanly:

| Trigger | Who raises it | Where it goes |
|---|---|---|
| Tester finds behavior the spec doesn't cover | Tester → reviewer → `DISCOVERED.md` | Team Lead / next task |
| Coder hits a test that can only be passed by violating the design | Coder → reviewer | Reviewer decides: rescope task, or escalate to bidding layer |
| Reviewer sees drift they can't resolve | Reviewer | Team Lead, possibly triggers a new bid cycle |
| Sub-team exceeds iteration budget | Reviewer → `STUCK.md` | Team Lead |
| ADR choice is provably impossible for this task | Coder → reviewer → `BLOCKERS.md` | Competing-implementations layer (see DESIGN-competing-implementations.md) |

The key principle: **the TDD loop never silently expands its own scope.** Every expansion is an explicit escalation.

---

## Orchestration

### Spawning the sub-team

The competing-implementations layer spawns one implementor agent per permutation today. With this design, that single implementor becomes a sub-team of three. The spawn pattern:

```
Competing-implementations Team Lead
  spawns permutation P1 sub-team:
    - tester-P1      (edits tests/ only)
    - coder-P1       (edits src/ only)
    - reviewer-P1    (read-only, coordinates)
  All three share the same worktree.
```

All three agents in a sub-team share **one** worktree, not three. They are not independent implementors — they are adversarial roles over a shared codebase. The isolation boundary is still the worktree, but it's now a worktree per *permutation*, not per *role*.

### Coordination inside the sub-team

The reviewer is the sub-team's internal coordinator. Flow per iteration:

```
reviewer → SendMessage(tester): "next case, please"
tester writes failing test, commits, notifies reviewer
reviewer → SendMessage(coder): "make this pass"
coder writes minimum change, commits, notifies reviewer
reviewer reads diffs, updates REVIEW-LOG.md
reviewer decides: continue / refactor / escalate / done
```

The reviewer acts as the loop's scheduler. The tester and coder never message each other directly — all coordination flows through the reviewer, which is what keeps their goals adversarial rather than collaborative.

### Task-level slicing

One TDD loop per *task*, not per *permutation*. A permutation's full implementation consists of multiple TDD loops run in sequence, each addressing one slice of the design:

```
Permutation P1 (sqlite_wal + push):
  ├─ TDD loop: event append + query              → PASS
  ├─ TDD loop: push protocol + retry              → PASS
  ├─ TDD loop: crash recovery                     → STUCK → escalate
  └─ TDD loop: integration tests                  → (pending)
```

This keeps each loop's scope narrow enough that the reviewer can actually hold the whole thing in mind.

---

## Reactive Variant — Event-Driven Sub-Team

The loop described above is **turn-based**: reviewer → tester → coder → reviewer, each role waits for the previous to hand off. A **reactive** variant inverts this: the three roles run in parallel, each listening for events and reacting, with no central scheduler deciding whose turn it is.

This maps more closely to how a skilled human TDD team actually feels in practice — the tester is always probing, the coder is always responding to breakage, and the senior engineer is always watching for structural decay. Turns are a simplification we accept when we can only hold one role at a time.

### Role reframe

The roles shift slightly when they become reactive:

| Role | Turn-based version | Reactive version |
|---|---|---|
| **Tester** | Writes one failing test per turn when called | Continuously validates code against the spec, probes for uncovered behavior and edge cases, drafts new tests whenever code changes |
| **Coder** | Makes the one failing test pass when called | Reacts to any red state — failing test, broken build, type error — and makes it green with minimum change |
| **Refactorer** *(replaces Reviewer)* | Read-only, decides when done | Senior engineer; reacts to green-state code and actually rewrites it for the larger picture — cohesion, coupling, architectural fit, not just the feature under test |

The big role shift is the third seat: the turn-based **Reviewer** is a read-only gate, while the reactive **Refactorer** is a writer. The reviewer's "request a refactor" step collapses into the refactorer just doing the refactor when the build is green and the shape is wrong. The reviewer's "decide we're done" role doesn't go away, but it's no longer bundled with architectural authorship — see *Termination* below.

### Trigger model

Each role is an event handler with a specific subscription:

| Role | Listens for | Reacts by |
|---|---|---|
| **Tester** | `src/` file changed; `tests/` passed fully (no red anywhere); spec changed; idle time elapsed | Re-validate coverage against spec; look for uncovered requirements, edge cases, failure modes; add a new failing test |
| **Coder** | Any red state: failing test, broken build, type error, lint error | Make it green with the minimum change; do nothing more |
| **Refactorer** | Build is fully green AND (significant code volume added since last refactor OR structural smell detected OR idle time elapsed) | Rewrite for the bigger picture; preserve behavior; do not add features |

The rules of the turn-based version still apply inside each reaction:
- Tester cannot touch `src/`
- Coder cannot weaken tests or exceed minimum change
- Refactorer cannot add new behavior; refactors are behavior-preserving by definition

### The three hard problems reactivity introduces

**1. Write contention.** In the turn-based version, only one role holds the pen at a time. In the reactive version, multiple roles may want to write concurrently. The failure mode is mundane but real: tester and coder both save files, git gets confused, builds see partial state.

Resolutions, in increasing order of strictness:

- **Role-scoped write areas** *(handles the easy case)*. Tester only writes `tests/`, coder only writes `src/`, refactorer writes both. This eliminates tester-vs-coder contention entirely. It leaves refactorer-vs-anyone as the hard case.
- **Refactorer holds an exclusive lock** while it runs. Tester and coder pause until the refactor lands. Simple, and matches how a senior engineer actually behaves — "stop touching stuff, I'm reshaping this."
- **Proposal queue + serializing applier** *(most flexible)*. All three roles emit proposals (patches + rationale) to a queue instead of writing directly. A small applier process serializes application, rejects conflicts, and hands back rebase requests. This gives reactive *generation* with sequential *application*, which is usually what you actually want.

The proposal-queue model is probably the right default. It preserves parallel thinking without letting parallel writes corrupt the tree.

**2. Oscillation and thrashing.** Reactive systems without damping loop forever. The failure mode here is:

```
tester adds test → coder makes it pass → refactorer reshapes →
  tester sees new shape, adds tests on it → coder fixes them →
  refactorer reshapes again → ...
```

Damping mechanisms:

- **Refactorer backoff**: the refactorer only runs when the build has been stable for N events or T seconds. This gives the coder time to absorb multiple tester additions before the refactor pass.
- **Tester stability window**: after a refactor lands, the tester's first job is to verify that existing coverage still holds against the new shape — not to add new tests. Only after that passes does it resume probing.
- **Progress metric**: track "new spec requirements covered per iteration." If it flatlines, the tester stops proposing and the system moves toward termination.
- **Refactor budget**: the refactorer has a hard cap on rewrites per task. Prevents a senior-engineer agent from endlessly polishing.

**3. Termination.** In the turn-based version, the reviewer declares `DONE`. In the reactive version, nobody's naturally in charge of stopping. Options:

- **Keep a thin reviewer role** alongside the three reactive roles — read-only, runs periodically, checks termination criteria against the shared transcript, and declares `DONE` when the spec is fully covered, the build is green, the refactorer has no pending concerns, and progress has flatlined.
- **Elect the refactorer as terminator** — but this risks the refactorer either stopping too early (after its last clean rewrite) or never stopping (always finding something to polish).
- **External stop condition** — the Team Lead sets a budget (wall clock, iterations, tokens) and hard-stops the sub-team. Pragmatic but crude.

The cleanest design is probably: **keep a separate reviewer/judge as a read-only terminator, and make the refactorer the writer that the reviewer used to gate.** That preserves the goal separation of the turn-based design (reviewer = big-picture correctness, coder = minimum change, tester = adversarial probing) while adding a fourth "architect-hands" role that actually rewrites. You get four agents instead of three, but each has a single clean job.

### Coordination inside the sub-team (reactive)

```
                       ┌──────────────┐
                       │  file/build  │
                       │   watcher    │
                       └──────┬───────┘
                              │ events
                ┌─────────────┼─────────────┐
                ▼             ▼             ▼
          ┌─────────┐   ┌─────────┐   ┌───────────┐
          │ Tester  │   │  Coder  │   │Refactorer │
          │(probes) │   │(fixes)  │   │(reshapes) │
          └────┬────┘   └────┬────┘   └─────┬─────┘
               │ proposals   │ proposals    │ proposals
               ▼             ▼              ▼
                       ┌─────────────┐
                       │  Applier    │  serializes writes,
                       │  (queue)    │  rejects conflicts
                       └──────┬──────┘
                              │ commits
                              ▼
                        shared worktree
                              │
                              ▼
                        ┌──────────┐
                        │ Reviewer │  read-only,
                        │(termin-  │  declares DONE
                        │  ator)   │
                        └──────────┘
```

The tester/coder/refactorer never message each other. They react to the worktree's state via the watcher. Coordination emerges from the shared environment, not from direct orchestration.

### Claude Code realities

Claude Code's agent model is not natively reactive — agents run, produce output, and stop. To simulate a reactive system you need scaffolding. The feasible options, from cheapest to most authentic:

1. **Pseudo-reactive polling loop** *(cheapest, works today)*. A single coordinator agent runs in a loop. Each iteration it checks state (which tests are red, whether the build is green, how long since the last refactor, what changed in the worktree). Based on state, it spawns the tester, coder, or refactorer as a subagent via the `Agent` tool to do one unit of work. Not true parallelism, but it's event-driven in spirit and easy to build with existing tools.

2. **Background agents + Monitor**. Spawn tester, coder, and refactorer with `run_in_background: true`. Run `npm test --watch` (or equivalent) as a background process. Use the `Monitor` tool on that process to stream build events. A lightweight dispatcher agent consumes Monitor events and wakes the right role via `SendMessage`. Closer to true reactivity; harder to debug.

3. **Hook-driven dispatch**. Configure `PostToolUse` hooks so that whenever any agent writes a file, a hook fires a dispatcher that re-evaluates state and messages the other roles. Works only within the bounds of what hooks can observe (tool calls in the current session), so this is more fragile than option 2.

4. **External file watcher + webhook**. Run an actual `fswatch` / `entr` process outside Claude Code that calls a small dispatcher script on every file change, which in turn triggers Claude Code agents. Most authentic, most moving parts, least contained.

Option 1 is the right starting point: it captures most of the value of reactivity (the tester continuously probes, the coder only reacts to red, the refactorer only reacts to quiet green) without needing the harness to actually run three agents concurrently. You lose genuine parallelism but keep the key property — *agents act because of state, not because it's their turn.*

### When to prefer reactive over turn-based

| Situation | Prefer |
|---|---|
| Narrow, well-scoped task with clear acceptance criteria | Turn-based — simpler, cheaper, easier to terminate |
| Exploratory implementation where the spec has gaps | Reactive — the tester's continuous probing surfaces gaps faster |
| Hot-path code that will be refactored heavily | Reactive — the refactorer-as-writer cycles faster |
| High-stakes code where auditability matters | Turn-based — the review log is a cleaner audit trail |
| Small sub-team cost budget | Turn-based — three agents worth of compute, not four |
| Developer actually wants to watch it happen live | Reactive — it feels like a working TDD pair and a senior dev on your shoulder |

The two modes are not mutually exclusive. A task could start reactive (for rapid exploration and gap-finding) and then switch to turn-based (for the final rigorous pass and the audit trail). Or run turn-based by default and flip to reactive when the turn-based loop gets stuck — letting the refactorer actually rewrite rather than just requesting a rewrite may be exactly what unblocks a `STUCK` state.

### New open questions introduced by the reactive variant

1. **Is the proposal queue worth the plumbing?** Role-scoped write areas plus a refactorer lock might be enough in practice. The queue only earns its keep if the refactorer often proposes changes that conflict with in-flight coder work.

2. **Does the refactorer need to justify each rewrite against the design, the way the turn-based reviewer justifies each `CONTINUE`?** Probably yes — without that, the refactorer just becomes a stylistic rewriter. Require a one-line rationale tied to an architectural goal per refactor.

3. **How do we avoid the refactorer and the tester racing to "fix" the same structural smell from opposite directions?** E.g., tester sees weak coverage and adds tests; refactorer sees the same weakness and restructures to remove the ambiguity. Both are valid responses, but doing both produces waste. The refactorer-backoff rule partly handles this — tester goes first because it runs on every code change, refactorer waits for quiet.

4. **Can a single model context play tester, coder, and refactorer by time-slicing, or does the adversarial dynamic require actually separate agent contexts?** Same question as the turn-based version, slightly sharper here: reactivity is *especially* vulnerable to a single-mind collapse because there's no hand-off moment to force a context switch.

---

## Round-Robin Variant — Self-Directed Cycle

Between the original turn-based loop (reviewer schedules every move) and the reactive variant (event handlers firing on state changes) sits a third option that may be the most practical of the three: **each role takes its turn in a fixed order and decides for itself what to do based on the current state.**

This keeps the determinism and simplicity of turn-based — no write contention, no oscillation risk, no watcher scaffolding — while removing the central scheduler. Each role becomes self-directed within its turn. The cycle is the coordination; the state is the message.

### The cycle

```
     ┌─────────────────────┐
     │                     │
     ▼                     │
 ┌────────┐                │
 │ Tester │                │
 │  turn  │                │
 └───┬────┘                │
     │                     │
     ▼                     │
 ┌────────┐                │
 │ Coder  │                │
 │  turn  │                │
 └───┬────┘                │
     │                     │
     ▼                     │
 ┌──────────┐              │
 │  Senior  │              │
 │  turn    │              │
 └───┬──────┘              │
     │                     │
     └─────────────────────┘
       (loop until a full cycle is all no-ops)
```

Each turn is a short decision:

**Tester's turn**:
- Did the code change since my last turn? → re-check coverage of the changed surface; if there's a gap, add a failing test
- Is there a spec requirement I haven't tested yet? → add a failing test for it
- Are there edge cases or failure modes in the current scope I haven't probed? → add a failing test
- If none of the above: **no-op**, pass the turn

**Coder's turn**:
- Is the build broken or are any tests failing? → make the minimum change to restore green
- Is there a test written last turn that I haven't satisfied yet? → make it pass
- If none of the above: **no-op**, pass the turn

**Senior (refactorer) turn**:
- Is the build green? (if not, refuse to act — this is the coder's job)
- Has enough changed since my last pass to warrant re-evaluation?
- Does the current shape still fit the design, or has coupling/cohesion/clarity degraded?
- If there's a worthwhile structural improvement: refactor it, preserving behavior
- If none of the above: **no-op**, pass the turn

### Termination

A **full cycle of no-ops** — tester no-ops, coder no-ops, senior no-ops, in the same pass — means the sub-team is done. There is nothing the tester wants to probe, nothing the coder needs to fix, and nothing the senior wants to reshape. That's the signal.

To guard against a lazy turn followed by a productive one giving a false done signal, require **two consecutive** fully-idle cycles before terminating. A single idle cycle is "stable"; two in a row is "settled."

The tester's final pass before termination should be an explicit **spec-coverage audit**: walk the spec, check each requirement has a test, verify all tests pass. Only after this audit passes can the tester legitimately no-op on a termination cycle. This prevents the common failure where the tester runs out of things to probe locally but hasn't actually checked global coverage.

### Why this sidesteps the hard problems

| Reactive problem | How round-robin avoids it |
|---|---|
| **Write contention** | Only one role holds the pen at a time. Never a conflict. |
| **Oscillation** | Each role must wait a full cycle to react. Natural damping — the tester can't chase a refactor instantly, the refactorer can't chase a new test instantly. Cycles get quieter, not louder. |
| **Termination** | Fall out naturally: full-idle cycle = done. No separate terminator role needed. |
| **Watcher scaffolding** | None. No file watcher, no event dispatcher, no proposal queue. Just three sequential Agent calls in a loop. |

### The trade-offs it keeps

**Cost**: every cycle runs all three agents, even when two or all three will no-op. This is the main cost of the simplicity. Mitigations:

- **State-check short-circuit**: each role's prompt leads with a cheap assessment — "check git diff since last turn, check test status, check coverage delta" — and exits fast if there's nothing to do. A no-op turn should be a small fraction of a full acting turn's tokens.
- **Skip patterns**: if the coder and senior no-op'd last cycle and the tester just wrote one test, skip straight to the coder (you know the senior has nothing to do on a freshly-red state). These are predictable enough to bake into the cycle driver.
- **Adaptive cycle length**: early cycles visit all three roles every time (lots to do), later cycles may only visit the role whose turn it is. Start broad, narrow as the state settles.

**Latency**: the tester can't react to a code change until its next turn comes up. In a three-role cycle, that's worst-case two turns of lag. For this kind of work, two-turn lag is fine — it's actually *useful* damping.

**Starvation**: if the tester consistently finds new things, the senior might not get a meaningful turn for a while. This is less of a concern than it sounds, because the senior runs every cycle; small structural improvements compound across many small turns rather than waiting for a big rewrite pass. If the senior is frequently no-op'ing, that's a feature: it means the shape is holding up.

### What each role's prompt looks like

The prompts are almost the same as the turn-based version, with one critical addition: **each role's first job on its turn is to assess state and decide whether to act.** The prompt gets a "decision framework" section:

```markdown
## Your Turn

When you are spawned, the cycle has handed you the pen. Your job has
two steps:

1. **Assess**: read the shared transcript, check git status since
   your last turn, run the test suite, check coverage. Decide
   whether you have anything to do.
2. **Act or yield**: if there's work for your role in the current
   state, do exactly one unit of it. If not, write NO-OP to the
   transcript with a one-line reason and hand back.

Do not do multiple units of work on a single turn — the cycle will
come back to you. One test, one fix, one refactor. The cycle is
your collaborator; trust it.
```

This framing is the key behavioral shift from the scheduled turn-based version. In that version, the reviewer decides *for* the tester whether there's work to do. Here, the tester decides for itself. That's more autonomous, and it's also where the agent's judgment can slip — e.g., the tester declaring "no gaps" when there are actually gaps it just didn't look hard enough for. The spec-coverage audit on the termination cycle is the backstop.

### Claude Code implementation — trivial, works today

This variant needs no scaffolding beyond what already exists:

```
# Team Lead pseudocode
idle_cycles = 0
while idle_cycles < 2:
    tester_result  = Agent(name="tester-turn",  prompt=...)
    coder_result   = Agent(name="coder-turn",   prompt=...)
    senior_result  = Agent(name="senior-turn",  prompt=...)

    if all(r == "NO-OP" for r in (tester_result, coder_result, senior_result)):
        idle_cycles += 1
    else:
        idle_cycles = 0

write_summary()
```

Three sequential `Agent` calls per cycle. Each is a fresh, focused context that reads the current worktree state, the transcript, and the spec, then does one thing or yields. The Team Lead (main session) is the cycle driver.

No Monitor, no hooks, no fswatch, no proposal queue. Just a loop.

### Three modes side by side

| Property | Turn-based (reviewer-scheduled) | **Round-robin (self-directed)** | Reactive (event-driven) |
|---|---|---|---|
| Who decides what happens | The reviewer schedules each step | **Each role, on its turn, from state** | State changes trigger handlers |
| Concurrency | None | **None** | Up to three |
| Write contention | None | **None** | Real (needs a queue or lock) |
| Oscillation risk | None | **Low (cycle = natural damping)** | High (needs explicit damping) |
| Termination signal | Reviewer says DONE | **Two consecutive idle cycles** | Separate terminator role needed |
| Scheduler overhead | Reviewer context grows with the loop | **None — the cycle is the scheduler** | Dispatcher process needed |
| Implementation in Claude Code | Doable today | **Trivial today — just a loop** | Needs scaffolding (Monitor, hooks, or fswatch) |
| Risk of single-mind collapse | Low (three distinct agents) | **Low (three distinct agents per turn)** | Low (three distinct agents) |
| How it feels | Formal review meeting | **A dev standup that just keeps going** | A live pairing session |

The round-robin variant is the one I'd actually start with. It captures the essence of the adversarial TDD idea — three opposed roles, a real test-first discipline, a senior voice preserving the big picture — with the minimum possible machinery. The reviewer-scheduled version is a more rigorous fallback for high-stakes work where you want the explicit `REVIEW-LOG.md` audit trail. The reactive version is an experimental target for later, when the other two modes are working well enough that the extra plumbing is justified by real evidence that parallelism would help.

### Open questions for the round-robin variant

1. **Does the senior need a "cool-down" rule?** Without one, the senior might refactor on every turn just because it sees room for improvement, never letting the code stabilize. A simple rule — "only refactor if the last N senior turns would have been no-ops with this code unchanged" — forces the senior to prefer stability when the shape is already acceptable.

2. **What belongs in the shared transcript vs. each role's own notes?** The transcript is the state every role reads on its turn, so it needs to be concise. Probably: one line per turn (role, action taken, one-sentence rationale). Full diffs live in git; the transcript is the narrative overlay.

3. **How do you keep the coder from doing the senior's job?** The coder reads the current state and makes the minimum change — but if the minimum change obviously wants a small restructure, the coder will be tempted. The prompt needs to be explicit: the coder makes the narrowest possible fix, and if that fix would be cleaner as a restructure, the coder just does the narrow fix and lets the senior come along next turn.

4. **Do you need a tester cool-down too?** Similar concern from the other end: a zealous tester could keep inventing marginal tests forever. The termination audit partly handles this — a test that doesn't map to a spec requirement or a design constraint shouldn't be added. Enforced by the tester's prompt: every new test must cite the spec line or design section it defends.

---

## What Differs From a Single Implementor

| Aspect | Single implementor | Adversarial TDD sub-team |
|---|---|---|
| **Test quality** | Tests written by same mind that wrote the code | Tests written by an agent trying to break it |
| **Minimum-change discipline** | Often violated — "while I'm here" | Enforced — coder is told to do nothing more |
| **Design drift** | Detected only at final self-review, if at all | Watched iteration-by-iteration by the reviewer |
| **Speed** | Faster per iteration | Slower per iteration, but fewer wasted iterations |
| **Cost** | 1 agent context per permutation | 3 agent contexts per permutation, but per-role contexts stay smaller and more focused |
| **Failure mode** | Over-confident self-assessment | Stuck loops, over-cautious tests |

The trade-off is explicit: adversarial TDD costs more compute per permutation in exchange for higher-confidence output and earlier drift detection. It's worth it when the cost of a bad implementation is higher than the cost of the extra agent runs — e.g., high-stakes code, security-critical paths, anything where the `REJECT ALL` verdict at the competing-implementations layer would be expensive to recover from.

---

## Composition With Existing Designs

This design slots in as a refinement of the implementor role in `DESIGN-competing-implementations.md`. It does not replace anything. It can be toggled per permutation:

```yaml
permutations:
  - id: P1
    choices: [sqlite, rest]
    implementor_mode: single        # cheap, fast
  - id: P2
    choices: [sqlite, grpc]
    implementor_mode: adversarial   # three-role TDD sub-team
```

This lets the Team Lead reserve the adversarial mode for permutations where the extra rigor pays off and run the rest cheap.

Similarly, this composes with `DESIGN-bidder-profiles.md`: bidder profiles diverge at the *proposal* layer, competing implementations diverge at the *choice* layer, and adversarial TDD diverges at the *role* layer within a single implementation. All three can be used together or independently.

---

## Open Questions

1. **How much transcript does the reviewer actually need?** A full turn-by-turn log might bloat context. Probably just the test diff, code diff, and the reviewer's own running notes — raw tool output can be dropped.

2. **Can the tester and coder share a single agent's context switched by prompt, to save compute?** Tempting for cost, but likely kills the adversarial dynamic — one mind can't genuinely oppose itself. The three-agent separation is probably load-bearing.

3. **Does the reviewer need to see the spec once or re-read it every iteration?** Spec content is static; caching it is safe. The design doc and REVIEW-LOG.md are the things that evolve.

4. **What happens if the tester and coder deadlock — tester keeps adding tests, coder keeps barely passing them, reviewer never sees progress toward "done"?** The reviewer has to notice the loop isn't converging and call `STUCK`. Worth defining explicit convergence signals: tests added but no new spec coverage, code changes getting more contorted, coverage metric flat.

5. **Should the reviewer role be filled by the same agent that wrote the design?** Appealing — the original architect has the strongest grasp of intent — but risks self-justification (reviewer rubber-stamps its own earlier decisions). A fresh reviewer reading the design cold may actually catch more drift.

6. **Integration with the judge layer**: if each permutation is now produced by a sub-team, does the judge read the sub-team's REVIEW-LOG.md as evidence? Probably yes — it's a high-signal record of how the implementation actually came together, and of what nearly went wrong.

---

## Migration Path

1. Define the three role prompts as new rule files: `adversarial-tester.md`, `adversarial-coder.md`, `adversarial-reviewer.md`.
2. Extend the competing-implementations Team Lead prompt to support spawning a sub-team (three agents sharing one worktree) as an alternative to a single implementor.
3. Define the shared transcript format and the role-exclusive artifact files (`COVERAGE-NOTES.md`, `CHANGE-NOTES.md`, `REVIEW-LOG.md`).
4. Add per-permutation `implementor_mode: single | adversarial` configuration.
5. Run a small end-to-end pilot on a task with a known-tricky edge case and compare:
   - Did the adversarial sub-team surface the edge case the single implementor missed?
   - How much more compute did it cost?
   - Was the `REVIEW-LOG.md` useful signal for the judge?
6. If the pilot is positive, document adversarial TDD as the default mode for high-stakes permutations and keep single-implementor as the fast path.
