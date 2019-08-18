#!/usr/bin/env ruby

# Would like to use Dir.children which excludes '.'' and '..', but that's only Ruby >= 2.5
# Do natural sort with files that have numbers or not
entries = Dir.entries("../img/sync")
             .select { |filename| filename != "." && filename != ".." }
             .sort_by { |name| [name[/\d+/].to_i, name] }
puts <<EOS
Content-type: application/json

#{entries}
                            
EOS
