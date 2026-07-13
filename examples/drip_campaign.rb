# frozen_string_literal: true

# The Drip Campaign: every product ships one - welcome on day 0,
# tips on day 3, the gentle upsell on day 7 - and every team ships
# the same three bugs with it: the DOUBLE SEND (cron fired twice;
# your users got two welcomes and one impression: amateurs), the
# GHOST MAIL (user unsubscribed on Tuesday, your Thursday job
# mailed them anyway, now it's a compliance ticket), and the
# COHORT SMEAR (users who signed up Wednesday get Monday's
# schedule). The cures are boring and absolute: an idempotency
# ledger keyed by (user, step), unsubscribes checked AT SEND TIME
# - the last possible moment - and every offset computed from the
# user's OWN signup day. Time here is simulated; the bugs are not.
#
#   bundle exec ruby examples/drip_campaign.rb
#
# Runs offline; exits 1 unless the outbox is exactly right after a
# week that includes a double-fired cron and two unsubscribes.

require "bundler/setup"
require "agentic"
require "set"

Agentic.logger.level = :fatal

CAMPAIGN = [
  {step: "welcome", day_offset: 0},
  {step: "tips", day_offset: 3},
  {step: "upsell", day_offset: 7}
].freeze

USERS = {
  "ana" => {signed_up: 0},   # the loyal one: gets all three
  "bo" => {signed_up: 0},    # unsubscribes day 2: welcome only
  "cy" => {signed_up: 1},    # signs up a day late: schedule shifts with them
  "di" => {signed_up: 0}     # unsubscribes ON day 3, before the tick: no tips
}.freeze

OUTBOX = []
SENT = Set.new       # the idempotency ledger: (user, step), forever
UNSUBSCRIBED = {}    # user => day it happened

# One scheduler tick: compute due sends, deliver them as a plan
def tick(day)
  due = USERS.flat_map { |user, info|
    CAMPAIGN.select { |step| info[:signed_up] + step[:day_offset] == day }.map { |step| [user, step] }
  }
  return if due.empty?
  orchestrator = Agentic::PlanOrchestrator.new(concurrency_limit: 4)
  due.each do |user, step|
    task = Agentic::Task.new(description: "#{step[:step]} -> #{user}", agent_spec: {"name" => "mailer", "instructions" => "send"})
    orchestrator.add_task(task, agent: ->(_t) {
      key = [user, step[:step]]
      next :duplicate_suppressed if SENT.include?(key)         # cure one: the ledger
      next :unsubscribed if UNSUBSCRIBED.key?(user)            # cure two: checked at SEND time
      SENT << key
      OUTBOX << {day: day, to: user, mail: step[:step]}
      :sent
    })
  end
  orchestrator.execute_plan
end

puts "THE DRIP CAMPAIGN (three emails, three classic bugs, three boring cures)"
puts

8.times do |day|
  UNSUBSCRIBED["bo"] = day if day == 2
  UNSUBSCRIBED["di"] = day if day == 3 # unsubscribes the morning of their tips day
  tick(day)
  tick(day) if day == 3 # the cron fires twice on day 3. it always eventually does.
end

puts "  the week's outbox (cron double-fired on day 3; bo and di unsubscribed):"
OUTBOX.each { |m| puts format("    day %d  %-8s -> %s", m[:day], m[:mail], m[:to]) }
puts

by_user = OUTBOX.group_by { |m| m[:to] }.transform_values { |ms| ms.map { |m| m[:mail] } }
failures = []
failures << "ana should get the full sequence" unless by_user["ana"] == ["welcome", "tips", "upsell"]
failures << "bo was mailed after unsubscribing" unless by_user["bo"] == ["welcome"]
failures << "cy's schedule didn't shift with their signup" unless OUTBOX.select { |m| m[:to] == "cy" }.map { |m| m[:day] } == [1, 4]
failures << "di's send-time unsubscribe was ignored" unless by_user["di"] == ["welcome"]
failures << "the double-fired cron double-sent" unless OUTBOX.size == OUTBOX.uniq { |m| [m[:to], m[:mail]] }.size
failures << "outbox size wrong (#{OUTBOX.size})" unless OUTBOX.size == 7 # cy's upsell lands on day 8, beyond this week

puts "  the three cures, verified: the (user, step) LEDGER made the"
puts "  day-3 double-fire invisible (same tick ran twice; the outbox"
puts "  can't tell); unsubscribes were checked at SEND time, the last"
puts "  possible moment - di unsubscribed the morning of their tips day"
puts "  and got nothing, because a check at schedule time is a promise"
puts "  made too early; and cy's whole sequence shifted with their"
puts "  signup day (day 1 welcome, day 4 tips), because offsets belong"
puts "  to the user's clock, not the calendar's. none of this needed a"
puts "  marketing platform - it needed a ledger, a late check, and"
puts "  per-user arithmetic. the right thing should be the default"
puts "  thing; in this campaign, it's the only thing."
exit(failures.empty? ? 0 : 1)
