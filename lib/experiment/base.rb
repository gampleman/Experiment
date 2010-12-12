require File.dirname(__FILE__) + "/notify"
require File.dirname(__FILE__) + "/stats/descriptive"
require File.dirname(__FILE__) + "/config"
require File.dirname(__FILE__) + "/params"
require File.dirname(__FILE__) + "/distributed/slave"
require File.dirname(__FILE__) + "/distributed/master"
require 'benchmark'
require "drb/drb"
require "yaml"

module Experiment
  # The base class for defining experimental conditons.
  # @author Jakub Hampl
  # @see https://github.com/gampleman/Experiment/wiki/Designing-your-experiment
  class Base
    
    @@cleanup_raw_files = false
    
    # The directory in which the results will be written to.  
    attr_reader :dir
    # The number of the current cross-validation
    attr_reader :current_cv
    # The number of overall cross-validations
    attr_reader :cvs
    # The file the program is currently set to output to.
    # Use this if you want to write additional data.
    attr_reader :output_file
    
    # Called internally by the framewrok
    # @private
    # @param [:normal, :master, :slave] mode
    # @param [String] experiment Name of the experimental condition.
    # @param [OpenStruct] options Most of the options passed from the CLI.
  	def initialize(mode, experiment, options)
  		@experiment = experiment
  		@options = options
  		# a bit of dependency injection here
  		case mode
  		when :normal
  		  @abm = [] 
		  when :master
		    @abm = []
		    extend DRb::DRbUndumped
		    extend Distributed::Master
		    @done = false
	    when :slave
		    extend Distributed::Slave
  		end
  		
  		Experiment::Config::load(experiment, options.opts, options.env)
  		@mode = mode
  	end
  	
  	# Is the experiment done.
  	def done?
  	  @done
	  end
  	
  	# The default analysis function
  	# Not terribly useful, better to override
  	# @abstract Override for your own method analysis.
  	# @param [String] input file path of results written by `measure` calls.
  	# @param [String] output file path where to optionally write detailed analysis.
  	# @return [Hash] Summary of analysis.
  	def analyze_result!(input, output)
      YAML::load_file(input)
    end
    
    # Sets up actions to do after the task is completed.
    #
    # This will be expanded in the future. Currently the only
    # possible usage is with :delete_raw_files
    # @example
    #   after_completion :delete_raw_files
    # @param [:delete_raw_files] args If called will delete the raw-*.txt files
    #   in the {dir} after the experiment successfully completes.
    def self.after_completion(*args)
      @@cleanup_raw_files = args.include? :delete_raw_files
    end
    
    # runs the whole experiment, called by the framework
    # @private
  	def run!(cv)
  		@cvs = cv || 1
      @results = {}
  		Notify.started @experiment
      split_up_data
  		write_dir!
  		@cvs.times do |cv_num|
  			@bm = []
  			@current_cv = cv_num
  			begin
  			  File.open(@dir + "/raw-#{cv_num}.txt", "w") do |output|
    			  @ouptut_file = output
    			    run_the_experiment
    			end
    		rescue Exception => e
    		  File.open(@dir + "/error.log", "a") do |f|
    		     f.puts e.message
    		     f.puts e.backtrace.join("\n")
  		    end
    		  raise e
  		  end
  			array_merge @results, analyze_result!(@dir + "/raw-#{cv_num}.txt", @dir + "/analyzed-#{cv_num}.txt")
  			write_performance!
  			Notify.cv_done @experiment, cv_num
  		end
  		summarize_performance!
  		summarize_results! @results
  		specification!
  		cleanup!
  		Notify.completed @experiment
  		puts File.read(@dir + "/summary.mmd") if @options.summary
  	end
    
    # Returns the portion of the {data_set} that corresponds 
    # to the current cross validation number.
    # @return [Array]
    def test_data
      @data[@current_cv]
    end
    
    # Returns the {data_set} that *without* the {test_data}.
    # @return [Array]
    def training_data
      (@data - test_data).flatten
    end
    
    # Use this every time you want to do a measurement.
    # It will be put on the record file and benchmarked
    # automatically.
    #
    # @param [Integer] weight Used for calculating 
    #   Notify::step. It should be an integer denoting how many 
    #   such measurements you wish to do.
    def measure(label = "", weight = nil, &block)
      out = ""
      benchmark label do
        out = yield
      end
      if out.is_a? String
        @ouptut_file << out
      else
        YAML::dump(out, @ouptut_file)
      end
      Notify::step(@experiment, @current_cv, 1.0/weight) unless weight.nil?
    end
    
    
    # Registers and performs a benchmark which is then 
    # calculated to the total and everage times.
    # 
    # A lower-level alternative to measure.
  	def benchmark(label = "", &block)
  	  @bm ||= []
  	  @bm << Benchmark.measure("CV #{@current_cv} #{label}", &block)
  	end

  	
    
    
    # creates a summary of the results and writes to 'summary.mmd'
  	def summarize_results!(results)
  	  File.open(@dir + '/results.yaml', 'w' ) do |out|
  			YAML.dump(results, out)
  		end
  		# create an array of arrays
  		res = results.keys.map do |key| 
  		  # calculate stats
  		  a = results[key]
  		  if a.all? {|el| el.is_a? Numeric }
  		    [key] + a + [Stats::mean(a), Stats::standard_deviation(a)]
		    else
		      [key] + a + ["--", "--"]
	      end
		  end
		  
		  ls = results.keys.map{|v| [7, v.to_s.length].max }
  		
  		ls = ["Std Deviation".length] + ls
  		res = header_column + res
  		res = res.transpose
  		out = build_table res, ls
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

  	
  	# A silly method meant to be overriden.
  	# should return an array, which will be then split up for cross-validating.
  	# @abstract Override this method to return an array.
  	def data_set
  	  (1..cvs).to_a
  	end
  	
  	protected
  	
  	# Creates the results directory for the current experiment
  	def write_dir!
  		@dir = "./results/#{@experiment}-cv#{@cvs}-#{Time.now.to_i.to_s[4..9]}"
  		Dir.mkdir @dir
  	end
    
    # Writes a yaml specification of all the options used to run the experiment
  	def specification! all = false
  		File.open(@dir + '/specification.yaml', 'w' ) do |out|
  			YAML.dump({:name => @experiment, :date => Time.now, :configuration => (all ? Experiment::Config.to_hash : Experiment::Config.to_h), :cross_validations => @cvs}, out )
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
  	
  	def build_table(table_data, ls)
  	  out = ""
  	  table_data.each_with_index do |col, row_num|
  		  col.each_with_index do |cell, i|
  		    l = ls[i]
  		    out << "| "
  		    if cell.is_a?(String) || cell.is_a?(Symbol)
  		      out << sprintf("%#{l}s", cell)
		      elsif cell.is_a? Numeric
		        out << sprintf("%#{l}.3f", cell)
	        else
	          out << sprintf("%#{l}s", cell.to_s)
		      end
		      out << " "
  		  end
  		  
  		  out << "|\n"
  		  
  		  if row_num == 0 || row_num == table_data.length - 3
  		    col.each_index do |i|
  		      out << "|" + "-" * (ls[i] + 2)
		      end
		      out << "|\n"
	      end	      
  		end # each_with_index
  		
  		return out
  	end
  	
  	
  	def split_up_data
  	  @data = []
  	  data_set.each_with_index do |item, i|
  	    @data[i % cvs] ||= []
  	    @data[i % cvs] << item
  	  end
  	  @data
  	end
  	
  	# Performs cleanup tasks
  	def cleanup!
  	  if @@cleanup_raw_files
  	    FileUtils.rm Dir[@dir + "/raw-*.txt"]
	    end
  	end
  	
  	
  	
  	def header_column
  	  [["cv"] + (1..cvs).to_a.map(&:to_s) + ["Mean", "Std Deviation"]]
  	end
  	
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