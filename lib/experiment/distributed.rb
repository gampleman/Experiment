module Experiment
module Distributed
  attr_accessor :master
  def get_work()
	  if cv = @started.index(false)
	    @started[cv] = true
	    {:cv => cv, :input => @data[cv], :dir => @dir, :options => Experiment::Config.to_h }
	  else
	    false
    end
  end
  
  def distribution_done?
    @started.all?
  end
  
  def submit_result(cv, result, performance)
    @completed[cv] = true
    array_merge(@results, result)
    @abm << performance
    Notify.cv_done @experiment, cv
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
			@master.submit_result @current_cv, result, @abm.first
    end

  end
  
  
  def master_run!(cv)
    
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
    @done = true
    summarize_performance!
		summarize_results! @results
		Notify.completed @experiment
		
		#sleep 1
    #DRb.stop_service
  end
end
end