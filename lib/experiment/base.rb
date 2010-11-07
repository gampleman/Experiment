require File.dirname(__FILE__) + "/notify"
require File.dirname(__FILE__) + "/stats"
require File.dirname(__FILE__) + "/config"
require File.dirname(__FILE__) + "/distributed"
require 'benchmark'
require "drb/drb"

module Experiment
  class Base
    
    include Distributed
    
    attr_reader :dir, :current_cv, :cvs

  	def initialize(mode, experiment, options, env)
  		@experiment = experiment
  		case mode
  		  
  		when :normal
  		  @abm = [] 
		  when :master
		    @abm = []
		    extend DRb::DRbUndumped
		    @done = false
	    when :slave
		    
  		end
  		Experiment::Config::load(experiment, options, env)
  		@mode = mode
  	end
  	
  	def done?
  	  @done
	  end
  	
  	
    
    # runs the whole experiment
  	def normal_run!(cv)
  		@cvs = cv || 1
      @results = {}
  		Notify.started @experiment
      split_up_data
  		write_dir!
  		specification!

  		@cvs.times do |cv_num|
  			@bm = []
  			@current_cv = cv_num
  			File.open(@dir + "/raw-#{cv_num}.txt", "w") do |output|
  			  @ouptut_file = output
  			    run_the_experiment(@data[cv_num], output)
  			end
  			array_merge @results, analyze_result!(@dir + "/raw-#{cv_num}.txt", @dir + "/analyzed-#{cv_num}.txt")
  			write_performance!
  			Notify.cv_done @experiment, cv_num
  		end
  		summarize_performance!
  		summarize_results! @results
  		Notify.completed @experiment
  	end
    
    
    # use this evry time you want to do a measurement.
    # It will be put on the record file and benchmarked
    # automatically
    # The weight parameter is used for calculating 
    # Notify::step. It should be an integer denoting how many 
    # such measurements you wish to do.
    def measure(label = "", weight = nil, &block)
      out = ""
      benchmark label do
        out = yield
      end
      @ouptut_file << out
      Notify::step(@experiment, @current_cv, 1.0/weight) unless weight.nil?
    end
    
    
    # Registers and performs a benchmark which is then 
    # calculated to the total and everage times
  	def benchmark(label = "", &block)
  	  @bm ||= []
  	  @bm << Benchmark.measure("CV #{@current_cv} #{label}", &block)
  	end

  	
    # Creates the results directory for the current experiment
  	def write_dir!
  		@dir = "./results/#{@experiment}-cv#{@cvs}-#{Time.now.to_i.to_s[4..9]}"
  		Dir.mkdir @dir
  	end
    
    # Writes a yaml specification of all the options used to run the experiment
  	def specification!
  		File.open(@dir + '/specification.yaml', 'w' ) do |out|
  			YAML.dump({:name => @experiment, :date => Time.now, :configuration => Experiment::Config.to_h, :cross_validations => @cvs}, out )
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
  			@abm ||= []
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
  	  File.open(@dir + '/results.yaml', 'w' ) do |out|
  			YAML.dump(results, out)
  		end
  		
  		# create an array of arrays
  		res = results.keys.map do |key| 
  		  # calculate stats
  		  a = results[key]
  		  [key] + a + [Stats::mean(a), Stats::standard_deviation(a)]
		  end
		  
		  ls = results.keys.map{|v| v.to_s.length }
  		
  		ls = ["Standard Deviation".length] + ls
  		res = [["cv"] + (1..cvs).to_a.map(&:to_s) + ["Mean", "Standard Deviation"]] + res
  		out = ""
  		res.transpose.each do |col|
  		  col.each_with_index do |cell, i|
  		    l = ls[i]
  		    out << "| "
  		    if cell.is_a?(String) || cell.is_a?(Symbol)
  		      out << sprintf("%#{l}s", cell)
		      else
		        out << sprintf("%#{l}.3f", cell)
		      end
		      out << " "
  		  end
  		  out << "|\n"
  		end
  		File.open(@dir + "/summary.mmd", 'w') do |f|
  		  f << "## Results for #{@experiment} ##\n\n"
  		  f << out
		  end
  	  #results = results.reduce({}) do |tot, res|
  	  # cv = res.delete :cv
  	  # tot.merge Hash[res.to_a.map {|a| ["cv_#{cv}_#{a.first}".to_sym, a.last]}]
  	  #end
  	  #FasterCSV.open("./results/all.csv", "a") do |csv|
  	  #  csv << results.to_a.sort_by{|a| a.first.to_s}.map(&:last)
  	  #end
  	end
  	
  	def result_line
  	 " Done\n"
  	end
  	
  	# A silly method meant to be overriden.
  	# should return an array, which will be then split up for cross-validating
  	def test_data
  	  (1..cvs).to_a
  	end
  	
  	def split_up_data
  	  @data = []
  	  test_data.each_with_index do |item, i|
  	    @data[i % cvs] ||= []
  	    @data[i % cvs] << item
  	  end
  	  @data
  	end
  	
  	private
  	# Yields a handle to the performance table
  	def performance_f(&block) # just a simple wrapper to make code a little DRYer
  		File.open(@dir+"/performance_table.txt", "a", &block) 
  	end
  	
  	def array_merge(h1, h2)
  	  h2.each do |key, value|
  	   h1[key] ||= []
  	   h1[key] << value
  	  end
	  end
  end
end