# frozen_string_literal: true

# The Executable Runbook: every ops wiki has a page titled "If the
# queue gets stuck" with eleven steps, three of which are stale,
# one of which is dangerous, and none of which have been run since
# the person who wrote them left. The fix is to make the runbook a
# PROGRAM: each step declares a check (read-only: is this step even
# needed?), an action (the mutation), and a verify (did it work?).
# Dry-run mode executes only the checks and provably touches
# nothing. Live mode skips steps whose checks say "already fine" -
# so the book is safe to re-run at 3am, twice, by someone whose
# hands are shaking. Documentation that executes cannot rot
# silently; it fails in CI like everything else you trust.
#
#   bundle exec ruby examples/executable_runbook.rb
#
# Runs offline; exits 1 unless dry-run is provably read-only and
# the live book is provably idempotent.

require "bundler/setup"
require "agentic"

Agentic.logger.level = :fatal

# The world: a job system having a bad morning
def sick_world
  {intake: :open, workers: :wedged, queue: [:job, :job, :stuck_job, :job, :stuck_job], processed: 0}
end

RUNBOOK = [
  # The check tests for the PROBLEM, not for the action's applicability -
  # "intake is open" is true on a healthy system too, and a guard that
  # merely asks "could I?" will happily re-break what a re-run should skip
  {step: "pause intake",
   check: ->(w) { w[:workers] == :wedged || w[:queue].include?(:stuck_job) },
   action: ->(w) { w[:intake] = :paused },
   verify: ->(w) { w[:intake] == :paused }},
  {step: "clear stuck jobs",
   check: ->(w) { w[:queue].include?(:stuck_job) },
   action: ->(w) { w[:queue].reject! { |j| j == :stuck_job } },
   verify: ->(w) { !w[:queue].include?(:stuck_job) }},
  {step: "restart workers",
   check: ->(w) { w[:workers] != :running },
   action: ->(w) { w[:workers] = :running },
   verify: ->(w) { w[:workers] == :running }},
  {step: "resume intake",
   check: ->(w) { w[:intake] == :paused },
   action: ->(w) { w[:intake] = :open },
   verify: ->(w) { w[:intake] == :open }},
  {step: "confirm queue draining",
   check: ->(w) { true }, # always assess
   action: ->(w) { w[:processed] += w[:queue].size },
   verify: ->(w) { w[:processed].positive? }}
].freeze

def run_book(world, mode:)
  orchestrator = Agentic::PlanOrchestrator.new(concurrency_limit: 1) # runbooks are read aloud, in order
  log = []
  actions_executed = 0
  previous = nil
  RUNBOOK.each do |entry|
    task = Agentic::Task.new(description: entry[:step], agent_spec: {"name" => entry[:step], "instructions" => "op"})
    orchestrator.add_task(task, previous ? [previous] : [], agent: ->(_t) {
      needed = entry[:check].call(world)
      if mode == :dry_run
        log << "  [dry] #{entry[:step].ljust(24)} #{needed ? "WOULD run" : "would skip (already satisfied)"}"
        next :assessed
      end
      if needed
        entry[:action].call(world)
        actions_executed += 1
        raise "VERIFY FAILED after #{entry[:step]}" unless entry[:verify].call(world)
        log << "  [live] #{entry[:step].ljust(24)} ran; verified"
      else
        log << "  [live] #{entry[:step].ljust(24)} skipped (check says already fine)"
      end
      :done
    })
    previous = task
  end
  status = orchestrator.execute_plan.status
  [log, actions_executed, status]
end

puts "THE EXECUTABLE RUNBOOK (documentation that cannot rot silently)"
puts

world = sick_world
before = Marshal.dump(world)
dry_log, dry_actions, = run_book(world, mode: :dry_run)
puts "  1. dry run against the sick system (the 3am confidence pass):"
dry_log.each { |l| puts "  #{l}" }
untouched = Marshal.dump(world) == before
puts "     world untouched: #{untouched} (byte-compared; a dry run that writes is a lie)"
puts

live_log, live_actions, live_status = run_book(world, mode: :live)
puts "  2. live run:"
live_log.each { |l| puts "  #{l}" }
healthy = world[:workers] == :running && world[:intake] == :open && !world[:queue].include?(:stuck_job)
puts "     system healthy: #{healthy}"
puts

rerun_log, rerun_actions, = run_book(world, mode: :live)
puts "  3. the shaky-hands re-run (someone ran it twice; someone always does):"
rerun_log.each { |l| puts "  #{l}" }
puts

failures = []
failures << "dry run mutated the world" unless untouched && dry_actions.zero?
failures << "live run failed (#{live_status})" unless live_status == :completed && healthy && live_actions == 5
failures << "re-run was not idempotent (#{rerun_actions} actions)" unless rerun_actions == 1 # only the always-assess step
puts "  the three properties, proven in order: DRY-RUN IS READ-ONLY"
puts "  (world byte-compared before and after - a dry run you can't"
puts "  trust is worse than none); EVERY STEP IS GUARDED (check before"
puts "  action, verify after - the book skips what's already fine, so"
puts "  a half-recovered system doesn't get un-recovered); and the"
puts "  RE-RUN IS SAFE (second pass executed #{rerun_actions} action - the"
puts "  always-assess step - because idempotency is what makes a"
puts "  runbook usable by someone at 3am whose hands are shaking)."
puts "  wikis rot because nothing fails when they do. this book runs"
puts "  in CI against a simulated sick system; the day a step goes"
puts "  stale, a build goes red, and the on-call finds out at 3PM"
puts "  instead of 3AM."
exit(failures.empty? ? 0 : 1)
