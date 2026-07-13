# frozen_string_literal: true

# Hot Config Reload: change the server's configuration without
# dropping a request - a problem every long-running process has,
# and one with two classic wounds. Wound one: TORN READS. Update
# the live config hash field by field and a request that starts
# mid-update sees half old, half new (rate limit from v2, burst
# from v1 - now your limiter math is nonsense). Wound two: the BAD
# CONFIG. A reload that applies first and validates never is how a
# typo'd YAML takes down what the deploy didn't. The cure for both
# is the same discipline: build the ENTIRE new config off to the
# side, validate it there, freeze it, and swap ONE reference. In-
# flight requests keep the object they started with; the swap is
# atomic; invalid proposals never touch the living.
#
#   bundle exec ruby examples/hot_config_reload.rb
#
# Runs offline; exits 1 unless tearing is demonstrated, then cured,
# and the bad config is refused with the old one still serving.

require "bundler/setup"
require "agentic"

Agentic.logger.level = :fatal

# Config invariant: limit and burst always ship as a matched pair
V1 = {version: 1, rate_limit: 100, burst: 100, motd: "steady"}.freeze
V2 = {version: 2, rate_limit: 200, burst: 200, motd: "spicy"}.freeze

# Serve requests concurrently while an updater changes config midway.
# Each request reads the config ONCE and checks the pair invariant.
def serve_through_update(holder, updater)
  orchestrator = Agentic::PlanOrchestrator.new(concurrency_limit: 8)
  torn = 0
  served = 0
  add_request = ->(i) {
    task = Agentic::Task.new(description: "req #{i}", agent_spec: {"name" => "req", "instructions" => "serve"})
    orchestrator.add_task(task, agent: ->(_t) {
      cfg = holder[:current] # one read; whatever object this is, we keep it
      sleep(0.004)           # the request does some work mid-flight
      torn += 1 if cfg[:rate_limit] != cfg[:burst] # the invariant a torn read breaks
      served += 1
      :ok
    })
  }
  16.times { |i| add_request.call(i) }
  # the reload arrives while traffic is flowing, as reloads do
  swap = Agentic::Task.new(description: "config update", agent_spec: {"name" => "cfg", "instructions" => "swap"})
  orchestrator.add_task(swap, agent: ->(_t) {
    updater.call(holder)
    :updated
  })
  (16...120).each { |i| add_request.call(i) }
  orchestrator.execute_plan
  [torn, served]
end

VALIDATE = ->(candidate) {
  problems = []
  problems << "rate_limit/burst must match (got #{candidate[:rate_limit]}/#{candidate[:burst]})" if candidate[:rate_limit] != candidate[:burst]
  problems << "rate_limit must be positive" unless candidate[:rate_limit].to_i.positive?
  problems
}

puts "HOT CONFIG RELOAD (in-flight requests keep their world; proposals prove themselves)"
puts

# --- wound one: field-by-field mutation tears requests -------------------------------
holder = {current: V1.dup}
torn, served = serve_through_update(holder, ->(h) {
  h[:current][:rate_limit] = 200 # the tempting in-place edit
  sleep(0.02)                    # ...and the gap where requests see half a config
  h[:current][:burst] = 200
  h[:current][:version] = 2
})
puts "  the in-place update (mutate the live hash, field by field):"
puts "    #{served} requests served, #{torn} saw a TORN config (limit != burst mid-swap)"
puts

# --- the cure: build aside, validate, freeze, swap one reference ---------------------
holder = {current: V1}
torn2, served2 = serve_through_update(holder, ->(h) {
  candidate = V2 # built entirely off to the side
  raise "invalid" unless VALIDATE.call(candidate).empty?
  h[:current] = candidate.freeze # ONE reference assignment; old requests finish on V1
})
puts "  the atomic swap (build aside, validate, freeze, assign once):"
puts "    #{served2} requests served, #{torn2} torn; config now v#{holder[:current][:version]}"
puts

# --- wound two: the bad proposal never touches the living -----------------------------
bad = {version: 3, rate_limit: 500, burst: 100, motd: "oops"}
problems = VALIDATE.call(bad)
applied = problems.empty?
puts "  the bad proposal (rate_limit 500, burst 100 - a typo'd deploy):"
puts "    validation refused it: #{problems.first}"
puts "    live config still v#{holder[:current][:version]}, still serving - the reload failed, the SERVER didn't"
puts

failures = []
failures << "in-place mutation didn't tear (weird scheduling?)" unless torn.positive?
failures << "atomic swap tore (#{torn2})" unless torn2.zero? && served2 == 120
failures << "swap didn't take effect" unless holder[:current][:version] == 2
failures << "bad config was applied" if applied

puts "  the whole pattern in four verbs: BUILD the new config as a"
puts "  separate object (never edit the one requests are holding);"
puts "  VALIDATE the proposal while it's still a proposal - invariants,"
puts "  not just parse success, because 'valid YAML' and 'valid config'"
puts "  are different claims; FREEZE it so nothing can tear it later;"
puts "  SWAP one reference, which Ruby makes atomic for free. requests"
puts "  in flight finish in the world they started in - a request is a"
puts "  promise, a config file is a proposal, and the server's job is"
puts "  to never confuse the two. #{torn} torn reads say the in-place"
puts "  shortcut isn't hypothetical; zero say the cure is complete."
exit(failures.empty? ? 0 : 1)
