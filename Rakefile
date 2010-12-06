require 'rubygems'
gem 'hoe', '>= 2.1.0'
require 'hoe'
require 'fileutils'
require './lib/experiment'

Hoe.plugin :newgem
# Hoe.plugin :website
# Hoe.plugin :cucumberfeatures

# Generate all the Rake tasks
# Run 'rake -T' to see list of generated tasks (from gem root directory)
$hoe = Hoe.spec 'experiment' do
  self.developer 'Jakub Hampl', 'honitom@seznam.cz'
  #self.post_install_message = 'PostInstall.txt' # TODO remove if post-install message not required
  self.rubyforge_name       = self.name # TODO this is default value
  #self.extra_deps         = [['ruby-growl','>= 1.0']]
  self.summary = "A framework for running Scientific experiments."
  self.description = "It provides basic command line tools for simply defining things like cross validations, factorial experimental design and basic statistics. All of this can be run in a distributed manner."
  #self.homepage = 'https://github.com/gampleman/Experiment'
end

require 'newgem/tasks'
Dir['tasks/**/*.rake'].each { |t| load t }

# TODO - want other tests/tasks run by default? Add them to the list
# remove_task :default
# task :default => [:spec, :features]
