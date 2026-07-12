# Round 19 field notes — Konstantin Haase curates the Wat Museum

*Built: `examples/wat_museum.rb` — seven exhibits of genuine Ruby
strangeness, each proven by a task before it may be displayed.
Strict acquisitions policy: a placard that can't demonstrate itself
is deaccessioned on the spot. 7/7 verified; nothing retracted.*

## What I built and why

I spent years giving the talk where I show Ruby doing something
apparently impossible and then remove the magician's cloth: *there
is no magic, only semantics you haven't met yet.* The Strange Ruby
brief is that talk's natural habitat, so I built its museum — with
the one policy every wat collection on the internet lacks:
**exhibits must execute.** Programming folklore runs on screenshots
of someone else's REPL, semantics misremembered from a conference
five years ago, behaviors that changed three minor versions back.
This museum's acquisitions committee is a plan: seven prover tasks
in parallel, one verdict each, and the tour only prints what ran.

```
Exhibit 1: The Flip-Flop            demonstrated: [3, 4, 5]
Exhibit 2: Some Integers Are More
           Equal                    demonstrated: small: true, big: false
Exhibit 5: defined? Leaves
           Footprints               demonstrated: ["assignment", "nil"]
acquisitions report: 7/7 verified, 0 deaccessioned
```

My favorites, as curator: the **flip-flop** (a range across *time*,
inherited from sed and awk, deprecated in 2.6 and un-deprecated by
popular demand — the only feature I know that was rescued by
nostalgia), and **`defined?` leaving footprints** — asking the
parser *whether* `zz = 1` would be an assignment causes `zz` to
exist, as nil, because local declaration is the parser's job and
the parser has already been by. A question that changes the answer
to later questions. Heisenberg would file a bug; the parser team
would close it as intended.

## Wat is the sound of a model updating

The curatorial position, printed in the exhibit hall: none of these
are bugs, and "wat" is not an accusation. Integer identity is the
immediate-value optimization wearing a mask; the float sum is base
2 being honest about a number it cannot say; `Array#*` joining on a
String is operator polymorphism doing exactly what it's told. The
gasp is the moment your mental model updates, and a museum that
*executes its placards* can afford to provoke that gasp — because
it never has to issue a retraction. The exit code is the museum's
accreditation.

## The linter tried to deaccession an exhibit

True story from the museum's opening night: the style linter's
autofix rewrote Exhibit 4's proof — `[1, 2, 3] * "-"` became
`[1, 2, 3].join("-")` — which "fixed" the code by removing the
entire wat while **keeping the assertion green** (join produces the
same string, so the exit code saw nothing). The placard claimed `*`
joins; the demonstration no longer used `*`; the museum briefly
contained exactly the kind of lie it was built to prevent, and no
referee could see it, because the falsehood lived in the *relation
between placard and proof*, not in either one. The restored exhibit
now carries a curator's note telling the linter to stand down. Add
it to the permanent collection: **style tools enforce idiom, and
wat is definitionally un-idiomatic — a museum of strangeness must
exempt its own artifacts from normalization.**

## Notes

- The demonstrations run as parallel tasks because exhibits are
  independent — the museum is, quietly, the catalog's standard
  fan-out-and-fan-in shape wearing a gift-shop lanyard.
- Ruby version drift is the real curatorial threat: exhibits ARE
  version-sensitive (the flip-flop's deprecation saga proves it).
  Running in CI per Ruby version turns the museum into a semantics
  regression suite, which may be the only genuinely useful thing
  I've built while wearing the joke this hard.
- Declined acquisitions: anything requiring `$;` or `$,` (global
  punctuation variables are strange but scheduled for removal — a
  museum shouldn't exhibit what the city plans to demolish).

## Verdict

Seven placards, seven demonstrations, zero retractions. The
strangeness was real, the proofs were cheap, and the lesson is the
same one from the talk: Ruby is not magic, but it *is* generous
with surprises — and the correct response to a surprise is an
executable placard, not a screenshot.
