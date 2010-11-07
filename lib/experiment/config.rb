require "yaml"

module Experiment
	class Config
	  class << self
	    
	    # the load method takes the basic config file, which is then 
	    # overriden by the experimental config file and finally by
	    # the options string (which should be in this format:
	    # "key: value, key2:value2,key3: value3")
	    def load(experiment, options, env = :development)
	      #init env
	      @config ||= {}
  			expath = File.expand_path("./experiments/#{experiment}/config.yaml")
  			if File.exists? expath
  				exp = YAML::load_file(expath)
  			  @config.merge! exp["experiment"][env.to_s] if exp["experiment"][env.to_s].is_a? Hash
  			end
  			@config.merge! parse(options)
  		end
      
      # loads the main config file
  		def init(env = :development)
  		  conf = YAML::load_file("./config/config.yaml")
  		  @config = conf["environments"][env.to_s]
  		end
      
      
      # Allows access to any config option by key (either String or Symbol)
  		def [](v)
  			@config[v.to_s]
  		end
  		
  		# Allows access to any config option by key. Supports Interploations.
  		# Interpolations are supported as opts argument
  		# words preceded with a colon (:) are interpolated
  		# Otionaly second argument may be a default value to use if option
  		# not present.
  		def get(v, *opts)
  		  default = opts.shift if opts.length == 2 || !opts.first.is_a?(Hash)
  		  out = @config[v.to_s] || default
  		  if opts = opts.first
          opts.keys.reduce(out.dup) do |result, inter|
            result.gsub /:#{inter}/, opts[inter]
          end
        else
  			  out
			  end
		  end
		  
		  def set(opts)
		    @config ||= opts
		    @config.merge opts
	    end
		  
		  # parses a string as passed into the CLI -o option
  		def parse(options)
  		  return {} if options == ""
  		  Hash[options.split(/\, ?/).map{|a| a.split /\: ?/ }]
		  end
		  
		  # returns current options as a Hash object
		  def to_h
		    @config
	    end
	  end
		
	end
end