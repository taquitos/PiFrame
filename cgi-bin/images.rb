#!/usr/bin/env ruby

require "json"

# Would like to use Dir.children which excludes '.' and '..', but that's only Ruby >= 2.5
# Do natural sort with files that have numbers or not
sync_dir = File.expand_path("../img/sync", __dir__)

entries =
  if Dir.exist?(sync_dir)
    Dir.entries(sync_dir)
       .select { |filename| filename != "." && filename != ".." }
       .select do |filename|
         path = File.join(sync_dir, filename)
         File.file?(path) && filename.match?(/\.(jpe?g|png|gif|webp|bmp)\z/i)
       end
       .sort_by { |name| [name[/\d+/].to_i, name.downcase] }
  else
    []
  end

puts "Content-Type: application/json"
puts
puts JSON.generate(entries)
