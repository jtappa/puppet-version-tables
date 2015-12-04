#!/usr/bin/env ruby

require 'git'
require 'pathname'
require 'json'
require 'pp'

project_dir = Pathname.new(File.expand_path(__FILE__)).parent
vanagon_dir = (project_dir + 'puppet-client-tools-vanagon')

if !Dir.exist?(vanagon_dir + '.git')
  Git.clone('git@github.com:puppetlabs/puppet-client-tools-vanagon.git', vanagon_dir)
end

client_repo = Git.open(vanagon_dir)
client_repo.fetch

component_files = {
  'Razor Client' => 'rubygem-pe-razor-client.rb',
  'Deployer Client' => 'puppet-xnode.json',
  'Puppet Access' => 'puppet-access.json',

  'Curl' => 'curl.rb',
  'LibSSH' => 'libssh.rb'
}

def version_from_json(file)
  # We want the last component of a string like refs/tags/4.2.0.
  JSON.load(File.read(file))['ref'].split('/')[-1]
end

def version_from_ruby(file)
  ruby_text = File.read(file)
  # find 'pkg.version "version"' and capture the version.
  ruby_text.match(/^\s*pkg\.version[\s\(]*['"]([^'"]+)['"]/)[1]
end

tags = client_repo.tags
# Structure of the repo didn't stabilize until 0.9.0-ish, so:
until tags.first.name == '1.0.0'
  tags.shift
end


client_versions_hash = tags.reduce(Hash.new) {|result, tag|
  client_repo.checkout(tag)
  components_hash = component_files.reduce(Hash.new) {|result, (component, config)|
    component_file = vanagon_dir + 'configs/components' + config
    if component_file.extname == '.json'
      result[component] = version_from_json(component_file)
    elsif component_file.extname == '.rb'
      result[component] = version_from_ruby(component_file)
    else
      raise("Unexpected file extension for #{component_file}")
    end
    result
  }
  result[tag.name] = components_hash
  result
}

puts JSON.dump(client_versions_hash)
