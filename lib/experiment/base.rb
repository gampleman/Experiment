require File.dirname(__FILE__) + "/notify"
require "./config/config"
require 'benchmark'

#if RUBY_VERSION > "1.9"
#  require 'csv'
#else
  require 'fastercsv'
#end

module Experiment
  class Base
    attr_reader :dir, :current_cv, :cvs, :options
    
  	def initialize(experiment, env, out = true)
  		@experiment = experiment
  		
  		Experiment::Config::load(experiment, env)
  		require "./experiments/#{experiment}/#{experiment}"
  		@abm = []
  	end
    
    # runs the whole experiment
  	def run!(cv, options)
  		@cvs = cv || 1
      @options = options
      @results = []
  		Notify.print "Running #{@experiment} "

  		write_dir!
  		specification!

  		@cvs.times do |cv_num|
  			@bm = []
  			@current_cv = cv_num
  			File.open(@dir + "/raw-#{cv_num}.txt", "w") do |output|
  			    run_the_experiment(output)
  			end
  			@results << analyze_result!(@dir + "/raw-#{cv_num}.txt", @dir + "/analyzed-#{cv_num}.txt").merge({:cv => cv_num})
  			write_performance!
  			Notify.print "."
  		end
  		summarize_performance!
  		summarize_results! @results
  		Notify.print result_line

  	end


    # Registers and performs a benchmark which is then 
    # calculated to the total and everage times
  	def benchmark(label = "", &block)
  	  @bm << Benchmark.measure("CV #{@current_cv} #{label}", &block)
  	end

  	
    # Creates the results directory for the current experiment
  	def write_dir!
  	  opts = @options.to_s
  		@dir = "./results/#{@experiment}-#{opts}-cv#{@cvs}-#{Time.now.to_i.to_s[4..9]}"
  		Dir.mkdir @dir
  	end
    
    # Writes a yaml specification of all the options used to run the experiment
  	def specification!
  		File.open(@dir + '/specification.yaml', 'w' ) do |out|
  			YAML.dump({:name => @experiment, :date => Time.now, :options => @options, :cross_validations => @cvs}, out )
  		end
  	end
    
    
    
    # Writes a file called 'performance_table.txt' which 
    # details all the benchmarks performed
  	def write_performance!
  		performance_f do |f|
  			f << "Cross Validation #{@current_cv} " + Benchmark::CAPTION 
  			f << @bm.map {|m| m.format("%19n "+Benchmark::FMTSTR)}.join
  			total = @bm.reduce(0) {|t, m| m + t}
  			f << total.format("         Total: "+Benchmark::FMTSTR)
  			@abm << total
  		end
  	end
    
    # Calculates the average performance and writes it
  	def summarize_performance!
  		performance_f do |f|
  			total = @abm.reduce(0) {|t, m| m + t} / @abm.count
  			f << total.format("       Average: "+Benchmark::FMTSTR)
  		end
  	end
    
    # creates a summary of the results and writes to 'all.csv'
  	def summarize_results!(results)
  	  
  	  results = results.reduce({}) do |tot, res|
  	   cv = res.delete :cv
  	   tot.merge Hash[res.to_a.map {|a| ["cv_#{cv}_#{a.first}".to_sym, a.last]}]
  	  end
  	  FasterCSV.open("./results/all.csv", "a") do |csv|
  	    csv << results.to_a.sort_by{|a| a.first.to_s}.map(&:last)
  	  end
  	end
  	
  	def result_line
  	 "Done\n"
  	end
  	
  	private
  	# Yields a handle to the performance table
  	def performance_f(&block) # just a simple wrapper to make code a little DRYer
  		File.open(@dir+"/performance_table.txt", "a", &block) 
  	end
  end
end