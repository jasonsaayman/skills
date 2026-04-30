---
name: review-comment
description: Turn an internal PR review (typically the output of /review-pr) into a posted-ready GitHub review comment in Jay's voice — technical but casual, direct without being curt, warm without being corporate. Invoke when the user says "give me a comment to post", "humanize this", "draft a review comment", or types `/review-comment`. Does not post by default — output only.
---

# review-comment — humanize a PR review for posting

Run when the user wants the internal review (from `/review-pr` or similar) converted into a comment they can post on a GitHub PR. The output should sound like Jay actually wrote it — not a template, not corporate review-speak, not a bullet-point report.

## What this skill is for

`/review-pr` produces a structured internal review with mandatory sections (Verdict, Semver, Breaking changes, Documentation, Performance, Blocking issues, etc.). That structure is for **Jay's** decision-making — it is not what should be posted on the PR. A contributor reading the comment doesn't need a "Semver: patch" line; they need to know what to change and feel like a human is talking to them.

This skill takes the substance of the internal review (the actual blocking issues, nits, and good things) and rewrites it in Jay's voice, dropping the taxonomy.

## Voice — Jay's patterns

These are extracted from his real comments on axios issues and PRs. Apply them; don't just describe them.

### Tone

- **Technical but casual.** Direct on the technical substance, relaxed on the wrapper. He does not soften feedback with corporate hedges ("It would be advisable to consider…") and he does not bark either. He says what's wrong, what to do, and moves on.
- **Warm at the edges, briefly.** Open with a plain thanks for the PR — that's it. Don't praise specific things the contributor did right ("nice catch on X", "adapter parity is clean too"); skip straight from "thanks" to the substance. Close with a thanks, a "happy to…", or a clear next step.
- **First person plural for the project, first person singular for personal action.** "We don't merge without tests on the fetch path" / "I will pull this in once the tests are added".
- **No emojis. No "LGTM". No "Per the contributing guide…".** He doesn't write like that.

### Sentence rhythm and casing

- **Always capitalize `I`.** No lowercase `i` for the first-person pronoun, even in casual comments. This is a hard rule. His real writing varies, but for posted review comments use capital `I` consistently.
- **Never use dashes or em dashes in the output.** No `-`, no `—`, no `–` joining clauses. This is a hard rule for the posted comment text. Where you would reach for an em dash, use a period, a comma, parentheses, or a colon instead. (File paths like `lib/adapters/http.js` and ranges inside code blocks are not affected; this rule is about prose punctuation only.)
- Short sentences. Often comma-spliced where a period would also work. That's part of the rhythm, leave it.
- Common openers: "Thanks for the patch", "Thanks for picking this up", "Thanks for the PR". Keep the opener to one short sentence with no "and nice catch on…" tail.
- **Mandatory closer.** Always end the comment with: `Let me know when the PR has been updated and I will take a look again`. Place it on its own line after any nits section. Do not paraphrase, do not append "thanks" or anything else after it. This is the standing sign-off.
- Don't be afraid of a one-line reply. "HTTP2 is coming to v1.x" is a complete answer in his voice. If the review has only one issue, a 2 or 3 sentence comment is the right shape, don't pad.

### Anti-patterns (do not write these)

- **Don't enumerate the internal taxonomy.** No "**Semver:** patch", no "**Breaking changes:** None", no "**Performance & regression risk:** Low". The contributor doesn't read those.
- **Don't write headings unless the comment is genuinely long.** A 4-paragraph comment with `## Blocking issues` headers feels like a report, not a conversation. Use bold inline (`**1. The first test is a tautology.**`) when you need to delineate, or just numbered points.
- **Don't use review-speak verbs.** Avoid "I would recommend that you consider", "It is advisable to", "Per our guidelines", "Kindly". Use: "can you", "let's", "we'll need", "needs", "drop it", "rewrite this to…".
- **Don't apologize for asking for changes.** "Sorry but unfortunately I'm going to have to request changes here". Just say what needs to change.
- **Don't restate what the PR does.** The contributor knows.
- **Don't compliment specific things in the opener.** Skip "nice catch on the second commit", "adapter parity is clean", "good test coverage". Just thank them for the PR and move into the substance. The absence of a complaint is the compliment.
- **No dashes or em dashes joining clauses.** If you find yourself writing `something — and another thing`, replace the dash with a period or comma. This is the most common slip; double-check the draft before printing.
- **Don't claim things are blocking when they aren't.** If a nit is genuinely optional, say so ("non-blocking, take it or leave it").

## Process

1. **Read the conversation context** for the most recent `/review-pr` output. The Verdict, Blocking issues, Non-blocking suggestions, and Looks good sections are the substance. If the user asks for a comment without a prior review, say so and offer to run `/review-pr <PR#>` first.
2. **Pick the register.** Three rough sizes:
   - **Short** (1–3 sentences): clean PR with one nit, or an outright approve. No headings, no structure.
   - **Medium** (1–2 short paragraphs + numbered points): typical "request changes" with 1–3 issues.
   - **Long** (multiple sections, code blocks): only when there are 4+ distinct issues or the technical substance genuinely needs it. Even then, keep prose around the bullets.
3. **Open with a plain thanks.** One short sentence: "Thanks for the patch @username," or "Thanks for the PR @username,". Then go straight into the substance. Do not append "and nice catch on X" or any other specific compliment. If a verdict signal helps clarity, fold it into the lead-in to the first point ("a couple of things to address before this can go in") rather than the thanks itself.
4. **Translate each blocking issue** from the internal review into one numbered point. Each point should have a bolded one-line summary, a file:line reference, what's wrong, and what to do. Use code blocks when quoting the diff or showing what the fix should look like. Keep technical density high, prose density low.
5. **Add a Non-blocking nits section** only if there are nits and only after blockers. Mark them clearly so the contributor doesn't think they have to address them. Phrase as suggestions, not demands.
6. **Close with the mandatory sign-off.** End with exactly: `Let me know when the PR has been updated and I will take a look again`. On its own line. Nothing after it. No "thanks!", no extra sentence, no variation in wording.

## Voice reference — real fragments from Jay

Use these as anchors for cadence and word choice. Don't copy them; match the *shape*.

> "to answer the NPM question. i have been told that once the RAT is on your machine they have full unilateral control of everything on your machine"

> "thanks @JamieMagee i will make this update. any chance you can put me in touch with someone who can help me with security on my own account"

> "@cctidal i will add it to my list thanks"

> "Closing this issue, we will start publishing the features we are working on and working towards on our website https://axios.rest"

> "HTTP2 is coming to v1.x"

> "A bit of an update, I think this is still the direction I want to take however I am approaching it in a bit of a different manner. Keep your eyes on the repo and releases as I am actively working to bring axios up to date with modern libs, testing and tooling!"

> "Since no comments have been made in about a week, I am going to close this issue. If anyone would like me to reopen this, I am happy to do so. Just reach out to me."

Notes on what these tell us:
- Direct address with `@username` is common when responding to a specific person.
- His real comments use lowercase `i` for the pronoun in many places — for posted PR review comments we deliberately normalize to capital `I` (his stated preference for this format). Do not copy the lowercase `i` from the quoted fragments above.
- He gives the *reason* and the *next step* in one breath. "Closing this … please re-create an issue if you still want this looked into."
- Where most maintainers would write a polite multi-paragraph rejection, he writes a sentence. Match that economy.

## Output

Print the comment as a single fenced markdown block so the user can copy-paste straight into GitHub:

````markdown
<the comment>
````

After the block, add one short line under it noting any choices the user might want to override (e.g. "Kept it short since the only issue is the missing test", or "Folded the verdict signal into the lead-in to point 1"). Keep this aside under one sentence. Skip it if there's nothing notable. Do not flag the casing — capital `I` is the standing rule and not a choice to surface every time.

## Posting

This skill **does not** post the comment. The output is for the user to copy or to explicitly ask for posting. If they say "post it", use:

```bash
gh pr review <PR#> --repo axios/axios <--comment|--request-changes|--approve> -F -
```

with the comment piped on stdin. Pick the verb based on the verdict in the source review — `--request-changes` for blocking issues, `--comment` for nit-only or discussion, `--approve` only when the source review was a clean approve. Confirm the verb with the user before running if there's any ambiguity.

## What this skill does NOT do

- Does not generate a review from scratch — it humanizes an existing one. If there is no prior review in the conversation, ask the user to run `/review-pr` first or paste the substance.
- Does not change the technical verdict. If the source review says "request changes" and the contributor's PR has real blockers, the comment must still ask for changes — even if a softer voice could paper over them. Voice is the wrapper; substance is fixed.
- Does not invent praise. "Looks good" sections only translate if the source review actually flagged something the contributor did right. Don't fabricate a compliment to pad the opener — pick something real or skip it.
