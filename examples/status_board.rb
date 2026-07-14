# frozen_string_literal: true

# Status Board: output is not always text. The wallboard your team
# glances at is a FILE - an SVG chart, a CSV you can pivot, a JSON
# summary a dashboard ingests - and a plan is the right machine to
# produce one: collect (aggregate raw timings), render (draw the SVG),
# export (write CSV + JSON), each step checkable, the artifacts the
# deliverable. Examples honor AGENTIC_ARTIFACTS_DIR so the showcase
# can collect and display what a run produces; without it they write
# to a tmpdir like polite guests.
#
#   bundle exec ruby examples/status_board.rb
#
# Runs offline; exits 1 unless the SVG holds one bar per suite, the
# CSV re-adds to the JSON's totals, and every artifact is non-empty.

require "bundler/setup"
require "agentic"
require "tmpdir"
require "json"

Agentic.logger.level = :fatal

OUT = ENV["AGENTIC_ARTIFACTS_DIR"] || Dir.mktmpdir("status_board")
Dir.mkdir(OUT) unless Dir.exist?(OUT)

# Two weeks of CI timings (seconds), deterministic world:
rng = Random.new(42)
SUITES = %w[models requests jobs mailers system lint].freeze
TIMINGS = SUITES.to_h { |s| [s, Array.new(14) { 40 + rng.rand(60) + ((s == "system") ? 90 : 0) }] }

collect = Agentic::Task.new(description: "aggregate suite timings",
  agent_spec: {"name" => "collector", "instructions" => "aggregate"})
render = Agentic::Task.new(description: "render the SVG wallboard",
  agent_spec: {"name" => "chartist", "instructions" => "draw"})
export = Agentic::Task.new(description: "export CSV + JSON",
  agent_spec: {"name" => "exporter", "instructions" => "write"})

stats = nil
orchestrator = Agentic::PlanOrchestrator.new(concurrency_limit: 1, retry_policy: {max_retries: 0, retryable_errors: []})
orchestrator.add_task(collect, [], agent: ->(_t) {
  stats = SUITES.map { |s|
    d = TIMINGS[s]
    {suite: s, mean: (d.sum.to_f / d.size).round(1), max: d.max, runs: d.size}
  }
  :aggregated
})
orchestrator.add_task(render, [collect], agent: ->(_t) {
  w, bar_h, gap, left = 460, 22, 8, 90
  peak = stats.map { |r| r[:mean] }.max
  bars = stats.each_with_index.map { |r, i|
    y = 10 + i * (bar_h + gap)
    len = ((w - left - 60) * r[:mean] / peak).round
    %(<text x="#{left - 6}" y="#{y + 15}" text-anchor="end" font-size="12">#{r[:suite]}</text>) +
      %(<rect x="#{left}" y="#{y}" width="#{len}" height="#{bar_h}" fill="#4c78a8"/>) +
      %(<text x="#{left + len + 6}" y="#{y + 15}" font-size="11">#{r[:mean]}s</text>)
  }.join
  h = 20 + stats.size * (bar_h + gap)
  File.write(File.join(OUT, "status_board.svg"),
    %(<svg xmlns="http://www.w3.org/2000/svg" width="#{w}" height="#{h}" font-family="sans-serif">#{bars}</svg>))
  :rendered
})
orchestrator.add_task(export, [render], agent: ->(_t) {
  File.write(File.join(OUT, "status_board.csv"),
    "suite,mean_seconds,max_seconds,runs\n" + stats.map { |r| "#{r[:suite]},#{r[:mean]},#{r[:max]},#{r[:runs]}" }.join("\n") + "\n")
  File.write(File.join(OUT, "summary.json"),
    JSON.pretty_generate({suites: stats.size, total_mean_seconds: stats.sum { |r| r[:mean] }.round(1), slowest: stats.max_by { |r| r[:mean] }[:suite]}))
  :exported
})
status = orchestrator.execute_plan.status

puts "STATUS BOARD (the deliverable is files, the plan is the factory)"
puts
puts "  plan status: #{status}; artifacts in #{OUT}:"
Dir[File.join(OUT, "*")].sort.each { |f| puts "    #{File.basename(f).ljust(18)} #{File.size(f)} bytes" }
puts

svg = File.read(File.join(OUT, "status_board.svg"), encoding: "UTF-8")
csv = File.readlines(File.join(OUT, "status_board.csv"))
summary = JSON.parse(File.read(File.join(OUT, "summary.json")))
csv_total = csv.drop(1).sum { |l| l.split(",")[1].to_f }.round(1)

failures = []
failures << "plan status: #{status}" unless status == :completed
failures << "SVG bars != suites" unless svg.scan("<rect").size == SUITES.size
failures << "CSV rows != suites" unless csv.size == SUITES.size + 1
failures << "JSON total #{summary["total_mean_seconds"]} != CSV re-sum #{csv_total}" unless summary["total_mean_seconds"] == csv_total
failures << "an artifact is empty" if Dir[File.join(OUT, "*")].any? { |f| File.zero?(f) }
failures << "slowest suite should be system" unless summary["slowest"] == "system"

puts "  the referee doesn't trust the plan's word - it reopens the files:"
puts "  #{svg.scan("<rect").size} bars for #{SUITES.size} suites, the CSV re-adds to the"
puts "  JSON's #{summary["total_mean_seconds"]}s, and \"#{summary["slowest"]}\" is slowest, as anyone who has"
puts "  run a system suite already knew. artifacts you can open beat"
puts "  claims you have to believe."
exit(failures.empty? ? 0 : 1)
