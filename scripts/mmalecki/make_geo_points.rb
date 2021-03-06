#!/usr/bin/env ruby

require 'rubygems'
require 'mongo'
require 'colorize'
require 'parallel'
require 'ruby-progressbar'

if ARGV.size != 2
  puts "USAGE: ruby #{$0} db collection".red
  exit(1)
else
  db = ARGV[0].to_s
  collection = ARGV[1].to_s
end

puts "db: #{db}, collection: #{collection}".green

include Mongo
cli = MongoClient.new.db(db).collection(collection);

all_docs = cli.find({"loc" => { "$exists" => false}})
count_all = all_docs.count

part_size = 10000

puts "Records to update: #{count_all.to_s.yellow}"
puts "Updating parallel in parts (each part has " \
     "#{part_size.to_s.yellow} docs)"

progress = ProgressBar.create(title: "Updating docs", total: count_all)

all_docs.each_slice(part_size) do |part|
  Parallel.each(part,
                in_processes: 2, # 1 master + 2 child / 4 in system
                finish: lambda { |item, i| progress.increment}) do |doc|

    cli.update({"_id" => doc["_id"]},
               {"$set" =>
                 {"loc" =>
                   {"type" => "Point", "coordinates" => [
                                         doc["PRIM_LAT_DEC"],
                                         doc["PRIM_LONG_DEC"]
                                       ]
                   }
                 }
               })
  end
end
# Removing lat/lng fields
#cli.update({},
#           {"$unset" => {"PRIM_LAT_DEC" => 1,
#                         "PRIM_LONG_DEC" => 1}})
