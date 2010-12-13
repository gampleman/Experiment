require "yaml"

module Experiment
  # You have a config directory containing a config.yaml file. This file contains 
  # several environments. The idea is that you might want to tweak your options 
  # differently when running on your laptop then when running on a university 
  # supercomputer.
  # 
  # development is the default environment, you can set any other with the --env option.
  # 
  # Experimental conditions also get their own config.yaml file. This 
  # file overrides the main config file so you can introduce in condition 
  # specific options.
  # 
  # And finally when running an experiment you can use the -o or --options 
  # option to override any config you want.
  # 
  # @example With the yamls like this:
  #   # config/config.yaml
  #   environments:
  #     development:
  #       ref_dir: /Users/kubowo/Desktop/points-vals
  #       master_dir: /Users/kubowo/Desktop/points-vals/s:writer
  #       alpha: 0.4
  #     compute:
  #       ref_dir: /afs/group/DB/points
  #       master_dir: /afs/group/DB/points/s:writer
  #       alpha: 0.4
  #   
  #   # experiments/my_condition/config.yaml
  #   experiment:
  #     development:
  #       alpha: 0.5
  #     compute:
  #       alpha: 0.6
  #
  #   # And you run the experiment with
  #   $ experiment console my_condition --env compute -o "master_dir: /Users/kubowo/Desktop/points-vals/aaa/s:writer"
  #    
  #   # Then your final config will look like this:
  #   > Experiment::Config.to_hash
  #   => { :ref_dir => "/afs/group/DB/points", 
  #          :master_dir => "/Users/kubowo/Desktop/points-vals/s:writer", 
  #          :alpha => 0.6 }
  #   > Experiment::Config[:master_dir]
  #   => "/Users/kubowo/Desktop/points-vals/s:writer"
  #   > Experiment::Config::get :master_dir, :writer => 145
  #   => "/Users/kubowo/Desktop/points-vals/s145"
  # @see https://github.com/gampleman/Experiment/wiki/Configuration
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
  			@config.merge! @override_options if @override_options
  			@config.merge! parse(options)
  		end
      
      # loads the main config file based on the environment
  		def init(env = :development)
  		  conf = YAML::load_file("./config/config.yaml")
  		  @config = conf["environments"][env.to_s]
  		end
      
      # @group Accessing configuration
      
      # Allows access to any config option by key
      # @example
      #   Config[:decay] # looks up decay in hierarchy of config files
      # @param [#to_s] key to llok up in config
  		def [](key)
        @used ||= []
        @used << key.to_s
  			@config[key.to_s]
  		end
  		
  		# Allows access to any config option by key. Supports Interploations.
  		# Interpolations are supported as opts argument
  		#
  		# Words preceded with a colon (:) are interpolated
  		# @overload def get(key)
  		#   Same as {[]}.
  		# @overload def get(key, default)
  		#   Returns default if key not found in configuration.
  		# @overload def get(key, default=nil, interpolations)
  		#   Interpolates values preceded by semicolon.
  		#   Otionaly second argument may be a default value to use if option
  		#   not present.
  		#   @param [Hash] interpolations key will be replaced by value.
  		# @example
  		#   Config.get :existing                   #=> "hello :what"
  		#   Config.get :exisitng, :what => "world" #=> "hello world"
  		#   Config.get :non_existent, "hello" # => "hello"
  		def get(v, *opts)
  		  @used ||= []
        @used << v.to_s
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
		  
		  # @endgroup
		  
		  # Mainly for use on the console for development.
		  #
		  # Usage in experiments may result in a warning, since it may
		  # invalidate results.
		  def set(opts)
		    @used ||= []
		    opts.keys.each {|key| puts "Warning: Overwriting '#{key}' that was already used in an experiment" if @used.include? key }
		    @config ||= opts
		    @config.merge! opts
	    end
		  
		  # parses a string as passed into the CLI -o option
		  # @param [String] options should be in the form of key:value separated by
		  #   commas
  		def parse(options)
  		  return {} if options == ""
  		  Hash[options.split(/\, ?/).map do |a| 
  		    a = a.split /\: ?/
  		    case a.last
  		    when /^\d+$/
  		      a[1] = a[1].to_i
		      when /^\d+\.\d+$/
		        a[1] = a[1].to_f
  		    end
  		    a
  		  end]
		  end
		  
		  # returns current options that were already accessed
		  # @return [Hash]
		  def to_h
		    @used ||= []
		    Hash[*@config.select{|k,v| @used.include? k }.flatten]
	    end
	    
	    # returns all Config values currently loaded
	    # @return [Hash]
	    def to_hash
	      #@used = @config.keys
	      @config
      end
	    
	    # Reads all the keys in config/config.yaml and provides
	    # optparse blocks for them.
	    # @private
	    # @param [OptParse] o Optparse instance to define options on.
	    # @param [OStruct] options The Options instance where to save parsed 
	    #   config and get reserved names from.
	    # @return [Boolean] Returns true if some parses were set.
	    def parsing_for_options(o, options)
	      return unless File.exists? "./config/config.yaml"
	      conf = YAML::load_file("./config/config.yaml")
        num = 0
	      conf["environments"].each do |env, keys|
	        (keys || []).each do |key, value|
	          next if options.marshal_dump.keys.include? key.to_sym
	          #puts env.inspect, key.inspect, value.inspect
	          num += 1
	          cl = value.class == Fixnum ? Integer : value.class;
	          o.on("--#{key} VALUE", cl, "Default value #{value.inspect}") do |v| 
	            @override_options ||= {}
	            @override_options[key] = v
            end
          end
        end
        num > 0
	    end
	    
	    # @return [String]
	    def inspect
	      "Experiment::Config \"" + @config.to_a.map {|k,v| "#{k}: #{v}"}.join(", ") + '"'
	    end
	    
	  end
		
	end
end