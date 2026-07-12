# frozen_string_literal: true

# The Mirror Plan: every task ships its own inverse, so every plan
# has a REFLECTION - same graph with the arrows flipped, undo agents
# in place of do agents - and running plan-then-mirror returns the
# world to its exact initial state, byte for byte. Which sounds like
# a party trick until a plan fails halfway with real side effects
# already committed: then the mirror of the completed prefix is the
# compensation saga you'd otherwise write by hand at 3am, and the
# strangest thing about it is that it was sitting in the graph all
# along, wearing the plan's clothes backwards.
#
#   bundle exec ruby examples/mirror_plan.rb
#
# Runs offline; exits 1 unless both mirrors restore the world.

require "bundler/setup"
require "agentic"

Agentic.logger.level = :fatal

# Each step declares its action AND its inverse, over a shared world
STEPS = [
  {name: "reserve stock",
   do: ->(w) { w[:inventory]["lamp"] -= 1 },
   undo: ->(w) { w[:inventory]["lamp"] += 1 }},
  {name: "charge card",
   do: ->(w) { w[:ledger] << {charge: 4900} },
   undo: ->(w) { w[:ledger].pop }},
  {name: "publish listing",
   do: ->(w) { w[:published] << "lamp" },
   undo: ->(w) { w[:published].delete("lamp") }},
  {name: "notify warehouse",
   do: ->(w) { w[:outbox] << "pick lamp" },
   undo: ->(w) { w[:outbox].pop }}
].freeze

def run(steps, world, direction:, fail_at: nil)
  orchestrator = Agentic::PlanOrchestrator.new(concurrency_limit: 1, retry_policy: {max_retries: 0, retryable_errors: []})
  ordered = (direction == :mirror) ? steps.reverse : steps
  completed = []
  previous = nil
  ordered.each do |step|
    action = (direction == :mirror) ? step[:undo] : step[:do]
    task = Agentic::Task.new(description: "#{direction}: #{step[:name]}", agent_spec: {"name" => step[:name], "instructions" => "w"})
    orchestrator.add_task(task, previous ? [previous] : [], agent: ->(_t) {
      raise Agentic::Errors::LlmAuthenticationError, "payment provider said no" if step[:name] == fail_at
      action.call(world)
      completed << step
      :done
    })
    previous = task
  end
  orchestrator.execute_plan
  completed
end

def snapshot(world) = Marshal.dump(world)

fresh_world = -> { {inventory: {"lamp" => 3}, ledger: [], published: [], outbox: []} }

puts "THE MIRROR PLAN (every plan carries its own reflection)"
puts

# --- act 1: forward, then the full mirror - the world round-trips -------------------
world = fresh_world.call
genesis = snapshot(world)
run(STEPS, world, direction: :forward)
changed = snapshot(world) != genesis
puts "  act 1 - the plan runs forward: lamp reserved, card charged, listing live"
puts "    world changed: #{changed} (inventory #{world[:inventory]["lamp"]}, ledger #{world[:ledger].size} entries)"
run(STEPS, world, direction: :mirror)
restored_full = snapshot(world) == genesis
puts "    ...then its mirror runs (same steps, arrows flipped, undo for do):"
puts "    world restored byte-for-byte: #{restored_full}"
puts

# --- act 2: the plan fails halfway - mirror only what completed ---------------------
world = fresh_world.call
genesis = snapshot(world)
completed = run(STEPS, world, direction: :forward, fail_at: "publish listing")
puts "  act 2 - the same plan dies at step 3 (payment provider said no... late):"
puts "    completed before the crash: #{completed.map { |s| s[:name] }.join(", ")}"
puts "    stock is reserved and money is TAKEN - the classic 3am state."
run(completed, world, direction: :mirror)
restored_partial = snapshot(world) == genesis
puts "    the mirror of the COMPLETED PREFIX runs (a saga, auto-derived):"
puts "    world restored byte-for-byte: #{restored_partial}"
puts

# --- act 3: the mirror of the mirror is the plan ------------------------------------
involution = STEPS.reverse.reverse == STEPS
puts "  act 3 - mirror(mirror(plan)) == plan: #{involution} (reflection is an involution;"
puts "    the mandala next door would like a word)"
puts

failures = []
failures << "forward plan changed nothing" unless changed
failures << "full mirror failed to restore" unless restored_full
failures << "compensation failed to restore" unless restored_partial
failures << "reflection is not an involution" unless involution

puts "  the honest fine print: this works because every step declared an"
puts "  inverse that TRULY inverts - pop for push, += for -=. some real"
puts "  actions have no inverse (you cannot unsend an email; you can only"
puts "  send an apology), and the discipline the mirror imposes is exactly"
puts "  that: it forces you to ANSWER, per step, 'what is the undo?' -"
puts "  and steps with no answer get quarantined behind the ones that"
puts "  have one. compensation isn't a framework feature you buy; it's a"
puts "  question you agree to keep answering. the mirror just makes the"
puts "  question mandatory, which is the most architecture anything in"
puts "  this file does."
exit(failures.empty? ? 0 : 1)
