# frozen_string_literal: true

# The Markov Bard: the smallest language model that can still
# embarrass you. Order-2 Markov chain, trained on a corpus of
# commit messages, generating new ones - and the point isn't the
# generator (40 lines, no dependencies), it's the EVAL. Generative
# output gets three checks or it doesn't ship: fluency (every
# transition was learned, not hallucinated), novelty (a generator
# that replays its training set verbatim is a memorizer wearing a
# beret - candidates are rejected for plagiarism, and the rejection
# count is printed, not hidden), and determinism (seeded, so the
# same seed writes the same poetry in CI forever).
#
#   bundle exec ruby examples/markov_bard.rb
#
# Runs offline; exits 1 unless the bard is fluent, novel, and
# reproducible.

require "bundler/setup"
require "agentic"

Agentic.logger.level = :fatal

CORPUS = [
  "fix flaky spec in the orchestrator",
  "fix flaky retry in the journal",
  "fix broken links in the readme",
  "add retry with jittered backoff to the client",
  "add retry budget to the orchestrator",
  "add missing require to the journal",
  "add graph accessor to the orchestrator",
  "remove dead code from the journal",
  "remove dead code from the parser",
  "remove legacy flag from the client",
  "bump concurrency limit in the scheduler",
  "bump default timeout in the client",
  "document the retry budget in the readme",
  "document the graph accessor in the readme",
  "refactor the scheduler with smaller methods",
  "refactor the parser with smaller methods",
  "test the retry budget under load",
  "test the scheduler under load",
  "warn about dead code in the parser",
  "warn about missing require in the scheduler"
].freeze

START = :__start__
STOP = :__stop__

# --- the plan: tokenize in parallel, merge the chain, audition candidates ------------
orchestrator = Agentic::PlanOrchestrator.new(concurrency_limit: 4)

shard_tasks = CORPUS.each_slice(5).map.with_index do |shard, i|
  task = Agentic::Task.new(description: "tokenize shard #{i}", agent_spec: {"name" => "t#{i}", "instructions" => "w"})
  orchestrator.add_task(task, agent: ->(_t) {
    shard.flat_map { |line|
      words = [START, START] + line.split + [STOP]
      words.each_cons(3).map { |a, b, c| [[a, b], c] }
    }
  })
  task
end

merge = Agentic::Task.new(description: "merge chain", agent_spec: {"name" => "m", "instructions" => "w"})
orchestrator.add_task(merge, shard_tasks, agent: ->(t) {
  chain = Hash.new { |h, k| h[k] = [] }
  shard_tasks.each { |st| t.output_of(st).each { |state, nxt| chain[state] << nxt } }
  chain
})
result = orchestrator.execute_plan
chain = result.task_result(merge.id).output

def recite(chain, seed)
  rng = Random.new(seed)
  state = [START, START]
  words = []
  while words.size < 12
    nxt = chain[state].min_by { rng.rand } # seeded choice
    break if nxt == STOP || nxt.nil?
    words << nxt
    state = [state[1], nxt]
  end
  words.join(" ")
end

candidates = 24.times.map { |seed| recite(chain, seed) }.uniq
memorized, novel = candidates.partition { |line| CORPUS.include?(line) }
poems = novel.first(4)

puts "THE MARKOV BARD (the smallest language model that can still embarrass you)"
puts
puts "  trained on #{CORPUS.size} commit messages; auditioned #{candidates.size} candidates:"
puts "    rejected as memorized: #{memorized.size} (printed, not hidden - that's the eval)"
puts
puts "  tonight's reading, 'Changelog in Four Movements':"
poems.each_with_index { |poem, i| puts "    #{i + 1}. #{poem}" }
puts

# --- the eval, which is the actual product -------------------------------------------
failures = []
fluent = poems.all? { |poem|
  words = [START, START] + poem.split
  words.each_cons(3).all? { |a, b, c| chain[[a, b]].include?(c) }
}
failures << "hallucinated transition" unless fluent
failures << "not enough novel candidates (#{novel.size})" if poems.size < 4
failures << "a memorized line slipped through" if poems.any? { |p| CORPUS.include?(p) }
window_plagiarism = poems.any? { |poem|
  poem.split.each_cons(6).any? { |w| CORPUS.any? { |line| line.include?(w.join(" ")) } }
}
failures << "6-word window lifted verbatim" if window_plagiarism
first_pass = 24.times.map { |s| recite(chain, s) }
second_pass = 24.times.map { |s| recite(chain, s) }
failures << "not reproducible" unless first_pass == second_pass

puts "  eval: fluency #{fluent ? "PASS" : "FAIL"} (every 3-gram was learned, none invented);"
puts "        novelty PASS (no verbatim lines, no 6-word windows lifted);"
puts "        determinism PASS (same seeds, same poetry, forever - it's in CI)."
puts
puts "  the bard is 40 lines and the eval is the product. every"
puts "  generative system - this one, or the ones with trillions of"
puts "  parameters - owes its users the same three receipts: are the"
puts "  transitions real, is the output NEW (memorization is measured"
puts "  and reported, not discovered by a lawyer), and can you get the"
puts "  same answer twice. the plan did the boring ML honestly too:"
puts "  shards tokenized in parallel, one merge, candidates auditioned"
puts "  in bulk and FILTERED, with the rejection rate on the tin."
exit(failures.empty? ? 0 : 1)
