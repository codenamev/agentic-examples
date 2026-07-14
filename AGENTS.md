# Agent protocol: contributing an example to this catalog

This file is written for AI agents (humans welcome). It is the complete,
self-contained procedure for adding an example. Follow it literally; every
gate you must pass is runnable locally, and CI runs the same command you do.

## What this repository is

A library of small, self-verifying Ruby programs built on the
[agentic](https://github.com/codenamev/agentic) gem — a plan-and-execute
framework. Each example applies the framework to a problem **outside the
framework itself**: bulk imports, retry policies, config reloads, drip
campaigns, PII scrubbing — plus a few Why-Day-spirited ones. Browse the
rendered catalog at the GitHub Pages site or in `examples/README.md`.

## The quality bar (what your example must be)

1. **Offline.** No network, no API keys, no external services. Simulate
   the world with lambdas, fixtures, and tmpdirs. The static scan rejects
   `Net::HTTP`, `open-uri`, `URI.open`, `TCPSocket`, `Faraday`, `HTTParty`.
2. **Self-verifying.** The script computes falsifiable claims about what
   it just demonstrated ("the resume skipped exactly 6 batches") and exits
   `0` when they hold, `1` when they don't. The referee is the product.
3. **One idea.** ~120 lines. A problem, the discipline that solves it,
   printed evidence, closing prose that interprets the numbers.
4. **A front-door header.** The top comment explains the problem and the
   idea to a stranger, then states the exact run line and the exit
   contract. The showcase site renders this header — write it well.
5. **Deterministic exit.** Two runs, same exit code. Timing prints may
   vary; verdicts may not.
6. **Uses the framework.** `require "bundler/setup"` + `require "agentic"`;
   a plan, a journal, a limiter, capabilities — the example should
   demonstrate agentic doing real coordination, not decorate a script.

## The procedure

```sh
git clone https://github.com/codenamev/agentic-examples && cd agentic-examples
bundle install                    # agentic resolves from git; AGENTIC_PATH=/path/to/checkout overrides

bin/contribute new my_example     # scaffolds examples/my_example.rb with the house conventions
                                  # plus perspectives/community/my_example.md (field notes, optional but loved)

# ... build the idea in examples/my_example.rb ...

bin/contribute check my_example   # the acceptance gates; iterate until all PASS:
                                  #   header contract / offline static scan / standardrb /
                                  #   the run (60s budget, exit 0) / determinism / size

bundle exec ruby examples/examples_index.rb   # regenerate examples/README.md
```

Then open a pull request:

- Title: `example: my_example`
- One example per PR (plus its field notes and the regenerated index).
- Do **not** commit `docs/` — it is gitignored; CI rebuilds and deploys
  the site on every merge to main.
- Do not modify other examples, `bin/`, or workflow files in the same PR.
- In the PR body: the problem it solves, what the referee asserts, and the
  output of `bin/contribute check`.

CI runs `bin/contribute check` on every example your PR adds or changes.
Green locally means green in CI; there is no hidden gate.

## Only have an idea?

Open an issue with the **example idea** template: the problem, why a
plan-and-execute shape fits it, and what the referee would assert. Ideas
seed future rounds; someone else's agent may build yours.

## House style, absorbed fastest by imitation

Read three before writing one: `examples/bulk_import.rb` (a production
staple), `examples/etude_machine.rb` (self-verifying exercises — the
quality bar for exercises is this repo's whole personality), and
`examples/fireworks_show.rb` (a fun one that still proves its claim).
