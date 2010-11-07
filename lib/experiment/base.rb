require File.dirname(__FILE__) + "/notify"
require File.dirname(__FILE__) + "/stats"
require File.dirname(__FILE__) + "/config"
require 'benchmark'
require "drb/drb"

module Experiment
  class Base
    attr_reader :dir, :current_cv, :cvs
    attr_accessor :master
  	def initialize(mode, experiment, options, env)
  		unless mode == :slave
  		  extend DRb::DRbUndumped
  		  @experiment = experiment
    		#require "./experiments/#{experiment}/#{experiment}"
    		@abm = []
  		end
  		@done = false
  		Experiment::Config::load(experiment, options, env)
  		@mode = mode
  	end
  	
  	def done?
  	  @done
	  end
  	
  	def get_work()
  	  if cv = @started.index(false)
  	    @started[cv] = true
  	    {:cv => cv, :input => @data[cv], :dir => @dir, :options => Experiment::Config.to_h }
  	  else
  	    false
	    end
	  end
	  
	  def submit_result(cv, result, performance)
	    @completed[cv] = true
	    array_merge(@results, result)
	    @abm << performance
      Notify.cv_done cv
	    master_done! if @completed.all?
	  end
    
    
    def slave_run!
      while work = @master.get_work
        puts work.inspect
        Experiment::Config.set work[:options]
        @current_cv = work[:cv]

        @dir = work[:dir]
        File.open(@dir + "/raw-#{@current_cv}.txt", "w") do |output|
  			  @ouptut_file = output
  			  run_the_experiment(work[:input], output)
  			end
  			result = analyze_result!(@dir + "/raw-#{@current_cv}.txt", @dir + "/analyzed-#{@current_cv}.txt")
  			write_performance!
  			@master.submit_result @current_cv, result, @abm
      end

    end
    
    
    def master_start!(cv)
      
      @cvs = cv || 1
      @results = {}
  		Notify.started @experiment
      split_up_data
  		write_dir!
  		specification!
  		@completed = (1..@cvs).map {|a| false }
  		@started = @completed.dup
    end
    
    def master_done!
      puts "master done called"
      @done = true
      summarize_performance!
  		summarize_results! @results
  		Notify.completed @experiment
  		
  		#sleep 1
      #DRb.stop_service
    end
    
    # runs the whole experiment
  	def run!(cv)
  		@cvs = cv || 1
      @results = {}
      if @mode == :master
  		  Notify.started @experiment
        split_up_data
    		write_dir!
    		specification!

    		@cvs.times do |cv_num|
    			@bm = []
    			@current_cv = cv_num
  			  
    			@slave.run_as_slave @current_cv, @dir, @cvs, @data[cv_num]
    			Notify.cv_done cv_num
    		end
    		summarize_performance!
    		summarize_results! @results
    		Notify.completed @experiment  		  
  		end
  	end
  	
  	
  	def run_as_slave(current_cv, dir, cvs, data)
  	  cv, @current_cv, @dir, @cvs = current_cv, current_cv, dir, cvs
  	  File.open(@dir + "/raw-#{cv}.txt", "w") do |output|
			  @ouptut_file = output
			  run_the_experiment(data, output)
			end
			result = analyze_result!(@dir + "/raw-#{@current_cv}.txt", @dir + "/analyzed-#{@current_cv}.txt")
			#write_performance!
			result
	  end
    
    
    # use this evry time you want to do a measurement.
    # It will be put on the record file and benchmarked
    # automatically
    def measure(label = "", &block)
      out = ""
      benchmark label do
        out = yield
      end
      @ouptut_file << out
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
  			@abm = total
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
  		puts res.inspect
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