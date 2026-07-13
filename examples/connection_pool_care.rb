# frozen_string_literal: true

# Connection Pool Care: the production incident with the most
# misleading symptoms - the database is fine, the app is fine, and
# nothing works, because the connection pool drained one leaked
# checkout at a time. The leak is always the same code: a checkout
# without an ensure, an exception on the unhappy path, a connection
# that never comes home. Two disciplines fix it forever: the BLOCK
# FORM is the API (checkout/checkin as separate calls is rope, and
# not the climbing kind), and the pool itself keeps RECEIPTS - when
# exhaustion hits, the timeout error names every holder and how
# long they've squatted, so the leak is attributed at the moment it
# hurts instead of guessed at from graphs three hours later.
#
#   bundle exec ruby examples/connection_pool_care.rb
#
# Runs offline; exits 1 unless the leak is caught with names AND
# the block form provably ends it.

require "bundler/setup"
require "agentic"

Agentic.logger.level = :fatal

def mono = Process.clock_gettime(Process::CLOCK_MONOTONIC)

class PoolExhausted < StandardError; end

class Pool
  attr_reader :size

  def initialize(size)
    @size = size
    @available = Array.new(size) { |i| "conn-#{i}" }
    @holders = {}
  end

  def checkout(who, timeout: 0.05)
    deadline = mono + timeout
    while @available.empty?
      raise PoolExhausted, exhaustion_report(who) if mono > deadline
      sleep(0.005)
    end
    conn = @available.pop
    @holders[conn] = {who: who, since: mono}
    conn
  end

  def checkin(conn)
    @holders.delete(conn)
    @available.push(conn)
  end

  # The block form IS the api; everything else is rope
  def with(who, &block)
    conn = checkout(who)
    begin
      yield conn
    ensure
      checkin(conn)
    end
  end

  def available_count = @available.size

  def exhaustion_report(who)
    lines = @holders.map { |conn, h| "#{conn} held by #{h[:who]} for #{((mono - h[:since]) * 1000).round}ms" }
    "#{who} waited past timeout; pool of #{@size} exhausted. current holders:\n      " + lines.join("\n      ")
  end
end

# Thirty jobs; every fourth hits the unhappy path and raises
def run_jobs(pool, style:)
  orchestrator = Agentic::PlanOrchestrator.new(concurrency_limit: 8, retry_policy: {max_retries: 0, retryable_errors: []})
  outcomes = {served: 0, failed_cleanly: 0, exhausted: []}
  30.times do |i|
    task = Agentic::Task.new(description: "job #{i}", agent_spec: {"name" => "job #{i}", "instructions" => "query"})
    orchestrator.add_task(task, agent: ->(_t) {
      work = -> {
        sleep(0.005)
        raise "unhappy path in job #{i}" if i % 4 == 3
        outcomes[:served] += 1
      }
      begin
        if style == :leaky
          conn = pool.checkout("job #{i}") # no ensure. the author was in a hurry.
          work.call
          pool.checkin(conn) # unreachable on the unhappy path
        else
          pool.with("job #{i}") { work.call }
        end
        :done
      rescue PoolExhausted => e
        outcomes[:exhausted] << e.message
        raise
      rescue RuntimeError
        outcomes[:failed_cleanly] += 1
        raise
      end
    })
  end
  orchestrator.execute_plan
  outcomes
end

puts "CONNECTION POOL CARE (the block form is the API; the pool keeps receipts)"
puts

leaky_pool = Pool.new(5)
leaky = run_jobs(leaky_pool, style: :leaky)
puts "  the leaky version (checkout with no ensure, unhappy path every 4th job):"
puts "    served: #{leaky[:served]}; pool now holds #{leaky_pool.available_count}/5 connections"
puts "    #{leaky[:exhausted].size} job(s) hit exhaustion, and the error came with RECEIPTS:"
puts "      #{leaky[:exhausted].first&.lines&.first}#{leaky[:exhausted].first&.lines&.[](1)}"
puts

healthy_pool = Pool.new(5)
healthy = run_jobs(healthy_pool, style: :block)
puts "  the block-form version (same jobs, same failure rate):"
puts "    served: #{healthy[:served]}; failed cleanly: #{healthy[:failed_cleanly]}; exhausted: #{healthy[:exhausted].size}"
puts "    pool restored to #{healthy_pool.available_count}/5 - every connection came home, including from the failures"
puts

failures = []
failures << "leak didn't drain the pool" unless leaky_pool.available_count.zero? && leaky[:exhausted].any?
failures << "exhaustion report lacks receipts" unless leaky[:exhausted].first.to_s.include?("held by job")
failures << "block form leaked (#{healthy_pool.available_count}/5)" unless healthy_pool.available_count == 5
failures << "block form dropped work" unless healthy[:served] == 23 && healthy[:failed_cleanly] == 7

puts "  the two disciplines, priced: the unhappy path leaked exactly"
puts "  #{5 - leaky_pool.available_count} connections (one per early failure until the pool was dry),"
puts "  and from then on INNOCENT jobs paid - exhaustion punishes"
puts "  whoever arrives after the leak, which is why pool incidents"
puts "  always look like someone else's fault. the block form ends the"
puts "  species: ensure runs on the unhappy path too, so every failure"
puts "  returned its connection. and the receipts matter as much as the"
puts "  fix - an exhaustion error that names its holders and their"
puts "  hold-times turns 'the database is slow??' into 'job 3 has held"
puts "  conn-4 for 40ms and never checks in' - attribution at the"
puts "  moment of pain, not archaeology after it."
exit(failures.empty? ? 0 : 1)
