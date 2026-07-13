# frozen_string_literal: true

# Carrier Quotes: the most common integration problem in commerce -
# ask three shipping carriers for rates, and cope with the fact that
# on any given afternoon one is slow, one is down, and one has
# quietly changed its response format. The confident-code answer:
# ALL defensiveness lives at the boundary. Each carrier adapter
# converts whatever happened - success, timeout, garbage - into an
# object with the same face (a Quote or an Unavailable), so the core
# that compares and chooses contains not one nil check, not one
# rescue, not one question mark it didn't want. Timid code asks
# "but what if?" at every line; confident code asks it ONCE, at the
# door.
#
#   bundle exec ruby examples/carrier_quotes.rb
#
# Runs offline; exits 1 unless checkout survives every weather.

require "bundler/setup"
require "agentic"

Agentic.logger.level = :fatal

Quote = Struct.new(:carrier, :cents, :days) do
  def available? = true

  def to_s = "#{carrier}: $#{cents / 100.0} in #{days}d"
end

Unavailable = Struct.new(:carrier, :reason) do
  def available? = false

  def cents = Float::INFINITY

  def to_s = "#{carrier}: unavailable (#{reason})"
end

BUDGET = 0.05

# The carriers, as found in nature
CARRIERS = {
  "TurtleShip" => -> {
                    sleep(0.01)
                    {price_cents: 899, transit_days: 5}
                  },
  "FedUp" => -> {
               sleep(0.2)
               {price_cents: 1499, transit_days: 1}
             }, # asleep at the desk
  "ParcelPanic" => -> { {cost: "cheap!!", eta: "soon"} } # changed their API. again.
}.freeze

# The boundary: one adapter, all the suspicion in the file
def quote_from(carrier, raw_call)
  raw = nil
  thread = Thread.new { raw = raw_call.call }
  unless thread.join(BUDGET)
    thread.kill
    return Unavailable.new(carrier, "no answer within #{(BUDGET * 1000).round}ms")
  end
  cents = raw[:price_cents]
  days = raw[:transit_days]
  return Unavailable.new(carrier, "malformed response: #{raw.keys.inspect}") unless cents.is_a?(Integer) && days.is_a?(Integer)
  Quote.new(carrier, cents, days)
rescue => e
  Unavailable.new(carrier, "adapter caught: #{e.class}")
end

# The core: reads like the business rule it is. No nils survive to here.
def choose_rate(quotes)
  available = quotes.select(&:available?)
  return {choice: Quote.new("FlatRate fallback", 1200, 7), degraded: quotes, fallback: true} if available.empty?
  {choice: available.min_by(&:cents), degraded: quotes.reject(&:available?), fallback: false}
end

def fetch_quotes(carriers)
  orchestrator = Agentic::PlanOrchestrator.new(concurrency_limit: 3)
  tasks = carriers.to_h do |name, api|
    task = Agentic::Task.new(description: name, agent_spec: {"name" => name, "instructions" => "quote"})
    orchestrator.add_task(task, agent: ->(_t) { quote_from(name, api) })
    [name, task]
  end
  result = orchestrator.execute_plan
  tasks.values.map { |t| result.task_result(t.id).output }
end

puts "CARRIER QUOTES (confidence is suspicion, spent once, at the door)"
puts

quotes = fetch_quotes(CARRIERS)
verdict = choose_rate(quotes)
puts "  an ordinary afternoon (one slow, one down, one confused):"
quotes.each { |q| puts "    #{q}" }
puts "    -> checkout shows: #{verdict[:choice]} (#{verdict[:degraded].size} carriers degraded, sale not lost)"
puts

apocalypse = fetch_quotes(CARRIERS.transform_values { -> { sleep(0.2) } })
end_times = choose_rate(apocalypse)
puts "  the apocalypse (every carrier asleep):"
puts "    -> checkout shows: #{end_times[:choice]} (fallback: #{end_times[:fallback]} - the store stays OPEN)"
puts

failures = []
failures << "wrong quote chosen" unless verdict[:choice].carrier == "TurtleShip" && verdict[:choice].cents == 899
failures << "degradation reasons lost" unless verdict[:degraded].map(&:reason).join.match?(/no answer/) && verdict[:degraded].map(&:reason).join.match?(/malformed/)
failures << "apocalypse broke checkout" unless end_times[:fallback] && end_times[:choice].cents == 1200
failures << "a nil escaped the boundary" if quotes.any?(&:nil?) || apocalypse.any?(&:nil?)

puts "  the architecture in one sentence: quote_from is the only method"
puts "  allowed to be afraid. it converts every real-world outcome -"
puts "  timeout, schema drift, exception - into an object with the same"
puts "  FACE (available?, cents, to_s), so choose_rate reads like the"
puts "  business rule it is: pick the cheapest available, fall back to"
puts "  flat rate, never lose the sale. the degraded carriers keep their"
puts "  REASONS (ops will want them), the fan-out means the slow carrier"
puts "  never delays the fast one, and nil - the billion-dollar"
puts "  non-answer - is stopped at the door like it should be. timid"
puts "  code checks everything everywhere; confident code has a"
puts "  doorman."
exit(failures.empty? ? 0 : 1)
