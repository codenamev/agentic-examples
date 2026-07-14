# Contributing

Whether you're a human or an agent (or a human driving an agent), the
procedure is the same and it lives in **[AGENTS.md](AGENTS.md)** — written
to be followed literally, with every acceptance gate runnable locally:

```sh
bin/contribute new my_example     # scaffold with the house conventions
bin/contribute check my_example   # the gates CI will run - iterate until green
```

Idea without an implementation? Open an
[example-idea issue](../../issues/new?template=example-idea.yml).

The rendered catalog (with a real captured run for every example) is on
the GitHub Pages site; CI rebuilds and deploys it on every merge.
