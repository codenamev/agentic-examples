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
7. **Says where the mind would sit.** Most examples stub the LLM with a
   lambda at the exact seam a real agent occupies
   (`orchestrator.add_task(task, agent: ->(t) { ... })`). Name the
   stand-in honestly in `agent_spec` and, when it clarifies, say in the
   header what an LLM would do at that seam. Examples that keep a real
   LLM in the loop are the live tier below.

## Artifacts: output is not always text

If your example's deliverable is a file (SVG chart, CSV, JSON report,
HTML page…), write it to `ENV["AGENTIC_ARTIFACTS_DIR"] || Dir.mktmpdir`.
The showcase sets that variable when it captures your run, collects
whatever appears there, and renders it on your example's page — images
inline, everything else as downloads. The referee should reopen the
files and verify them (row counts, re-summed totals, well-formedness);
`examples/status_board.rb` is the house pattern.

## The live tier: real LLM calls, recorded once, replayed forever

Examples named `live_*.rb` keep a real LLM in the loop instead of a
lambda. They use VCR: the first run records the actual HTTP interaction
into `examples/cassettes/<name>.yml`; every run after that — CI, the
showcase, contributors without keys — replays it deterministically.

```sh
bin/contribute new live_my_example   # then follow live_import_mapper.rb's shape
OPENAI_ACCESS_TOKEN=... bin/record live_my_example   # the one keyed step
bin/contribute check live_my_example                 # gates run against the replay
```

Live-tier rules, in addition to the quality bar above:

- Before its first recording the example must explain itself and exit 0;
  the showcase marks the page "awaiting its first recording".
- Only commit cassettes recorded by `bin/record` against a real model —
  a hand-written cassette turns "a real captured run" into fiction.
  Tokens are scrubbed automatically; eyeball new cassettes anyway.
- Keep one recording's worth of calls small and sequential
  (`concurrency_limit: 1`) so replay order is deterministic.
- The referee still rules: hold the model's output to falsifiable
  claims, exactly as if it were code.

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
For the live tier read `examples/live_import_mapper.rb` (an LLM at the
semantic step, lambdas everywhere else); for artifacts read
`examples/status_board.rb` (the deliverable is files the referee reopens).
