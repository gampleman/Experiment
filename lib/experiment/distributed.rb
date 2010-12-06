module Experiment
# this module is included in Experiment::Base
# It incorporates most of the logic required for distributed
# computing support.
# @see https://github.com/gampleman/Experiment/wiki/Distributed-Mode
# @private
module Distributed
  
  
  # @group Called on slave
  
  # master server DRb object
  attr_accessor :master
  
  # Main function. Will continously request work from the server,
  # execute it and send back results, then loops to the beggining.
  def slave_run!
    while work = @master.get_work
      puts work.inspect
      Experiment::Config.set work[:options]
      @current_cv = work[:cv]

      @dir = work[:dir]
      #@data = work[:input]
      File.open(@dir + "/raw-#{@current_cv}.txt", "w") do |output|
			  @ouptut_file = output
			  run_the_experiment
			end
			result = analyze_result!(@dir + "/raw-#{@current_cv}.txt", @dir + "/analyzed-#{@current_cv}.txt")
			write_performance!
			@master.submit_result @current_cv, result, @abm.first
    end

  end
  
  
  # @endgroup
  
  # @group Called on master
  
  # Send work from the master server
  # @return [Hash, false] either a spec what work to carry out or false 
  #   when no work available
  def get_work()
	  if cv = @started.index(false)
	    @started[cv] = true
	    {:cv => cv, :input => @data[cv], :dir => @dir, :options => Experiment::Config.to_hash }
	  else
	    false
    end
  end
  
  # returns true if all work has been disseminated
  def distribution_done?
    @started.all?
  end
  
  # Sends the result of the computation back to the master server.
  # Called on the master server object.
  def submit_result(cv, result, performance)
    @completed[cv] = true
    array_merge(@results, result)
    @abm << performance
    Notify.cv_done @experiment, cv
    master_done! if @completed.all?
  end
  
  
  
  # Strats up the master server
  def master_run!(cv)
    
    @cvs = cv || 1
    @results = {}
		Notify.started @experiment
    split_up_data
		write_dir!
		@completed = (1..@cvs).map {|a| false }
		@started = @completed.dup
  end
  
  # Cleans up the master server after all work is done
  def master_done!
    @done = true
    specification! true
    summarize_performance!
		summarize_results! @results
		cleanup!
		Notify.completed @experiment
		
		#sleep 1
    #DRb.stop_service
  end
  
  # @endgroup
  
end
end