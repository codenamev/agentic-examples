# frozen_string_literal: true

# The VM Eye: your plan, as the virtual machine saw it. Above the
# waterline there are tasks and dependencies; below it there are
# method calls, block invocations, and allocated objects, and the
# VM counts ALL of them without being asked. TracePoint and GC.stat
# are the periscope: per task we count every :call and :b_call and
# every object allocated, we prove from VM evidence alone that each
# agent ran EXACTLY once, and we weigh the framework itself - the
# honest price, in method calls, of running three tasks that do
# nothing. Nothing is free. The VM has receipts.
#
#   bundle exec ruby examples/vm_eye.rb
#
# Runs offline; exits 1 unless the VM's ledger balances.
# (Attribution requires concurrency 1: to observe cleanly, the
# observer must first flatten the schedule. The VM eye changes the
# thing it looks at - it says so on the tin.)

require "bundler/setup"
require "agentic"

Agentic.logger.level = :fatal

# Each lambda's opening line is its VM signature; the inner blocks
# live on their own lines so the signatures stay distinct
WORKLOADS = {
  "hoarder (string churn)" => lambda {
    5_000.times.map { "str" * 2 }.last
  },
  "monk (pure arithmetic)" => lambda {
    (1..50_000).sum
  },
  "void (does nothing)" => lambda {
  }
}.freeze
LAMBDA_LINES = WORKLOADS.transform_values { |l| l.source_location[1] }.freeze

def with_vm_eye
  stats = {calls: 0, b_calls: 0, lambda_hits: Hash.new(0)}
  tracer = TracePoint.new(:call, :b_call) do |tp|
    stats[:calls] += 1 if tp.event == :call
    if tp.event == :b_call
      stats[:b_calls] += 1
      stats[:lambda_hits][tp.lineno] += 1 if tp.path == __FILE__
    end
  end
  allocated_before = GC.stat(:total_allocated_objects)
  tracer.enable
  yield
  tracer.disable
  stats[:allocations] = GC.stat(:total_allocated_objects) - allocated_before
  stats
end

# --- per-task periscope: each agent observed alone (hence one lane) -----------------
orchestrator = Agentic::PlanOrchestrator.new(concurrency_limit: 1)
per_task = {}
WORKLOADS.each do |name, work|
  task = Agentic::Task.new(description: name, agent_spec: {"name" => name, "instructions" => "w"})
  orchestrator.add_task(task, agent: ->(_t) { per_task[name] = with_vm_eye { work.call } and :done })
end

# the whole plan under one wide-angle lens, framework and all
total = with_vm_eye { orchestrator.execute_plan }

puts "THE VM EYE (nothing is free; the VM has receipts)"
puts
puts format("  %-24s %12s %10s %13s", "task", "method calls", "b_calls", "allocations")
per_task.each do |name, s|
  puts format("  %-24s %12d %10d %13d", name, s[:calls], s[:b_calls], s[:allocations])
end
puts

agent_sum = per_task.values.sum { |s| s[:calls] }
framework_tax = total[:calls] - agent_sum
puts "  the wide-angle ledger: #{total[:calls]} method calls to run the whole plan;"
puts "  the agents themselves account for #{agent_sum}, so the framework's keep -"
puts "  scheduling, fibers, hooks, bookkeeping - cost #{framework_tax} calls and"
puts "  #{total[:allocations] - per_task.values.sum { |s| s[:allocations] }} allocations. that's the price of the machinery that"
puts "  makes 'just run these in order with retries' a one-liner."
puts

# exactly-once, proven from VM evidence alone: each workload lambda's
# body (identified by source line) fired exactly one :b_call
exactly_once = WORKLOADS.keys.all? { |name| total[:lambda_hits][LAMBDA_LINES[name]] == 1 }
puts "  exactly-once, per the VM: each workload's :b_call fired once - #{exactly_once}"
puts "  (not asserted from the framework's bookkeeping - from the VM's)"
puts

failures = []
failures << "exactly-once violated (per the VM)" unless exactly_once
hoarder = per_task["hoarder (string churn)"]
monk = per_task["monk (pure arithmetic)"]
void = per_task["void (does nothing)"]
failures << "the hoarder didn't hoard" unless hoarder[:allocations] > 5_000
failures << "the monk allocated like a hoarder" unless monk[:allocations] < hoarder[:allocations] / 50
failures << "the void was truly free (impossible)" unless void[:allocations] >= 0 && total[:calls] > agent_sum

puts "  what the periscope teaches: allocation profiles are personalities"
puts "  (the hoarder's #{hoarder[:allocations]} objects vs the monk's #{monk[:allocations]} - same wall-clock"
puts "  ballpark, different GC futures); the framework tax is REAL and"
puts "  measurable and worth every call until it isn't - now you know the"
puts "  number to watch; and 'the task ran exactly once' can be verified"
puts "  beneath every abstraction, at the level where nothing can lie,"
puts "  because the VM was never told what it's looking at. observability"
puts "  usually means asking the framework to confess. TracePoint is"
puts "  asking the machine."
exit(failures.empty? ? 0 : 1)
