$:.unshift(File.dirname(__FILE__)) unless
  $:.include?(File.dirname(__FILE__)) || $:.include?(File.expand_path(File.dirname(__FILE__)))


# This module is the top level namespace for the whole project.
# 
# You may be interested especially in {Base}, {Config}, 
# {Factorial} and {Params} (as these form the public api).
#
# @author Jakub Hampl
# @see https://github.com/gampleman/Experiment/wiki/_pages
module Experiment
  VERSION = '0.3.3'
end