# Round 20 field notes — Sarah Mei scrubs the survey

*Built: `examples/survey_scrubber.rb` — ten free-text survey
responses full of names, emails, a phone number, and a handle,
scrubbed before anything else happens, categorized, aggregated —
and a referee that greps every downstream surface for every seeded
identifier. Zero leaks, ten responses accounted for.*

## What I built and why

The brief asked for a common problem, and here is the one hiding
inside every retro survey, NPS form, and "quick feedback" doc:
**humans answer questions with other humans' names in them.** Ask
what's blocking the team and you'll get "ask Maria Santos" and
"email varun.k@" — organic, well-meant, and now sitting in your
data warehouse, your category model's logs, and the exec summary
that gets forwarded outside the org. Data about people *is* people.

```
TEAM BLOCKERS, Q3 (10 responses)
  tooling  #### 4    infra ### 3    process ## 2    people # 1
  sample voices: CI is flaky, ask [NAME] she has the details | ...
privacy referee: 6 seeded identifiers grepped against the report,
the warehouse file, and every categorized record: ZERO leaks
```

The architecture is one decision made loudly: **the scrubber runs
first.** Before categorization, before the warehouse write, before
anything that owns a disk or a memory. Every stage that sees raw
text is a stage that can leak it — through logs, through error
messages, through a cached intermediate someone finds in March —
and the way you win that game is to shrink the set of raw-seeing
stages to exactly one. (This is flavorjones' decode-first lesson
from round 17 wearing its most important outfit: pipeline order is
not a style choice; it's the security model, and here, the ethics.)

## Recall beats precision, and grep beats policy

Two positions worth defending explicitly. The name-scrubbing rule
is blunt — `[A-Z]\w+ [A-Z]\w+` will occasionally redact "Le Sigh" —
and blunt is *correct*, because the costs are asymmetric: a false
positive costs a chuckle; a miss costs a person. Tune PII detection
for recall and let precision complain to HR. And the verification
is a grep, not a paragraph: every seeded identifier hunted through
every downstream surface — the report, the warehouse file, each
categorized record. "We scrub the data" is a claim. Grep is a fact.

## Notes

- The report kept everything the survey was *for* — counts, ranked
  themes, even sample voices (scrubbed). Anonymized is not the same
  as useless; it's useful without a body count. Teams over-rotate
  to "we can't keep anything" and lose the signal that justified
  asking.
- Real pipelines add: a PII rule for street addresses and employee
  IDs, review of `[NAME]`-dense responses (a response that's mostly
  names is probably an interpersonal issue that deserves a human,
  not a category), and scrub-rule versioning in the warehouse
  records so you know which rules cleaned what.
- The parallel fan-out means response 7 never waits on response 2's
  regex, and the fan-in report reads its inputs by task — the
  catalog's plainest shape, carrying its heaviest responsibility.

## Verdict

Six identifiers seeded, zero found downstream, ten responses in
the tally, themes intact. The pipeline's order did the ethics, the
blunt rule did the recall, and the grep did the auditing. Ask your
survey pipeline the question this example answers with an exit
code: if I plant a name in the input, can you prove it never
reaches the report?
