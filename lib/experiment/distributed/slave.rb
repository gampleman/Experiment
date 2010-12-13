module Experiment
  module Distributed
    # this module is included into base when running as worker
    module Slave
      # master server DRb object
      attr_accessor :master

      # Main function. Will continously request work from the server,
      # execute it and send back results, then loops to the beggining.
      def run!(not_used_arg)
        while work = @master.get_work
          puts work.inspect
          Experiment::Config.set work[:options]
          @current_cv = work[:cv]
          @dir = work[:dir]
          @data = work[:input]
          #@data = work[:input]
          execute_experiment!
    			result = analyze_result!(@dir + "/raw-#{@current_cv}.txt", @dir + "/analyzed-#{@current_cv}.txt")
    			write_performance!
    			@master.submit_result @current_cv, result, @abm.first
        end

      end
      
      
      def test_data
        @data
      end
      
    end # Master
  end
end