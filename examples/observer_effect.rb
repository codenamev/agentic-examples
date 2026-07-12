# frozen_string_literal: true

# The Observer Effect: profilers are not free, and the strangest
# number in performance work is the one almost nobody measures -
# the cost of measuring. This example instruments a workload with
# 0, 1, 2, and 3 layers of probes (each probe is what real
# profilers do: read the clock, append an event), times each
# configuration, and derives the PER-GLANCE cost of observation.
# Then it says the quiet part with an exit code: the act of watching
# has a price, the price is linear in the watching, and you can -
# and therefore must - know the number before you turn on the
# always-on profiler in production.
#
#   bundle exec ruby examples/observer_effect.rb
#
# Runs offline; exits 1 unless the observer tax is real, positive,
# and roughly linear in the number of observers.

require "bundler/setup"
require "agentic"

Agentic.logger.level = :fatal

def mono = Process.clock_gettime(Process::CLOCK_MONOTONIC)

ITERATIONS = 20_000
DEPTHS = [0, 1, 2, 3].freeze
TRIALS = 5

# The workload: honest arithmetic. The probes: what every profiler
# actually does per sample - read the clock, record an event.
def run_workload(probe_layers, events)
  total = 0
  ITERATIONS.times do |i|
    probe_layers.times { events << Process.clock_gettime(Process::CLOCK_MONOTONIC, :nanosecond) }
    total += (i * 31) % 97
  end
  total
end

# Each depth measured as a task; one lane, because timing tasks in
# parallel is how you measure your scheduler instead of your code
orchestrator = Agentic::PlanOrchestrator.new(concurrency_limit: 1)
timings = {}
answers = {}
DEPTHS.each do |depth|
  task = Agentic::Task.new(description: "depth #{depth}", agent_spec: {"name" => "d#{depth}", "instructions" => "w"})
  orchestrator.add_task(task, agent: ->(_t) {
    samples = TRIALS.times.map {
      events = []
      started = mono
      answers[depth] = run_workload(depth, events)
      mono - started
    }
    timings[depth] = samples.min # min-of-N: the least-disturbed run is the truest
    :measured
  })
end
orchestrator.execute_plan

puts "THE OBSERVER EFFECT (the most unmeasured number in profiling is the profiler)"
puts
puts format("  %-10s %-12s %-14s %s", "observers", "wall (min)", "overhead", "events recorded per run")
DEPTHS.each do |depth|
  overhead = timings[depth] - timings[0]
  puts format("  %-10d %-12s %-14s %s", depth, "#{(timings[depth] * 1000).round(2)}ms",
    depth.zero? ? "-" : "+#{(overhead * 1000).round(2)}ms", depth * ITERATIONS)
end
puts

# The derived number: nanoseconds per glance
per_glance_ns = ((timings[3] - timings[0]) / (3 * ITERATIONS) * 1_000_000_000).round
step1 = timings[1] - timings[0]
step3 = (timings[3] - timings[0]) / 3.0
puts "  the observer tax, derived: ~#{per_glance_ns}ns per glance (clock read + event append)"
puts "  linearity check: 1 layer costs #{(step1 * 1000).round(2)}ms; a third of 3 layers costs #{(step3 * 1000).round(2)}ms"
puts

failures = []
failures << "the workload changed under observation (impossible - it's arithmetic)" unless answers.values.uniq.size == 1
failures << "observation was free (suspicious beyond words)" unless timings[3] > timings[0]
failures << "per-glance cost implausible (#{per_glance_ns}ns)" unless per_glance_ns.between?(5, 100_000)
failures << "observer tax wildly non-linear" unless step3.between?(step1 * 0.2, step1 * 5)

puts "  what to do with the number: an always-on profiler at one glance"
puts "  per unit of work costs you ~#{per_glance_ns}ns each - multiply by your"
puts "  requests-per-second and you have the REAL price of the pretty"
puts "  flamegraph, in CPU you could have spent serving users. usually"
puts "  it's worth it! visibility pays rent. but 'usually' is a"
puts "  measurement, not a vibe: min-of-five to shed scheduler noise,"
puts "  the workload's ANSWER asserted unchanged under observation (the"
puts "  probe must never touch the physics), and the tax checked for"
puts "  linearity, because a profiler whose cost curves is a profiler"
puts "  with a bug. watch everything - but first, watch the watcher."
exit(failures.empty? ? 0 : 1)
