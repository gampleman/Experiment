module Experiment
  class WorkServer
    def initialize(experiments, options, ip = "localhost")
      uri="druby://#{ip}:8787"
      # The object that handles requests on the server
      front_object = self
      #$SAFE = 1   # disable eval() and friends
      DRb.start_service(uri, front_object)
      
      @experiments = experiments
      @started = @experiments.map { |e| false }
      @done = @started
      @options = options
      @experiment_instances = []
      DRb.thread.join
    end
    
    def ready?
      true
    end
    
    def new_item
      @experiments.each_with_index do |e, i|
        if @experiment_instances[i].nil?
          exp = @experiments[i]
          require "./experiments/#{exp}/#{exp}"
  			  cla = eval(as_class_name(exp))
  				experiment = cla.new :master, exp, @options.opts, @options.env
  				experiment.master_run! @options.cv
  				@experiment_instances[i] = experiment
  				return i
  			elsif !@experiment_instances[i].distribution_done?
          return i
        end
      end
      
      DRb.stop_service if @experiment_instances.all? {|a| a.done? }
      false
    end
    
    def notify
      Notify
    end
    
    def experiment(num)
      @experiments[num]
    end
    
    def instance(num)
      @experiment_instances[num]
    end
    
    def as_class_name(str)
      str.split(/[\_\-]+/).map(&:capitalize).join
    end
    
  end
end