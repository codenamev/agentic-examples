# frozen_string_literal: true

# The Setup Doctor: every onboarding wiki page is a bug. This runs the
# checks a README asks a new hire to do by hand - gem loads, bundle
# health, git state, catalog presence - in parallel, then one
# diagnosis task reads them all BY NAME and prescribes.
#
#   bundle exec ruby examples/setup_doctor.rb
#
# Runs offline against the current repo. Exit 0 means "start coding".

require "bundler/setup"
require "agentic"

ROOT = File.expand_path("..", __dir__)

def check(description)
  Agentic::Task.new(
    description: description,
    agent_spec: {"name" => description, "instructions" => "examine the machine"}
  )
end

orchestrator = Agentic::PlanOrchestrator.new(concurrency_limit: 4)

ruby = check("agentic gem")
orchestrator.add_task(ruby, agent: ->(_t) {
  {ok: defined?(Agentic::VERSION) ? true : false,
   detail: "agentic #{Agentic::VERSION} loaded (ruby #{RUBY_VERSION})"}
})

bundle = check("bundle health")
orchestrator.add_task(bundle, agent: ->(_t) {
  ok = system("bundle check > /dev/null 2>&1", chdir: ROOT)
  {ok: ok, detail: ok ? "all gems installed" : "run bin/setup (or bundle install)"}
})

git = check("git state")
orchestrator.add_task(git, agent: ->(_t) {
  dirty = `git -C #{ROOT} status --porcelain`.lines.size
  branch = `git -C #{ROOT} branch --show-current`.strip
  {ok: true, detail: "on #{branch}, #{dirty} uncommitted change(s)"}
})

suite = check("example catalog")
orchestrator.add_task(suite, agent: ->(_t) {
  examples = Dir[File.join(ROOT, "examples", "*.rb")].size
  {ok: examples.positive?, detail: "#{examples} runnable examples (bin/smoke checks them all)"}
})

diagnosis = check("diagnosis")
orchestrator.add_task(diagnosis, needs: {ruby: ruby, bundle: bundle, git: git, suite: suite}, agent: ->(t) {
  findings = {
    "ruby" => t.needs.ruby,
    "bundle" => t.needs.bundle,
    "git" => t.needs.git,
    "catalog" => t.needs.suite
  }
  {healthy: findings.values.all? { |f| f[:ok] }, findings: findings}
})

result = orchestrator.execute_plan
verdict = result.results[diagnosis.id].output

puts "SETUP DOCTOR"
puts
verdict[:findings].each do |name, finding|
  puts format("  %s  %-8s %s", finding[:ok] ? "ok " : "FIX", name, finding[:detail])
end
puts
if verdict[:healthy]
  puts "you're good. write code, not wiki pages."
else
  puts "fix the FIX lines above, run me again."
  exit 1
end
