# frozen_string_literal: true

# The Deprecation Shepherd: removing an API is easy; removing it
# WITHOUT breaking anyone is a data problem wearing an etiquette
# costume. The failure mode is universal - a warning gets printed
# for two years, nobody reads warnings, the removal ships, pagers
# sing. The cure is to treat deprecation as data collection: the
# shim counts every call WITH its call site, the removal is gated
# on observed evidence (zero uses in the window, not zero
# complaints), and while usage exists the gate names the holdouts
# instead of shaming the void. You don't remove an API when the
# changelog says you may; you remove it when the telemetry says
# nobody's standing there.
#
#   bundle exec ruby examples/deprecation_shepherd.rb
#
# Runs offline; exits 1 unless the gate refuses while evidence
# exists and approves only at observed zero.

require "bundler/setup"
require "agentic"

Agentic.logger.level = :fatal

# The library: one deprecated door, one replacement
USAGE = Hash.new(0)
module Billing
  def self.legacy_total(items) # deprecated since 2.1
    site = caller_locations(1, 1).first.label
    USAGE[site] += 1
    total(items) # the shim delegates; behavior identical, data collected
  end

  def self.total(items) = items.sum { |i| i[:cents] }
end

# The app: three call sites, migrated one phase at a time
def app_workload(migrated:)
  orchestrator = Agentic::PlanOrchestrator.new(concurrency_limit: 3)
  jobs = {
    "checkout_flow" => 5, # calls per run
    "nightly_reconcile" => 2,
    "admin_refunds" => 1
  }
  jobs.each do |site, calls|
    task = Agentic::Task.new(description: site, agent_spec: {"name" => site, "instructions" => "bill"})
    orchestrator.add_task(task, agent: ->(_t) {
      calls.times do
        items = [{cents: 1200}, {cents: 300}]
        migrated.include?(site) ? Billing.total(items) : send(:call_from, site, items)
      end
      :ran
    })
  end
  orchestrator.execute_plan
end

# Distinct call sites for honest attribution (the label is the method name)
def call_from(site, items) = method("site_#{site}").call(items)

def site_checkout_flow(items) = Billing.legacy_total(items)

def site_nightly_reconcile(items) = Billing.legacy_total(items)

def site_admin_refunds(items) = Billing.legacy_total(items)

# The gate: evidence in, verdict out
def removal_gate
  USAGE.clear # open a fresh observation window
  yield       # let a representative workload run through it
  if USAGE.empty?
    {verdict: :approved, holdouts: {}}
  else
    {verdict: :refused, holdouts: USAGE.dup}
  end
end

puts "THE DEPRECATION SHEPHERD (remove when the telemetry says nobody's standing there)"
puts

phases = [
  {label: "release 2.1 - shim in place, nobody migrated yet", migrated: []},
  {label: "release 2.2 - checkout and reconcile migrated", migrated: ["checkout_flow", "nightly_reconcile"]},
  {label: "release 2.3 - the refunds admin finally migrates", migrated: ["checkout_flow", "nightly_reconcile", "admin_refunds"]}
]

verdicts = phases.map do |phase|
  gate = removal_gate { app_workload(migrated: phase[:migrated]) }
  puts "  #{phase[:label]}:"
  if gate[:verdict] == :refused
    puts "    removal REFUSED - #{gate[:holdouts].values.sum} call(s) observed from #{gate[:holdouts].size} site(s):"
    gate[:holdouts].each { |site, count| puts "      #{site}: #{count} call(s) this window" }
  else
    puts "    removal APPROVED - zero uses observed. the door can close."
  end
  puts
  gate
end

failures = []
failures << "gate approved with 3 live sites" unless verdicts[0][:verdict] == :refused && verdicts[0][:holdouts].size == 3
failures << "gate lost track of the holdout" unless verdicts[1][:verdict] == :refused && verdicts[1][:holdouts].keys == ["site_admin_refunds"]
failures << "gate never approved" unless verdicts[2][:verdict] == :approved
failures << "call counts wrong" unless verdicts[0][:holdouts].values.sum == 8

puts "  the shepherd's three rules, all data: the shim DELEGATES (users"
puts "  keep working - a deprecation that breaks people is just a"
puts "  removal with extra steps) while counting every call with its"
puts "  SITE, because 'someone still uses this' is useless and"
puts "  'admin_refunds calls it once nightly' is a pull request you can"
puts "  write; the gate consumes an observation WINDOW, not a release"
puts "  count - time passing is not evidence, traffic passing is; and"
puts "  the approval is falsifiable: zero observed uses in a"
puts "  representative window, or no removal. two releases of warnings"
puts "  convinced nobody in the history of software. one report naming"
puts "  the last holdout has ended every deprecation I've ever shipped."
exit(failures.empty? ? 0 : 1)
