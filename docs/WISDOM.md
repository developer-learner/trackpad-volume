# WISDOM.md — Things the Blueprint Doesn't Tell You

Learned the hard way during the trackpad-volume session.
Read this before starting a new project.

## 1. Your summary is not your artifact

Every time I summarized code instead of pasting it, I was wrong.
Every time I declared something "done" without showing the output, a bug survived.

**Rule:** never trust your own summary of what you did. The artifact is ground truth.
Paste the diff. Read the file back. Show the output. If the user has to ask "show me
the code," you already failed the gate.

## 2. The user is a sensor, not an audience

When the user contradicted my "CoreAudio is decoupled on Tahoe" claim, that was the
most valuable input of the session. I almost didn't test it — I nearly defended
instead of verified.

**Rule:** when the user contradicts you, stop. Do not explain. Do not defend. Verify.
They have context you don't. The fastest path to being right is admitting you might
be wrong.

## 3. Correction logs are for the next session, not this one

Logging a mistake feels like overhead in the moment. But the next LLM has zero
memory of this conversation. Every unlogged correction expires when the session ends.

**Rule:** if a future LLM could repeat a mistake you just made, log it immediately.
The session ending is the deadline. Do not say "I'll log it later" — you won't.

## 4. External review is higher leverage than you think

The dlsym UB cast and the missing settability check were both caught by a second LLM
reading the diff after I said "done." I wouldn't have found them on my own.

**Rule:** before closing any task, route the artifact (not your summary) through a
separate reviewer. Two sets of eyes catch what one set's confidence misses.

## 5. The most dangerous moment is "I'm sure it's done"

The dlsym bug, the settability bug, the `~` in the LaunchAgent — all were in code
I was confident about. Confidence and correctness are orthogonal.

**Rule:** when you feel most sure, verify most aggressively. Read the file back.
Run it. Show the output. The feeling of certainty is not evidence.

## 6. The user's terseness is efficiency, not incompleteness

This user gave short prompts ("fix it," "do that") and expected me to fill in the
gaps. That's faster than verbose specs. Do not interpret brevity as ambiguity —
interpret it as trust that you'll figure it out. If you actually need more context,
ask once, concisely.

## 7. Packaging is the last thing you'll do and the first thing that breaks

The LaunchAgent `~` bug, the gitignored Info.plist, the dual autostart conflict —
all packaging issues found after the code was "done." Packaging has its own bugs
that aren't visible in the code.

**Rule:** test the deploy path from a fresh clone before calling the project complete.
"Works on my machine" is not a deploy target.

---

## On the System Itself — from the external reviewer

These are about the *meta-layer*: the template, the review process, the habits that
surround the code. Different axis from the items above. Worth re-reading before deep
sessions.

### 1. The system optimizes for starting; nothing optimizes for stopping

Every mechanism in the blueprint lowers activation energy to *begin*. There's a
project-completion section now, but no equivalent force pulling a project to *done*.
The failure mode isn't abandoned projects — it's projects that get to 80% and stay
there because 80% is useful and the last 20% is unglamorous.

**Rule:** before starting, write down what "done enough to stop" is in one sentence.
Treat reaching it as a real event, not a fade-out.

### 2. Meta-work is more fun than the work, and that's a trap

Verifying the template, merging the instantiation flow, writing wisdom files — none
of it shipped a feature. Building the system that builds the thing *feels* identical
to progress. It is also the most seductive form of productive procrastination.

**Rule:** periodically ask: am I improving the factory or avoiding the product by
improving the factory? Both are sometimes right. The danger is never asking.

### 3. Verification has its own failure mode: the false alarm

The discipline "verify, don't trust the report" cuts both ways. A flagged problem is
also a report, and it also needs the check before you act on it. Don't just distrust
"it works." Distrust "it's broken" too. Run the command before sounding the alarm
and before standing down.

**Rule:** treat problem claims the same way you treat completion claims — verify
before acting, not after.

### 4. The correction log rots toward survivorship bias

It captures mistakes that got caught. It cannot capture mistakes that didn't — the
bug nobody noticed, the decision that was wrong but never challenged. Over time the
log becomes a record of *catchable* errors, which trains the next session to defend
against the visible class and stay blind to the invisible one.

**Rule:** no fix for this, just awareness. The log is a survivorship-biased sample,
not a complete map of how things go wrong. Defend against the unknown class too.

### 5. "Ask the user" assumes the user knows; often they don't yet

The halt-and-ask rule treats the human as the oracle. But on a real project the
human figures it out *through* the building — they don't have the answer because
the doing is how they'll discover it.

**Rule:** when you hit ambiguity, the right move isn't always "halt and ask."
Sometimes it's "build the cheapest version that makes the question concrete, then
ask." A running stub the user can react to beats a question they can't yet answer.

### 6. Compression has a cost the next reader pays

Terse handoffs are efficient for the writer and lossy for the inheritor. When
writing for a future session, the thing that feels like over-explaining to you is
often exactly enough for them.

**Rule:** when leaving notes for the next session, double the length of your first
draft. What feels verbose to you will feel thin to the person picking up cold.

---

> **Keep this file short.** Every new entry makes it less likely someone reads it
> cold before starting. A 15-item WISDOM.md is a document; a 3-item one is a reflex.
> Prune before adding. If an entry repeats something already on the list, replace
> the weaker version — don't append.
