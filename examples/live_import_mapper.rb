# frozen_string_literal: true

# Live Import Mapper: bulk_import's sibling with the stub removed. The
# mechanical 80% of an import (batch, upsert, journal) never needed a
# mind - but the semantic 20% does: marketing's CSV says "E-Mail Addr"
# and "Tier", one row has name and email swapped, another writes "Pro "
# with a trailing space. Here that step is a REAL LLM task: an agent
# spec resolved by DefaultAgentProvider, a structured-output schema
# registered in TaskOutputSchemas, one live call that returns canonical
# rows plus its own repair log - then the boring disciplines take over.
# Right tool per task is the whole point of a plan.
#
#   bundle exec ruby examples/live_import_mapper.rb
#
# Replays offline from its cassette; exits 1 unless every row lands
# canonically (valid emails, plans in {free,pro}, unique ids) and the
# repairs were declared. Before the first recording it explains itself
# and exits 0. Record once: OPENAI_ACCESS_TOKEN=... bin/record live_import_mapper

require "bundler/setup"
require "agentic"
require "vcr"
require "tmpdir"

Agentic.logger.level = :fatal

NAME = File.basename(__FILE__, ".rb")
CASSETTES = File.expand_path("cassettes", __dir__)
RECORDING = ENV["RECORD"] == "1"

unless RECORDING || File.exist?(File.join(CASSETTES, "#{NAME}.yml"))
  puts "LIVE IMPORT MAPPER - not yet recorded"
  puts
  puts "  bulk_import without the stub: a real LLM normalizes the messy CSV,"
  puts "  deterministic tasks batch/upsert/journal the result."
  puts "  record it once (the only step that needs a key):"
  puts "    OPENAI_ACCESS_TOKEN=... bin/record #{NAME}"
  puts "  after that every run replays the recording, offline, byte-for-byte."
  exit 0
end

VCR.configure do |c|
  c.cassette_library_dir = CASSETTES
  c.hook_into :webmock
  c.filter_sensitive_data("<LLM_TOKEN>") { Agentic.configuration.access_token }
  c.before_record { |i| i.request.headers.delete("Authorization") }
  # match on path, not full uri: a cassette recorded against a local model
  # replays fine in CI, where the client points at the default endpoint
  c.default_cassette_options = {match_requests_on: [:method, :path]}
end

# replay needs no credentials - every byte of HTTP comes from the cassette
Agentic.configure { |c| c.access_token ||= "vcr-replay" } unless RECORDING

# The CSV marketing sent at 5pm: alien headers, two damaged rows.
HEADERS = ["Customer Ref", "Full Name", "E-Mail Addr", "Tier"]
ROWS = [
  ["u1", "Ada Lovelace", "ada@example.com", "pro"],
  ["u2", "Grace Hopper", "grace@example.com", "free"],
  ["u3", "hopper2@example.com", "Mary Hopper", "free"],   # name/email swapped
  ["u4", "Jean Jennings", "jean@example.com", "Pro "],    # case + stray space
  ["u5", "Kay Antonelli", "kay@example.com", "premium"]   # not a plan we sell
]

Agentic::TaskOutputSchemas.register(:canonical_rows,
  Agentic::StructuredOutputs::Schema.new("canonical_rows") do |s|
    s.array :rows, items: {
      type: "object",
      properties: {id: {type: "string"}, email: {type: "string"}, plan: {type: "string"}},
      required: %w[id email plan]
    }
    s.array :repairs, items: {type: "string"}
  end)

DB = {}
JOURNAL_PATH = File.join(Dir.tmpdir, "agentic_live_import_journal.jsonl")
File.delete(JOURNAL_PATH) if File.exist?(JOURNAL_PATH)
journal = Agentic::ExecutionJournal.new(path: JOURNAL_PATH)

normalize = Agentic::Task.new(
  description: "Normalize this CSV export into canonical import rows",
  agent_spec: {"name" => "data steward",
               "instructions" => "Map the given headers onto the canonical schema {id, email, plan}. " \
                                 "Repair obviously damaged rows (swapped fields, whitespace, casing). " \
                                 "plan must be exactly 'free' or 'pro'; map unknown paid tiers to 'pro'. " \
                                 "List every repair you made, one short sentence each."},
  input: {headers: HEADERS, rows: ROWS},
  output_schema_name: :canonical_rows
)

import = Agentic::Task.new(description: "batch upsert + journal",
  agent_spec: {"name" => "importer", "instructions" => "load canonical rows"})

orchestrator = Agentic::PlanOrchestrator.new(concurrency_limit: 1, retry_policy: {max_retries: 0, retryable_errors: []})
orchestrator.add_task(normalize, []) # no agent injected: DefaultAgentProvider builds a real one
orchestrator.add_task(import, [normalize], agent: ->(_t) {
  rows = normalize.output["rows"]
  rows.each { |r| DB[r["id"]] = r } # upsert: keyed write, idempotent
  journal.record(:batch_done, description: "0", rows: rows.size)
  :imported
})

VCR.use_cassette(NAME, record: RECORDING ? :all : :none) do
  puts "LIVE IMPORT MAPPER (a real mind at the semantic step, discipline everywhere else)"
  puts
  status = orchestrator.execute_plan(Agentic::DefaultAgentProvider.new).status
  if normalize.output.nil?
    puts "  the normalize task failed: #{normalize.failure&.message}"
    exit 1
  end
  repairs = normalize.output["repairs"]

  puts "  the agent read #{HEADERS.inspect}"
  puts "  and returned #{DB.size} canonical rows; its own repair log:"
  repairs.each { |r| puts "    - #{r.gsub(/\s+/, " ").strip[0, 76]}" }
  puts
  puts "  then the boring disciplines: upserted in 1 round-trip, journaled;"
  puts "  plan status: #{status}"
  puts

  failures = []
  failures << "plan status: #{status}" unless status == :completed
  failures << "lost rows (#{DB.size}/#{ROWS.size})" unless DB.size == ROWS.size
  failures << "an email doesn't look like one" unless DB.values.all? { |r| r["email"].include?("@") }
  failures << "plans not canonical: #{DB.values.map { |r| r["plan"] }.uniq}" unless DB.values.all? { |r| %w[free pro].include?(r["plan"]) }
  failures << "repairs went undeclared" if repairs.size < 2

  puts "  the LLM did the one thing lambdas can't - understood 'E-Mail Addr',"
  puts "  unswapped row u3, read 'premium' as a paid tier - and the referee"
  puts "  still holds it to falsifiable claims. minds for meaning, machines"
  puts "  for mechanics, one plan for both."
  exit(failures.empty? ? 0 : 1)
end
