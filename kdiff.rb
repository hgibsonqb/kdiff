#!/usr/bin/env ruby

require 'optparse'
require 'tmpdir'

def kdiff(old, new)
  %x( zsh -c 'colordiff -u <(kustomize build #{old}) <(kustomize build #{new})' )
end

def kdiffs(old, new)
  clusters = Dir.children("#{old}/cluster") | Dir.children("#{new}/cluster")
  clusters.collect do |cluster|
    [cluster, kdiff("#{old}/cluster/#{cluster}", "#{new}/cluster/#{cluster}")]
  end.to_h.delete_if { |k, v| v.empty? }
end

options = {}
optparser = OptionParser.new do |parser|
  parser.banner = <<~EOD
    usage: kdiff.rb [branch] [branch]
    compare the output of `kustomize build` between git branches

    defaults to `kdiff.rb main`

    options:
  EOD
  parser.on("-h", "--help", "prints this message") do
    puts parser
    exit
  end
  parser.on("-s", "--summary", "only print names of clusters with changes") do
    options[:summary] = true
  end
end
optparser.parse!
unless ARGV.length.between?(0, 2)
  puts optparser
  exit
end

oldbranch = ARGV.any? ? ARGV.shift : "main"
newbranch = ARGV.shift

diffs = Dir.mktmpdir do |old|
  repo = %x( git rev-parse --show-toplevel ).chomp
  %x( git clone -q -b #{oldbranch} #{repo} #{old} )
  if newbranch.nil?
    kdiffs(old, repo)
  else
    Dir.mktmpdir do |new|
      %x( git clone -q -b #{newbranch} #{repo} #{new} )
      kdiffs(old, new)
    end
  end
end

if diffs.empty?
  puts "No changes detected."
  exit
end

output = if options[:summary]
  diffs.keys.sort
else
  diffs.sort.each
end.to_a.join("\n")
puts output
