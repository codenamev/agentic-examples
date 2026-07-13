# frozen_string_literal: true

# The Survey Scrubber: you asked ten humans "what's blocking your
# team?" and they answered like humans - with names, emails, phone
# numbers, and @handles embedded in the grievances. Every downstream
# system that touches those answers (the category model, the data
# warehouse, the exec summary) is a system that can leak them. So
# the pipeline's FIRST stage, before anything is categorized or
# stored, is the scrubber - and the referee greps everything
# downstream for every seeded PII string, because 'we scrub the
# data' is a claim and grep is a fact. The safest PII is the PII
# you never stored; data about people IS people, and the pipeline's
# order is its ethics.
#
#   bundle exec ruby examples/survey_scrubber.rb
#
# Runs offline; exits 1 if one identifying string survives past
# the scrubber.

require "bundler/setup"
require "agentic"
require "tmpdir"

Agentic.logger.level = :fatal

RESPONSES = [
  "CI is flaky, ask Maria Santos she has the details",
  "deploys blocked on approvals - email varun.k@corp.example about it",
  "our staging db is tiny. @davenotdave complains weekly",
  "hiring! we lost two people and process is drowning us",
  "the linter wars. also call 555-0142 if you want the real story",
  "nobody owns the flaky specs so they rot",
  "process process process. three tickets to change a label",
  "infra costs review meeting eats every tuesday",
  "tooling is fine, honestly it's the approvals",
  "ask Chen Wei or maria.santos@corp.example - migrations block everything"
].freeze
SEEDED_PII = ["Maria Santos", "varun.k@corp.example", "@davenotdave", "555-0142", "Chen Wei", "maria.santos@corp.example"].freeze

SCRUB_RULES = [
  [/[a-z0-9._]+@[a-z0-9.-]+\.[a-z]{2,}/i, "[EMAIL]"],
  [/\b\d{3}-\d{4}\b/, "[PHONE]"],
  [/(?<!\w)@\w+/, "[HANDLE]"],
  [/\b[A-Z][a-z]+ [A-Z][a-z]+\b/, "[NAME]"] # blunt on purpose; recall beats precision for PII
].freeze

CATEGORIES = {
  "tooling" => ["ci", "flaky", "linter", "specs", "tooling"],
  "process" => ["approvals", "process", "tickets", "meeting"],
  "people" => ["hiring", "lost", "owns"],
  "infra" => ["db", "staging", "infra", "costs", "migrations", "deploys"]
}.freeze

warehouse = File.join(Dir.mktmpdir("survey"), "responses.jsonl")

orchestrator = Agentic::PlanOrchestrator.new(concurrency_limit: 4)
scrubbed_tasks = RESPONSES.each_with_index.map do |raw, i|
  scrub = Agentic::Task.new(description: "scrub #{i}", agent_spec: {"name" => "scrubber", "instructions" => "w"}, payload: raw)
  tag = Agentic::Task.new(description: "categorize #{i}", agent_spec: {"name" => "tagger", "instructions" => "w"})
  orchestrator.add_task(scrub, agent: ->(t) {
    SCRUB_RULES.reduce(t.payload) { |text, (pattern, replacement)| text.gsub(pattern, replacement) }
  })
  orchestrator.add_task(tag, [scrub], agent: ->(t) {
    text = t.previous_output
    hits = CATEGORIES.transform_values { |words| words.count { |w| text.downcase.include?(w) } }
    category = hits.max_by { |_, v| v }
    record = {text: text, category: (category[1]).zero? ? "other" : category[0]}
    File.write(warehouse, "#{record}\n", mode: "a") # only scrubbed text ever touches disk
    record
  })
  tag
end

report_task = Agentic::Task.new(description: "report", agent_spec: {"name" => "analyst", "instructions" => "w"})
orchestrator.add_task(report_task, scrubbed_tasks, agent: ->(t) {
  records = scrubbed_tasks.map { |st| t.output_of(st) }
  tally = records.group_by { |r| r[:category] }.transform_values(&:size).sort_by { |_, v| -v }
  quotes = records.first(2).map { |r| r[:text] }
  "TEAM BLOCKERS, Q3 (#{records.size} responses)\n" +
    tally.map { |cat, n| "  #{cat.ljust(8)} #{"#" * n} #{n}" }.join("\n") +
    "\n  sample voices: #{quotes.join(" | ")}"
})
result = orchestrator.execute_plan
report = result.task_result(report_task.id).output

puts "THE SURVEY SCRUBBER (data about people is people; the pipeline order is the ethics)"
puts
report.lines.each { |l| puts "  #{l.rstrip}" }
puts

# --- the referee: grep beats 'we scrub the data' --------------------------------------
downstream = [report, File.read(warehouse), scrubbed_tasks.map { |st| result.task_result(st.id).output.to_s }.join]
leaks = SEEDED_PII.flat_map { |pii| downstream.each_index.select { |d| downstream[d].include?(pii) }.map { |d| [pii, [:report, :warehouse, :records][d]] } }
tallied = report[/\((\d+) responses\)/, 1].to_i

puts "  privacy referee: #{SEEDED_PII.size} seeded identifiers (names, emails, a phone,"
puts "  a handle) grepped against the report, the warehouse file, and every"
puts "  categorized record: #{leaks.empty? ? "ZERO leaks" : "LEAKED: #{leaks.inspect}"}"
puts

failures = []
failures << "PII leaked downstream: #{leaks.inspect}" unless leaks.empty?
failures << "responses lost in aggregation (#{tallied})" unless tallied == RESPONSES.size
failures << "categories degenerate" unless report.include?("process") && report.include?("tooling")
failures << "warehouse got raw text" if SEEDED_PII.any? { |pii| File.read(warehouse).include?(pii) }

puts "  the design choices that matter: the scrubber runs FIRST - before"
puts "  categorization, before the warehouse write, before anything with"
puts "  a disk or a memory - because every stage that sees raw text is a"
puts "  stage that can leak it, and you shrink that set to one. the name"
puts "  rule is blunt on purpose ([A-Z]\\w+ [A-Z]\\w+ catches some false"
puts "  positives): for PII, RECALL beats precision - redacting 'Le"
puts "  Sigh' by mistake costs a chuckle; missing one real name costs a"
puts "  person. and the verification is a grep, not a policy document:"
puts "  every seeded identifier hunted through every downstream surface."
puts "  the aggregate report kept everything the survey was FOR - counts,"
puts "  themes, even sample voices - because anonymized is not the same"
puts "  as useless. it's just useful without a body count."
exit(failures.empty? ? 0 : 1)
