require 'rubygems'
require 'httpclient'
require 'uri'
require 'nokogiri'
require 'date'
require 'yaml'
require_relative 'kilometrikisa'
require_relative 'endomondo'

# monkeypatch Hash to support hmap, which returns a Hash instead of an Array
# sauce: http://chrisholtz.com/blog/lets-make-a-ruby-hash-map-method-that-returns-a-hash-instead-of-an-array/
class Hash
  def hmap(&block)
    Hash[self.map {|k, v| block.call(k,v) }]
  end
end


Workout = Struct.new(:date, :length)
$stdout.sync = true
CONFIG = YAML.load_file('config.yaml')
start_date = Date.parse(CONFIG['kilometrikisa-start-date'])

workouts = []
if (CONFIG['endomondo-user-token'])
  print "Fetching workouts from endomondo..."
  endomondo = Endomondo.new(CONFIG['endomondo-user-token'])
  workouts.concat(endomondo.get_recent_workouts())
  puts " done."
end

total_lengths_by_date = workouts.select {|wo|
  wo.date >= start_date
}.group_by {|wo|
  wo.date
}.hmap {|date, workouts|
  [date, Workout.new(
    date,
    workouts.inject(0.0) {|sum, wo| sum + wo.length}
  )]
}.hmap {|date, workout|
  [date, workout.length.round(2)]
}

workout_dates = total_lengths_by_date.keys
min_date, max_date = workout_dates.min, workout_dates.max

print "Fetching workouts from kilometrikisa..."
kilometrikisa = Kilometrikisa.new(CONFIG['kilometrikisa-user'], CONFIG['kilometrikisa-password'], CONFIG['kilometrikisa-contest-id'])
written_workouts_by_date = kilometrikisa.get_entries_between(min_date, max_date)
puts " done"

workouts_to_update = written_workouts_by_date.select {|wwo|
  len = total_lengths_by_date[wwo.date]
  len && (len > wwo.length)
}.map{|wo| Workout.new(wo.date, total_lengths_by_date[wo.date])}

if workouts_to_update.length > 0
  puts "Workouts that need to be written to kilometrikisa:"
  workouts_to_update.each {|wo|
    puts "-- %s: %f kilometers" % [wo.date.strftime('%d.%m.%Y'), wo.length]
  }


  successes, failures = workouts_to_update.partition{|wo|
    kilometrikisa.save_workout(wo)
  }
  puts "Successfully updated %d entries, failed to update %d entries!" % [successes.length, failures.length]
else
  puts "All found entries up to date"
end
