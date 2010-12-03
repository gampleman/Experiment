require "CSV"
require File.dirname(__FILE__) + "/params"

module Experiment
  class Parametrized < Base
    
    def initialize(*args)
      super(*args)
      @params ||= {}
    end
    
    # runs the whole experiment
  	def normal_run!(cv)
  		@cvs = cv || 1
      @results = {}
      puts "Running #{@experiment} with #{param_grid.length} experiments at #{cv} cross validations each..."
  		#experiments = Notify.total / cv
  		#Notify.total = (experiments - 1) * cv + cv * param_grid.length
  		#
      Notify::init param_grid.length * @options.cv, STDOUT, Experiment::Config::get(:growl_notifications, false)
      split_up_data
  		write_dir!
      param_grid.each do |paramset|
        Params.set paramset
        results = {}
        Notify.started @experiment + ' ' + param_string(paramset, ", ")
        @cvs.times do |cv_num|
    			@bm = []
    			@current_cv = cv_num
    			File.open(@dir + "/raw-#{param_string(paramset)}-#{cv_num}.txt", "w") do |output|
    			  @ouptut_file = output
    			    run_the_experiment(@data[cv_num], output)
    			end
    			array_merge results, analyze_result!(@dir + "/raw-#{param_string(paramset)}-#{cv_num}.txt", @dir + "/analyzed-#{param_string(paramset)}-#{cv_num}.txt")
    			write_performance!

    			Notify.cv_done @experiment + ' ' + param_string(paramset, ", "), cv_num
    			#Notify.inc step
    			
    		end
    		#print '.'
    		Notify.completed @experiment + ' ' + param_string(paramset, ", ")
    		
    		@results[paramset] = results
      end
  		Notify::done
  		specification!
  		summarize_performance!
  		summarize_results! @results
  		cleanup!
  		
  		puts File.read(@dir + "/summary.mmd") if @options.summary
  	end
  	
  	# Specify a parameter that will be used as a factor in the experiment
  	# @example
  	#   param :decay_rate, [0.1, 0.3, 0.7]
  	#   param :photons, [5, 10]
  	#   # runs these 6 experiments:
  	#   # | decay_rate | photons
  	#   # |        0.1 |   5
  	#   # |        0.1 |  10
  	#   # |        0.3 |   5
  	#   # |        0.3 |  10
  	#   # |        0.7 |   5
  	#   # |        0.7 |  10
  	# @example Contrived example of block usage
  	#   param :user_iq do
  	#     mean = gets "How much is 1 + 1?"
  	#     if mean == '2'
  	#       (100..160).to_a
  	#     else
  	#       (20..30).to_a
  	#     end
  	#   end
  	# @see Params
  	def self.param(name, value = nil, &block)
  	  @@params ||= {}
  	  if block_given?
  	    @@params[name] = block.call
	    else
	      @@params[name] = value
      end
	  end
	  
	  protected
	  
	  def param_grid
	    keys, vals = @@params.keys, @@params.values
	    start = vals.shift
	    @@params = {}
	    @grid ||= start.product(*vals).map do |ar|
	      Hash[*keys.zip(ar).flatten]
      end
	  end
	  
	  
	  # creates a summary of the results and writes to 'all.csv'
  	def summarize_results!(all_results)
  	  summaries = {}
  	  all_results.each do |paramset, results|
  	    File.open(@dir + "/results-#{param_string(paramset)}.yaml", 'w' ) do |out|
    			YAML.dump(results, out)
    		end
    		summaries[paramset] = {}
    		# create an array of arrays
    		res = results.keys.map do |key| 
    		  # calculate stats
    		  a = results[key]
    		  if a.all? {|el| el.is_a? Numeric }
    		    summaries[paramset]["#{key} mean"] = Stats::mean(a)
    		    summaries[paramset]["#{key} SD"] = Stats::standard_deviation(a)
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
    		File.open(@dir + "/#{paramset}-summary.mmd", 'w') do |f|
    		  f << "## Results for #{@experiment} with parametres #{param_string(paramset, ", ")} ##\n\n"
    		  f << out
  		  end
		  end
		  
		  # Build CSV file with all of the results
		  #puts summaries.inspect
		  
		  summaries = summaries.to_a
      #puts summaries.inspect
		  keys1 = summaries.first.first.keys
		  keys2 = summaries.first.last.keys
		  #puts keys1.inspect, keys2.inspect, "====="
      CSV.open(@dir + "/results.csv", "w") do |csv|
  	    csv << keys1 + keys2
  	    summaries.each do |summary|
  	      #puts summary.first.inspect
  	      #puts summary.first.values_at(*keys1).inspect + summary.last.values_at(*keys2).inspect
  	      csv << summary.first.values_at(*keys1) + summary.last.values_at(*keys2)
  	      
  	    end
  	  end
		  
	  end
	  
	  # Writes a yaml specification of all the options used to run the experiment
  	def specification!
  		File.open(@dir + '/specification.yaml', 'w' ) do |out|
  			YAML.dump({:name => @experiment, :date => Time.now, :configuration => Experiment::Config.to_h, :cross_validations => @cvs, :params => @@params}, out )
  		end
  	end
	  
    
    def param_string(par, split = ",")
      out = []
      par.each do |k,v|
        out << "#{k}=#{v}"
      end
      out.join split
    end
  end
end
