#!/usr/bin/env ruby
# ruby script to create a directory structure from indented data.
# Two ways to use it now:
# Pass it a path to a template file.
# p = planter.new
# p.plant(path/to/template.tpl)
#
# or just call it with a simple name and it will look in ~/.planter for a template that matches that name.
# You can put %%X%% variables into templates, where X is a number that corresponds to the index
# of the argument passed when planter is called.
# e.g. `planter.rb client "Mr. Butterfinger"` would replace %%1%% in client.tpl with "Mr. Butterfinger"
# Created by Brett Terpstra (https://gist.github.com/3767188) 
# Modified and turned into a class by Nate Dickson (https://gist.github.com/4277795)

require 'yaml'
require 'tmpdir'
require 'fileutils'
class Planter
  def get_hierarchy(input, parent=".", dirs_to_create=[])
    input.each do |dirs|
      if dirs.kind_of? Hash
        dirs.each do |k, v|
          dirs_to_create.push(File.expand_path("#{parent}/#{k.strip}"))
          dirs_to_create = get_hierarchy(v, "#{parent}/#{k.strip}", dirs_to_create)
        end
      elsif dirs.kind_of? Array
        dirs_to_create = get_hierarchy(dirs, parent, dirs_to_create)
      elsif dirs.kind_of? String
        dirs_to_create.push(File.expand_path("#{parent}/#{dirs.strip}"))
      end
    end
    return dirs_to_create
  end

  def text_to_yaml(input, replacements = [])
    lines       = input.split("\n")
    #output = []  #this doesn't seem to be used anywhere?
    prev_indent = 0
    lines.each_with_index do |line, i|
      if line =~ /%%(\d+)%%/
        if $1.to_i <= replacements.length
          line.gsub!(/%%#{$1}%%/, replacements[$1.to_i - 1])
        else
          $stderr.puts('Mismatch in number of template variables found and replacements provided')
          lines[i] = ''
          next
        end
      end
      indent = line.gsub(/  /, "\t").match(/(\t*).*$/)[1]
      if indent.length > prev_indent
        lines[i-1] = lines[i-1].chomp + ":"
      end
      prev_indent = indent.length
      lines[i]    = indent.gsub(/\t/, '  ') + "- " + lines[i].strip # unless indent.length == 0
    end
    lines.delete_if { |line|
      line == ''
    }
    return "---\n" + lines.join("\n")
  end

  def plant(incoming, *names)
    data = ""
    if File.exists? incoming
       template = incoming
    else
      template = File.expand_path("~/.planter/#{incoming.gsub(/\.tpl$/, '')}.tpl")
      ARGV.shift
    end
    if File.exists? template
      File.open(template, 'r') do |infile|
        data = infile.read
      end
    else
      STDERR.puts "Specified template not found in ~/.planter/*.tpl"
      exit 1
    end
    data.strip!
    
    yaml = YAML.load(text_to_yaml(data, names))
    dirs_to_create = get_hierarchy(yaml)

    dirs_to_create.each do |dir|
      $stderr.puts "Creating #{dir}"
      Dir.mkdir(dir) unless File.exists? dir
    end
  end #def plant
end #class Planter
