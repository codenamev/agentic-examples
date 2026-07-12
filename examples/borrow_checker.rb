# frozen_string_literal: true

# The Borrow Checker: I brought Rust's ownership model to a language
# that never asked for it, and I regret nothing. Task outputs get
# ownership semantics: a value can be MOVED to exactly one consumer
# (who may then mutate it - ownership is mutation rights), or
# BORROWED by any number of readers (who receive it deep-frozen,
# because a shared reference you can mutate is just a bug with
# extra steps). Double moves are rejected at ASSEMBLY time with a
# proper error[E0382], because the whole point of a borrow checker
# is that the crime is prevented, not avenged.
#
#   bundle exec ruby examples/borrow_checker.rb
#
# Runs offline; exits 1 unless ownership is actually enforced.

require "bundler/setup"
require "agentic"

Agentic.logger.level = :fatal

class BorrowChecker
  Claim = Struct.new(:consumer, :mode)

  def initialize
    @claims = Hash.new { |h, k| h[k] = [] }
  end

  def deep_freeze(obj)
    case obj
    when Hash then obj.each { |k, v|
                     deep_freeze(k)
                     deep_freeze(v)
                   }.freeze
    when Array then obj.each { |v| deep_freeze(v) }.freeze
    else obj.freeze
    end
  end

  # Declare intent at assembly time - this is the "compile" phase
  def claim(producer, consumer, mode)
    @claims[producer] << Claim.new(consumer, mode)
  end

  # Rust rule, one graph up: any number of borrows, at most one move
  def check!
    errors = []
    @claims.each do |producer, claims|
      moves = claims.select { |c| c.mode == :move }
      next unless moves.size > 1
      errors << <<~ERR
        error[E0382]: use of moved value: `#{producer}.output`
          --> plan assembly
           note: value moved to `#{moves[0].consumer}` here
           note: value used again by `#{moves[1].consumer}` after move
           help: consider borrowing instead: mode: :borrow
      ERR
    end
    errors
  end

  def deliver(value, mode)
    (mode == :borrow) ? deep_freeze(Marshal.load(Marshal.dump(value))) : value
  end
end

def build_pipeline(second_consumer_mode:)
  checker = BorrowChecker.new
  orchestrator = Agentic::PlanOrchestrator.new(concurrency_limit: 3)
  incidents = []

  fetch = Agentic::Task.new(description: "fetch", agent_spec: {"name" => "fetch", "instructions" => "w"})
  orchestrator.add_task(fetch, agent: ->(_t) { {records: ["alpha", "beta"], count: 2} })

  enrich = Agentic::Task.new(description: "enrich", agent_spec: {"name" => "enrich", "instructions" => "w"})
  checker.claim("fetch", "enrich", :move)
  orchestrator.add_task(enrich, [fetch], agent: ->(t) {
    owned = checker.deliver(t.previous_output, :move)
    owned[:records] << "gamma" # the owner may mutate; that's what owning MEANS
    owned.merge(enriched: true)
  })

  audit = Agentic::Task.new(description: "audit", agent_spec: {"name" => "audit", "instructions" => "w"})
  checker.claim("fetch", "audit", second_consumer_mode)
  orchestrator.add_task(audit, [fetch], agent: ->(t) {
    borrowed = checker.deliver(t.previous_output, second_consumer_mode)
    begin
      borrowed[:records] << "CORRUPTION" # the auditor turns to crime
      incidents << "mutation of a borrow SUCCEEDED (checker asleep)"
    rescue FrozenError
      incidents << "auditor's mutation attempt stopped by FrozenError (the borrow held)"
    end
    {records_seen: borrowed[:records].size}
  })

  [checker, orchestrator, incidents, {fetch: fetch, enrich: enrich, audit: audit}]
end

puts "THE BORROW CHECKER (fighting for memory safety in a language with no memory)"
puts

# --- scene 1: a well-typed plan - one move, one borrow, one attempted crime ---------
checker, orchestrator, incidents, tasks = build_pipeline(second_consumer_mode: :borrow)
compile_errors = checker.check!
result = orchestrator.execute_plan
enriched = result.task_result(tasks[:enrich].id).output
puts "  scene 1 - one move (enrich) + one borrow (audit): #{compile_errors.empty? ? "borrow check PASSES" : "rejected?!"}"
puts "    the owner mutated freely: records grew to #{enriched[:records].size} (ownership is mutation rights)"
puts "    #{incidents.first}"
puts

# --- scene 2: two moves of the same value - rejected before anything runs -----------
checker2, _orchestrator2, _incidents2, _tasks2 = build_pipeline(second_consumer_mode: :move)
errors = checker2.check!
puts "  scene 2 - both consumers demand a move. the compiler(ish) speaks:"
errors.each { |e| e.lines.each { |l| puts "    #{l.rstrip}" } }
puts "    nothing executed. the crime was PREVENTED, not avenged - that's the"
puts "    entire difference between a checker and a postmortem."
puts

failures = []
failures << "clean plan failed" unless result.status == :completed && enriched[:records].size == 3
failures << "borrow was mutable" unless incidents.first&.include?("FrozenError")
failures << "double move not rejected" unless errors.size == 1 && errors.first.include?("E0382")

puts "  what ports and what doesn't: the MODEL ports beautifully - move"
puts "  semantics are just 'exactly one consumer may treat this as its"
puts "  own', borrows are 'everyone else gets it deep-frozen', and the"
puts "  aliasing-XOR-mutation rule is enforceable with a Struct, a Hash,"
puts "  and Marshal. what doesn't port is the TIMING: Rust rejects at"
puts "  compile time; here 'assembly time' plays the part, which is"
puts "  still before anything RUNS, which is the part that matters."
puts "  the deep freeze on borrows is the honest cost - in Ruby, the"
puts "  only reference nobody can mutate is a frozen copy. fearless"
puts "  concurrency starts with knowing whose data it is; turns out you"
puts "  can know that in any language, if you're willing to write it"
puts "  down at the seam."
exit(failures.empty? ? 0 : 1)
