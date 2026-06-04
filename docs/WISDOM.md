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
