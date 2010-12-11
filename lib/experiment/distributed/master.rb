module Experiment
  # It incorporates most of the logic required for distributed
  # computing support.
  # @see https://github.com/gampleman/Experiment/wiki/Distributed-Mode
  # @private
  module Distributed
    # this module is included into base when running with --distributed
    module Master
      # Send work from the master server
      # @return [Hash, false] either a spec what work to carry out or false 
      #   when no work available
      def get_work()
    	  if cv = @started.index(false)
    	    @started[cv] = true
    	    {:cv => cv, :input => @data[cv], :dir => @dir, :options => Experiment::Config.to_hash, :cvs => cvs }
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
      def run!(cv)

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
      
    end # module Master
  end
end