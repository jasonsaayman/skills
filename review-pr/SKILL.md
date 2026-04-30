---
name: review-pr
description: Review a GitHub PR against the axios repo using axios-specific criteria (platform parity, type definitions, security, tests, conventional commits, docs, semver, breaking changes, performance & regression risk). Holds the line for a 100M-weekly-download library — no regressions, no perf loss, no sloppiness. User-invoked via `/review-pr <PR#>`. Always fetches the PR from GitHub via `gh`.
---

# review-pr — axios PR review

Run when the user types `/review-pr <PR#>` (or `/review-pr <github-pr-url>`). This skill reviews a PR in the axios repo with the project-specific bar maintainers actually apply.

## The quality bar

Axios is downloaded **~100 million times per week**. Every line that ships hits a global blast radius: a regression breaks tens of millions of apps; a 1% slowdown costs the ecosystem real CPU; a sloppy patch becomes a maintenance tax forever. **Optimize for never shipping a regression**, in this order: correctness → security → performance → ergonomics → diff size. When in doubt, lean toward **request changes**: it is always cheaper to revise than to revert. Do not approve "looks fine" — a PR either clearly meets the bar or it doesn't.

Concretely, this means:
- **No regressions.** A behavior the existing test suite covers must not change unless the PR is explicitly labeled breaking and routed accordingly (see section 6).
- **No silent perf loss.** New allocations in hot paths, extra `await` round-trips, redundant `Object.assign`/spread, regex recompilation per call, sync work in interceptor chains, and unnecessary `JSON.parse`/`stringify` are all flagged (see section 11).
- **No sloppiness.** Half-finished edge cases, "TODO: handle later", commented-out code, console.logs, dead branches, lint suppressions without a reason, and copy-paste between adapters that drifts are all blockers.

## Inputs

The user must supply a PR number or URL. If they don't, ask once:

> Which PR? (number like `10782` or full URL)

Do not invent a PR number, and do not review the current branch — this skill is GitHub-PR-only.

## Step 1 — Fetch the PR

Run these in parallel via `gh`:

- `gh pr view <PR#> --json number,title,author,baseRefName,headRefName,state,isDraft,labels,body,additions,deletions,changedFiles,commits,files,reviewDecision,statusCheckRollup`
- `gh pr diff <PR#>`
- `gh pr checks <PR#>` (non-fatal if no checks)

If the PR targets a base branch other than `v1.x`, flag it and confirm with the user before continuing — axios maintains release branches separately and a v2/main PR has different review criteria.

If the diff is large (>2000 lines or >40 files), say so up front and tell the user you'll review in passes rather than line-by-line.

## Step 2 — Review against the axios checklist

Walk these in order. For each finding, cite `file:line` so the user can jump.

### 1. Conventional commits & PR hygiene
- Every commit subject matches `<type>(<scope>): <subject>` (`feat`, `fix`, `docs`, `chore`, `refactor`, `test`, `perf`, `build`, `ci`, `revert`). Header ≤ 130 chars (commitlint).
- PR title follows the same convention (it becomes the squash commit).
- PR body filled in (not the empty template). Linked issue for non-trivial features.
- Failing test and the fix are in **separate commits** when applicable (PR template asks for this).

### 2. Platform parity (high-frequency miss)
If the change touches request/response behavior, check **all three** adapters:
- `lib/adapters/http.js` — Node
- `lib/adapters/xhr.js` — browser (XHR)
- `lib/adapters/fetch.js` — browser/node fetch

A change that lands in one adapter but not the others is the single most common review block on this repo. Call it out even if the PR description claims it's "Node-only."

### 3. Tests
- New behavior has tests in `test/unit/**/*.test.js` (Vitest, Node) and — if user-facing in the browser — `test/unit/**/*.browser.test.js` (Vitest + Playwright).
- Bug fixes include a regression test that **fails without the fix**.
- Security fixes (SSRF, proto pollution, header injection, max-content-length, redirect handling) **must** have regression tests — non-negotiable.
- Don't accept "manually tested" as a substitute.

### 4. TypeScript definitions
- Public API changes update **both** `index.d.ts` (ESM) and `index.d.cts` (CJS). Drift between the two is a common bug.
- New options, headers, error classes (`CanceledError`, `AxiosError`, `AxiosHeaders`, etc.) are exported.
- Generic parameters preserved (don't widen `T` to `any`).

### 5. Security review
Apply extra scrutiny on these paths:
- `lib/helpers/` (URL parsing, header handling, form data, cookies)
- `lib/core/` (dispatchRequest, mergeConfig, settle)
- `lib/adapters/http.js` (socketPath, redirects, max body size, proxy)

Watch for:
- **Prototype pollution** — any `Object.assign`, `merge`, or property copy without `Object.prototype.hasOwnProperty.call` / own-property guard.
- **SSRF** — accepting unvalidated URLs/socket paths from config.
- **Resource exhaustion** — bypassing `maxContentLength` / `maxBodyLength` / timeouts.
- **Header injection** — CRLF in user-supplied header values.
- Reverting or weakening an existing security check (compare against `git log -p -- <file>` for that line).

### 6. Behavior compatibility, semver, and breaking changes
**These three checks are mandatory on every review and must appear in the output, even when the answer is "none."**

**Semver classification.** Pick exactly one and justify it in one line:
- **major** — public API removed/renamed, default behavior changed, error-class hierarchy changed, type-definition signature narrowed in a way that breaks existing consumers, dependency dropped.
- **minor** — new public API, new option, new exported type, new error code, new adapter capability — strictly additive.
- **patch** — bug fix, internal refactor, docs/test/CI/build only, performance fix without behavior change.

If you classify as **major**, this is a **breaking change** — see below. If a PR mixes a minor feature with an incidental breaking change, the whole PR is major.

**Breaking-change call-out.** A change is breaking if it would cause an existing, correct user program to behave differently after `npm update` within the same major. Examples that are easy to miss:
- Default-value changes (`maxRedirects`, `validateStatus`, default headers, default adapter order).
- Error-message wording (users grep for these in tests).
- Throwing where the old path returned, returning where it threw, or changing the resolved/rejected shape.
- Tightening or loosening a type-definition signature in `index.d.ts` / `index.d.cts`.
- Changing what `Object.keys(axios)` or `axios.defaults` enumerate.
- Removing or renaming an exported symbol — even an "internal-looking" one in `lib/`, since `./unsafe/*` re-exports several internals.

For each breaking change identified: name it, cite `file:line`, describe the user-visible behavior diff, and recommend whether to gate it (deprecation warning + opt-in flag) or accept it (next major; this PR retargets `v2.x` or waits).

Deprecations should keep the old path working with a one-time warning, not throw.

### 7. Documentation
**Mandatory check on every review.** Determine whether the PR requires doc updates and call it out explicitly — including a "no docs needed" line when that's the case.

Triggers that require docs:
- New or changed public API (config option, method signature, error class, exported type).
- New or changed default value.
- New or changed error code (`AxiosError.ERR_*`).
- New CLI/runtime support (Deno, Bun, React Native) or platform behavior change.
- Breaking change of any kind — must update both docs and `MIGRATION_GUIDE.md`.

Where docs live:
- **`README.md`** — top-level usage, option tables, examples. Most user-facing PRs need a README touch.
- **`docs/`** — VuePress site source (the published `axios-http.com` content). Deeper API reference and guides live here.
- **`MIGRATION_GUIDE.md`** — required for any breaking change or non-trivial deprecation.
- **`CHANGELOG.md`** — see section 9; user-visible changes need an entry.
- **JSDoc in `lib/`** — new public functions/methods need `@param` / `@returns`.
- **TypeScript doc comments in `index.d.ts` / `index.d.cts`** — keep in sync with JSDoc.

If the PR adds a public-facing change without touching any of these, request docs as a blocking issue (or non-blocking if the change is small and the maintainer commonly handles docs in a follow-up — note which).

### 8. Build & artifacts
- `dist/` is **not** committed in v1.x — if the PR includes `dist/` changes, flag for removal.
- `package.json` version bumps shouldn't be in feature PRs (releases are separate).
- New runtime deps need justification (axios is intentionally light).

### 9. CHANGELOG.md
- User-visible changes (feat / fix / breaking / security) need a CHANGELOG entry under the appropriate Unreleased section. Pure `chore`/`docs`/`test`/`refactor` PRs don't.

### 10. CI signal
Read `gh pr checks` output. If checks are failing, summarize which job and (if possible) the failure cause from `gh run view`. Don't approve over red CI.

### 11. Performance & regression risk (mandatory)
Axios sits in the request hot path of millions of services — performance review is **never optional**. Even on a "small" PR, walk this list and report findings explicitly (see the **Performance & regression risk** output section).

**Hot paths to guard.** Treat any change touching these as performance-sensitive by default:
- `lib/core/dispatchRequest.js`, `lib/core/Axios.js`, `lib/core/InterceptorManager.js` — every request goes through here.
- `lib/core/AxiosHeaders.js` — header normalization runs per request and per response.
- `lib/core/mergeConfig.js` — runs on every call, including instance creation.
- `lib/adapters/{http,xhr,fetch}.js` — request loop / streaming.
- `lib/utils.js` type-checks — called dozens of times per request.
- `lib/helpers/buildURL.js`, `formDataToJSON.js`, `parseHeaders.js` — parsing/serialization on every call.

**Anti-patterns to flag in hot paths:**
- New `Object.assign({}, …)`, spread copies, or `JSON.parse(JSON.stringify(…))` clones where the previous code didn't allocate.
- Regex literals constructed inside a function body instead of hoisted to module scope.
- Promises/`async` added where sync code would do (each `await` is a microtask hop).
- New `for…in` over `for…of` / indexed loops on arrays; `Array.prototype.reduce` to build hot-path objects.
- Repeated `headers.get()` / `utils.isX()` calls on the same value within one function — hoist to a local.
- Adding listeners (e.g. `signal.addEventListener`) without a matching removal — both a leak and a perf cost over long-lived clients.
- Eager work moved out of a `runWhen` / lazy guard.
- New `try/catch` wrapping a hot loop body (V8 deopts in older engines axios still supports).

**Regression risk to flag:**
- Behavior touched by existing tests but no test updated — either the test should change (and the PR explains why) or the behavior shouldn't.
- Adapter-specific change without the parity check from section 2 — silent regressions on the adapter that wasn't tested locally.
- Default-value flip (see section 6) — even a "more correct" default breaks consumers depending on the old one.
- Removing a defensive check (`if (!signal) return`, null-guards in `mergeConfig`) — almost always re-introduces an old bug; check `git blame` for the original fix.
- Touching code referenced by `tests/smoke/**` or `tests/module/**` without re-running those suites — these catch packaging regressions CI sometimes lets through.

**When perf is plausibly impacted, ask for evidence.** A microbenchmark run, before/after `node --prof` numbers, or a comparison against a current adapter baseline — pick whichever fits. "Looks faster" is not evidence. If the PR claims a perf improvement, the author owns providing the numbers.

**Sloppiness signals (block on these):**
- Commented-out code, leftover `console.log` / `debugger` / `.only` / `.skip`.
- TODO/FIXME without an accompanying issue link.
- ESLint disables without a `// eslint-disable-next-line <rule> -- <reason>` comment.
- Identical fix copy-pasted across the three adapters with subtle drift between copies — extract a helper.
- Type definitions updated in one of `.d.ts`/`.d.cts` but not the other (already covered in section 4 — re-flag here as a sloppiness signal).
- New public API with no JSDoc.

### 12. Disposition — close vs. revise (mandatory)

A reviewer's job isn't only "approve or request changes" — sometimes the right call is **close the PR**, and (if the underlying bug or feature need is real and not already tracked) **open a fresh issue** so a maintainer or another contributor can take a clean swing. Iterating in-place is the default, but it's the wrong move when:

- **Approach is fundamentally wrong.** The PR addresses a real problem but the fix is in the wrong layer, papers over a deeper issue, or would require effectively rewriting the patch to land. Asking the author to redo it from scratch is worse than closing and re-routing through a clean issue with a clear problem statement.
- **Scope is unsalvageable.** Mixes unrelated changes, refactors, or drive-by fixes that can't be reasonably split apart at this point. A new issue + new PR is faster than untangling.
- **Architectural / design call needed first.** The change affects public API, defaults, adapter selection, error semantics, or cross-cutting concerns and needs maintainer-level discussion before code. The PR is premature — close, open a design issue capturing the problem and trade-offs, route the decision through there.
- **Out of scope for axios.** Belongs in user code, a separate adapter package, or a downstream library — not in core.
- **Stale / abandoned.** Author hasn't responded for an extended period (check `commits[0].committedDate` and last review activity) and the change still applies but needs work. Close with thanks; open a tracking issue if the underlying bug is real.
- **Duplicate or already fixed.** Superseded by another PR, already landed, or fixed indirectly by an upstream dep bump. Verify with `gh pr list --search "<keywords>"` and `git log --all --grep="<keywords>"` before recommending close.
- **Wrong base branch with significant divergence.** Targets `master` or another branch and rebasing onto `v1.x` would change too much of the diff — easier to close and reopen against the correct base.

When recommending close, **always**:
- Search for an existing issue first: `gh issue list --search "<keywords>" --state all`. Never recommend opening a duplicate tracking issue.
- State whether a new issue should be opened and what it should capture: the problem statement, a minimal repro (carry the PR's test over if there is one), why this PR's approach didn't work, and any prior art worth preserving (links, related PRs).
- Draft a **short, kind close message** the maintainer can paste verbatim: thank the author by name, summarize why the PR isn't the right path forward in one or two sentences, link the issue if one is being opened, and invite a follow-up if appropriate. Closing should never feel dismissive — first-time contributors especially read tone closely.

Closing is not failure — it's **routing**. A clean issue is more useful to the project than a half-fixed PR that nobody wants to merge and nobody wants to close. Conversely, do not recommend close as a way to avoid a hard review; if the PR is salvageable in one or two rounds of feedback, request changes instead.

## Step 3 — Output the review

Format the response as:

```
# PR #<num> — <title>
**Author:** @<login>  **Base:** <base>  **Files:** <n>  **+<add>/-<del>**
**CI:** <pass|fail|pending summary>

## Verdict
<one of: Approve · Approve with nits · Request changes · Block · Close>
<one-sentence rationale>

## Disposition
**<Continue (revise in-place) | Close + open tracking issue | Close (duplicate / superseded / out-of-scope) | Close (stale, no issue needed)>**
<one-sentence rationale>
<if "Close + open tracking issue": include a bullet with — proposed issue title, one-paragraph problem statement, what to carry over from this PR (failing test, repro, prior art), and any existing-issue search you ran (`gh issue list --search "..."`)>
<if any "Close" disposition: include a 2–3 sentence draft close message the maintainer can paste — thank the author by name, explain why this PR isn't the path forward, link the new/existing issue, invite follow-up>

## Semver
**<major | minor | patch>** — <one-line justification>

## Breaking changes
<"None." or a bulleted list — each item names the change, cites file:line, and describes the user-visible behavior diff>

## Documentation
<"No docs needed — <reason>." OR a bulleted list of required updates: README.md, docs/, MIGRATION_GUIDE.md, JSDoc, type-definition comments — each with file path>

## Performance & regression risk
**Hot path touched:** <yes/no — which file(s) from section 11>
**Allocations / perf:** <"No new hot-path allocations." OR specific concerns with file:line>
**Regression risk:** <"Low — covered by existing tests." OR specific risks: existing-test-changed-without-explanation, adapter-parity gap, removed defensive check, etc.>
**Evidence requested:** <"None." OR "Author should provide before/after numbers for X.">

## Blocking issues
- <file:line> — <what's wrong> — <what to do>
…

## Non-blocking suggestions
- <file:line> — <suggestion>
…

## Looks good
- <thing the PR did right — call this out, especially for first-time contributors>
```

The **Disposition**, **Semver**, **Breaking changes**, **Documentation**, and **Performance & regression risk** sections are mandatory — always emit them, even when the answer is "continue / patch / None / no docs needed / low risk." A missing section is a skill bug.

Verdict rules:
- **Block** = security regression, broken tests, breaking change on v1.x without sign-off, performance regression in a hot path, removal of a defensive check, sloppiness signals (commented-out code, debugger leftovers, unjustified lint suppressions). Verdict can still be Block while disposition is "Continue" — the PR is fixable, it just must not merge as-is.
- **Request changes** = missing tests, platform-parity gap, type-definition drift, conventional-commit violation, missing docs for a public-API change, missing `MIGRATION_GUIDE.md` entry for a breaking change, plausible perf concern without evidence, copy-paste drift between adapters.
- **Approve with nits** = small style/comment/changelog issues only.
- **Approve** = clean — and only when every mandatory section comes back clean. The default for an ambiguous PR is **request changes**, not approve.
- **Close** = the right disposition is to close the PR, not iterate. Use when the approach is wrong-layer, scope is unsalvageable, a design call is needed first, the change is out-of-scope, the PR is duplicate/superseded, or it's stale beyond rescue (see section 12). Always pair a Close verdict with an explicit decision in **Disposition** about whether to open a tracking issue, and include the draft close message there.

Verdict and disposition are independent axes — a "Block" verdict can still recommend "Continue" when the PR is fixable; an "Approve with nits" verdict can still recommend "Close" only in the rare case of a duplicate that overlaps a strictly better PR. Most reviews will pair Verdict and Disposition naturally; when they diverge, explain why in the rationale.

Keep blocking issues short and actionable. Don't pad with generic advice.

## What this skill does NOT do

- Does not post the review to GitHub. Stop at the printed review unless the user explicitly says "post it" — at which point use `gh pr review <PR#> --comment|--approve|--request-changes -F -` with the body piped in.
- Does not check out the PR branch locally (review from the diff). If you genuinely need to run code, ask first.
- Does not run the test suite unless the user asks — CI already does.
