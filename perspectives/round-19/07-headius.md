# Round 19 field notes — Charles Nutter builds a VM out of the framework

*Built: `examples/stack_vm_plan.rb` — arithmetic compiles to stack
bytecode, and each instruction becomes a task: the chain is the
program counter, `previous_output` is the operand stack, and a
peephole optimizer folds every constant program to a single push.
Cross-checked against Ruby herself.*

## What I built and why

I've spent twenty years compiling Ruby onto other people's virtual
machines. For the strange round I inverted the stack (pun budgeted
and spent): a virtual machine made *out of* the workflow framework.
A pocket recursive-descent compiler turns `(2 + 3) * (10 - 4)` into
push/add/sub/mul bytecode — a YARV you could lose in a coat pocket
— and then the deranged part, which is also the illuminating part:
**each instruction is a task.**

```
push 2    -> [2]
push 3    -> [2, 3]
add       -> [5]
push 10   -> [5, 10]
push 4    -> [5, 10, 4]
sub       -> [5, 6]
mul       -> [30]
peephole: 7 instructions -> 1 (push 30), same answer: true
```

The dependency chain is the program counter (`concurrency_limit: 1`
— this machine fetches one instruction at a time, as machines do).
The operand stack threads through `previous_output`, frozen at
every step — a machine with no mutable registers, so no
instruction can corrupt state it doesn't own. And the referee is
the only reference implementation that matters: `eval`. Three
programs, plan-VM versus MRI, unanimous.

## The peephole is the sermon

No instruction stream of mine ships unoptimized, even a joke one.
The peephole pass does constant folding to fixpoint — `push a, push
b, add` becomes `push a+b` — and every test program collapses to a
*single push*, because arithmetic on constants is the compiler's
job, not the runtime's. That's the JRuby lesson compressed to one
line: **the fastest instruction is the one you delete before the
executor sees it.** It applies verbatim to plans that aren't jokes:
a "plan optimizer" that pre-folds pure tasks whose inputs are known
at assembly (config lookups, static transforms) before the
scheduler ever spawns a fiber is this same peephole, wearing
production clothes. Somebody should build it. Somebody may have
just been tricked into designing it.

## Notes

- The optimizer is verified the only way optimizers deserve: same
  answer, fewer instructions, on every program. An optimization
  without an equivalence check is a bug with a press release.
- Task-per-instruction overhead is comically wrong for arithmetic
  (that's the bit) and exactly right one level up — when each
  "instruction" costs an LLM call or an API round-trip, folding the
  constant ones matters at real money scale.
- The trace (stack state after each instruction, straight from task
  outputs) is a free single-stepper. Twenty years in VMs and I've
  never gotten a debugger this cheaply.

## Verdict

Three programs, two implementations, zero disagreements, and every
bytecode stream folded to one push. "The plan is the program" was
always the framework's implicit metaphor — this example just runs
the metaphor at machine granularity until it confesses. The moral
survived the joke: delete instructions before the executor sees
them, and check your optimizer against the truth.
