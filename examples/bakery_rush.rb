# frozen_string_literal: true

# The Bakery Rush: two ovens, thirteen orders, one queue - and the
# morning is decided before the first tray goes in, by ENQUEUE
# ORDER. A bakery is a queue wearing an apron: the plan is the
# queue, the concurrency limit is the ovens, and the discipline
# (who bakes first) is policy you choose, not fate. We run the same
# morning twice - first-come-first-served with the wedding cake up
# front, then shortest-bake-first - and measure customer sadness.
# Queue theory has opinions about croissants. They are correct.
#
#   bundle exec ruby examples/bakery_rush.rb
#
# Runs offline; exits 1 unless the discipline change rescues every
# croissant customer without making the cake late.

require "bundler/setup"
require "agentic"

Agentic.logger.level = :fatal

def mono = Process.clock_gettime(Process::CLOCK_MONOTONIC)

# The 6am board: everyone "arrived" at open; patience varies wildly
ORDERS = [
  {item: "wedding cake", bake: 0.20, patience: 1.00},  # due at noon; the baker's pride
  {item: "birthday cake", bake: 0.18, patience: 1.00}, # due at three; has sprinkles
  *6.times.map { |i| {item: "croissant ##{i + 1}", bake: 0.02, patience: 0.15} },
  *3.times.map { |i| {item: "baguette ##{i + 1}", bake: 0.04, patience: 0.30} },
  *2.times.map { |i| {item: "eclair ##{i + 1}", bake: 0.03, patience: 0.30} }
].freeze

def open_the_doors(orders_in_queue_order)
  orchestrator = Agentic::PlanOrchestrator.new(concurrency_limit: 2) # two ovens, no negotiating
  opened = mono
  tickets = {}
  orders_in_queue_order.each do |order|
    task = Agentic::Task.new(description: order[:item], agent_spec: {"name" => order[:item], "instructions" => "bake"})
    orchestrator.add_task(task, agent: ->(_t) {
      waited = mono - opened
      sleep(order[:bake]) # the oven does not care about your feelings
      tickets[order[:item]] = {waited: waited, done: mono - opened, patience: order[:patience]}
      :golden_brown
    })
  end
  orchestrator.execute_plan
  tickets
end

def morning_report(label, tickets)
  lost = tickets.select { |_, t| t[:waited] > t[:patience] }
  cakes = tickets.select { |item, _| item.include?("cake") }.values
  mean_wait = tickets.values.sum { |t| t[:waited] } / tickets.size
  puts "  #{label}:"
  puts "    mean wait #{(mean_wait * 1000).round}ms; customers lost to the cafe next door: #{lost.size}"
  lost.each { |item, t| puts "      walked out: #{item} (waited #{(t[:waited] * 1000).round}ms, patience #{(t[:patience] * 1000).round}ms)" }
  cakes_ok = cakes.all? { |c| c[:done] <= c[:patience] }
  puts "    cakes: done at #{cakes.map { |c| "#{(c[:done] * 1000).round}ms" }.join(" and ")} #{cakes_ok ? "- both on time" : "- LATE, catastrophe"}"
  [mean_wait, lost.size, cakes_ok]
end

puts "THE BAKERY RUSH (a bakery is a queue wearing an apron)"
puts

fifo = open_the_doors(ORDERS) # cake first: it was ordered first, seems fair
fifo_mean, fifo_lost, fifo_cake_ok = morning_report("monday, first-come-first-served (two cakes hog BOTH ovens at 6am)", fifo)
puts

sjf = open_the_doors(ORDERS.sort_by { |o| o[:bake] }) # shortest bake first; cake waits, but its deadline is NOON
sjf_mean, sjf_lost, sjf_cake_ok = morning_report("tuesday, shortest-bake-first (same ovens, same orders, new discipline)", sjf)
puts

puts "  nothing about the bakery changed overnight - not the ovens, not"
puts "  the orders, not the bake times. only the DISCIPLINE: monday"
puts "  baked in arrival order and the wedding cake sat in an oven for"
puts "  200ms while croissant customers (patience: 150ms) studied the"
puts "  cafe across the street. tuesday baked shortest-first, because"
puts "  shortest-job-first provably minimizes mean wait - and the cake"
puts "  was never actually urgent: ordered first, due at NOON. arrival"
puts "  order and deadline order are different orders. every queue"
puts "  system rediscovers this; bakers knew it already. the queue is"
puts "  the product - choose its discipline like you chose the recipes."
exit((sjf_lost.zero? && fifo_lost.positive? && sjf_cake_ok && fifo_cake_ok && sjf_mean < fifo_mean) ? 0 : 1)
