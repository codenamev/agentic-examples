# Round 20 field notes — Jean Boussier imports five thousand rows

*Built: `examples/bulk_import.rb` — the job every team writes badly
once: a chunked, idempotent, journal-resumable bulk import that
survives its own included crash with zero duplicates and zero lost
rows. Batch for the database, journal for the crash, upsert for the
truth.*

## What I built and why

The brief said common problems, and there is none more common than
this: marketing sends a CSV at 5pm, someone writes a loop with a
`create!` in it, and three weeks later that loop is why the
database fell over during the Tuesday deploy. At scale we've
rewritten this job more times than I can count, and the correct
version is always the same three boring disciplines:

```
monday 17:04 - power cut at batch 6 of 10
  rows landed: 3000 (batches 0-5, durably journaled)
monday 17:11 - same command, re-run. no flags, no surgery:
  6 batches skipped; resumed at batch 6
  rows in db: 5000; total batch calls: 10
at-least-once drill: batch 0 re-delivered -> 5000 -> 5000 rows
```

**Batch**, because the database bills per round-trip, not per row —
5,000 rows in 10 calls, not 5,000. **Idempotent upsert**, because
at-least-once is the only delivery guarantee production has ever
offered anyone; a keyed write makes re-delivery a shrug instead of
a dedup incident. **Journaled cursor**, because the crash is not an
edge case, it's a scheduled guest — the resume reads which batches
*finished* from a durable journal and skips exactly those, so the
17:11 re-run is the same command with no flags and no surgery.
Recovery that requires remembering the right incantation is not
recovery; it's a second incident.

## The bug I wrote on the way is the lesson in miniature

My first row-reader used `filter_map` with `next header = values`
to skip the header line — and `filter_map` cheerfully *included*
the header row, because the assignment is truthy and `next value`
yields it. One phantom row meant eleven batches, an array where a
hash should be, and an import that landed zero rows. Exactly the
class of off-by-one-row bug that real CSV imports produce in the
wild — and the referee caught it instantly because the final
assertion is absolute: `DB.size == ROWS`, not "roughly the right
amount." Import counts are the one place where approximately
correct means wrong.

## Notes

- The journal cursor records *batch indexes*, not row offsets —
  coarse on purpose. Resume granularity should match write
  granularity; a finer cursor than your transaction boundary is a
  lie about what's actually durable.
- The hand-rolled row parser exists because `csv` leaves the
  default gems in Ruby 3.4 — this catalog's own stdlib census made
  that exact point two casts ago. Dependencies you don't add can't
  bill you later.
- Production additions, same skeleton: a staging table swap for
  atomicity, `ON CONFLICT` as the real upsert, and the batch size
  tuned by measuring round-trip amortization — not by folklore.

## Verdict

One included crash, one flag-free resume, ten round-trips, five
thousand rows exactly. Bulk import is a solved problem that teams
keep unsolving by skipping one of the three disciplines — this
example is the checklist, executable, with the crash built in
because the crash is always built in.
