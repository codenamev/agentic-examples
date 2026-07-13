# frozen_string_literal: true

# Bulk Import: the job every team writes badly once - load N
# thousand rows into the database without melting it, and survive
# the crash that WILL happen at row 2,743. Three disciplines, all
# boring, all load-bearing: BATCH (one insert of 500 beats 500
# inserts of one - the database's time is billed per round-trip),
# IDEMPOTENT UPSERT (re-running a batch must be a no-op, because
# at-least-once is the only delivery guarantee reality offers), and
# a JOURNALED CURSOR (completed batches are recorded durably, so the
# resume skips exactly what finished and repeats nothing). The crash
# is included. The crash is always included.
#
#   bundle exec ruby examples/bulk_import.rb
#
# Runs offline; exits 1 unless the import survives its own crash
# with zero duplicates and zero lost rows.

require "bundler/setup"
require "agentic"
require "tmpdir"

Agentic.logger.level = :fatal

ROWS = 5_000
BATCH = 500
CSV_PATH = File.join(Dir.tmpdir, "agentic_import.csv")
JOURNAL_PATH = File.join(Dir.tmpdir, "agentic_import_journal.jsonl")

# The database: a hash with a meter on it. Every call costs a round-trip.
DB = {}
DB_CALLS = Hash.new(0)
def db_upsert_batch(rows)
  DB_CALLS[:batch_upsert] += 1
  rows.each { |row| DB[row["id"]] = row } # upsert: keyed write, naturally idempotent
end

# Generate the file (in real life: the CSV marketing sent you at 5pm).
# Parsed by hand: the csv stdlib leaves the default gems in 3.4, and
# this file has no quoting to worry about - the census taught us well.
File.delete(CSV_PATH) if File.exist?(CSV_PATH)
File.open(CSV_PATH, "w") do |f|
  f.puts "id,email,plan"
  ROWS.times { |i| f.puts "u#{i},user#{i}@example.com,#{["free", "pro"][i % 2]}" }
end

def read_rows(path)
  lines = File.foreach(path).map { |line| line.strip.split(",") }
  header = lines.shift
  lines.map { |values| header.zip(values).to_h }
end

def run_import(sabotage_batch: nil)
  journal = Agentic::ExecutionJournal.new(path: JOURNAL_PATH)
  done = Agentic::ExecutionJournal.replay(path: JOURNAL_PATH).events
    .select { |e| e[:event] == "batch_done" }.map { |e| e[:description].to_i }

  orchestrator = Agentic::PlanOrchestrator.new(concurrency_limit: 1, retry_policy: {max_retries: 0, retryable_errors: []})
  batches = read_rows(CSV_PATH).each_slice(BATCH).to_a
  previous = nil
  skipped = 0
  batches.each_with_index do |rows, index|
    if done.include?(index)
      skipped += 1
      next
    end
    task = Agentic::Task.new(description: "batch #{index}", agent_spec: {"name" => "importer", "instructions" => "w"})
    orchestrator.add_task(task, previous ? [previous] : [], agent: ->(_t) {
      raise Agentic::Errors::LlmAuthenticationError, "power cut at batch #{index}" if index == sabotage_batch
      db_upsert_batch(rows)
      journal.record(:batch_done, description: index.to_s, rows: rows.size)
      :imported
    })
    previous = task
  end
  status = orchestrator.execute_plan.status
  [status, skipped, batches.size]
end

puts "BULK IMPORT (batch, upsert, journal - and the crash is included)"
puts
File.delete(JOURNAL_PATH) if File.exist?(JOURNAL_PATH)

status, _, total = run_import(sabotage_batch: 6)
puts "  monday 17:04 - the import runs, and at batch 6 of #{total}: power cut."
puts "    plan status: #{status}; rows landed so far: #{DB.size} (batches 0-5, durably journaled)"
puts

status2, skipped, = run_import
puts "  monday 17:11 - same command, re-run. no flags, no surgery:"
puts "    journal says #{skipped} batches already done -> skipped; resumed at batch 6"
puts "    plan status: #{status2}; rows in db: #{DB.size}; total batch calls: #{DB_CALLS[:batch_upsert]}"
puts

# At-least-once drill: re-deliver an already-imported batch on purpose
before = DB.size
db_upsert_batch(read_rows(CSV_PATH).first(BATCH))
puts "  and the at-least-once drill: batch 0 re-delivered on purpose ->"
puts "    row count #{before} -> #{DB.size} (upsert made the duplicate delivery a non-event)"
puts

failures = []
failures << "crash run should have failed" unless status == :partial_failure
failures << "resume didn't skip completed work" unless skipped == 6
failures << "rows lost or duplicated (#{DB.size})" unless DB.size == ROWS
failures << "batches re-imported (#{DB_CALLS[:batch_upsert]} calls)" unless DB_CALLS[:batch_upsert] == total + 1 # 10 real + 1 drill
failures << "resume didn't complete" unless status2 == :completed

puts "  the arithmetic that pays the rent: #{ROWS} rows in #{total} round-trips"
puts "  instead of #{ROWS} (the database bills per round-trip, not per row);"
puts "  a resume that skipped exactly the #{skipped} finished batches because"
puts "  the CURSOR lives in a durable journal, not in a variable that"
puts "  died with the process; and an upsert so boring that re-delivery"
puts "  is a shrug - which is the entire trick, because at-least-once"
puts "  is the only delivery guarantee production has ever offered"
puts "  anyone. batch for the database, journal for the crash, upsert"
puts "  for the truth."
exit(failures.empty? ? 0 : 1)
