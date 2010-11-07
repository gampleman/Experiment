module Experiment
  
  # This is the class behind the command line magic
  class Runner
    
    attr_reader :options
    
    def initialize(arg, opt)
      @arguments, @options = arg, opt
    end
    
    
    # Generates a new experiment condition
    # Usage of the -m flag for writing a hypothesis is recommended 
    def generate
		  dir = "./experiments/" + @arguments.first
			Dir.mkdir(dir)
			File.open(dir + "/" + @arguments.first + ".rb", "w") do |req_file|
			  req_file.puts "# ## #{as_human_name @arguments.first} ##"
			  req_file.puts "# "+@options.description.split("\n").join("\n# ")
			  req_file.puts
			  req_file.puts
			  req_file.puts "# The first contious block of comment will be included in your report."
			  req_file.puts "# This includes the reference implementation."
			  req_file.puts "# Override any desired files in this directory."
			  Dir["./app/**/*.rb"].each do |f|
			    p = f.split("/") - File.expand_path(".").split("/")
			    req_file.puts "require File.dirname(__FILE__) + \"/../../#{p.join("/")}\""
			  end
			  req_file.puts "\nclass #{as_class_name @arguments.first} < MyExperiment\n\t\nend"
			end
			File.open(dir + "/config.yaml", "w") do |f|
			  f << "---\nexperiment:\n  development:\n  compute:\n"
      end
    end
    
    # generate a new project in the current directory
    def new_project 
      require 'fileutils'
      dir = "./" + @arguments.first
      Dir.mkdir(dir)
      %w[app config experiments report results test tmp vendor].each do |d|
        Dir.mkdir(dir + "/" + d)
      end
      basedir = File.dirname(__FILE__)
      File.open(File.join(dir, "config", "config.yaml"), "w") do |f|
        f << "---\nenvironments:\n  development:\n  compute:\n"
      end
      File.open(File.join(dir, ".gitignore"), "w") do |f|
        f << "tmp/*"
      end
      FileUtils::cp File.join(basedir, "generator/readme_template.txt"), File.join(dir, "README")
      FileUtils::cp File.join(basedir, "generator/Rakefile"), File.join(dir, "Rakefile")
      FileUtils::cp File.join(basedir, "generator/experiment_template.rb"), File.join(dir, "experiments", "experiment.rb")
    end
    
    # Lists available experiments
		def list
		  puts "Available experiments:"
		  puts "  " + Dir["./experiments/*"].map{|a| File.basename(a) }.join(", ")
		end
		
		# Generates 2 files in the report directory
		# method.mmd which sums up comments from experimental conditions
		# data.csv which sums all results in a table
		def report
		  dir = "./report/"
      File.open(dir + "method.mmd", "w") do |f|
        f.puts "# Methods #"
        Dir["./experiments/*/*.rb"].each do |desc|
          if File.basename(desc) == File.basename(File.dirname(desc)) + ".rb"
            File.read(desc).split("\n").each do |line|
              if m = line.match(/^\# (.+)/)
                f.puts m[1]
              else
                break
              end
            end
          f.puts
          f.puts
          end
        end
      end
      require 'csv'
      require "yaml"
      require File.dirname(__FILE__) + "/stats"
      CSV.open(dir + "/data.csv", "w") do |csv|
        data = {}
        Dir["./results/*/results.yaml"].each do |res|
          d = YAML::load_file(res)
          da = {}
          d.each do |k, vals|
            da[k.to_s + " mean"], da[k.to_s + " sd"] = Stats::mean(vals), Stats::standard_deviation(vals)
            vals.each_with_index do |v, i|
              da[k.to_s + " cv:" + i.to_s] = v
            end
          end
          array_merge(data, da)
        end
        data.keys.map do |key| 
    		  # calculate stats
    		  a = data[key]
    		  [key] + a
  		  end.transpose.each do |row|
  		    csv << row
  		  end
      end
		
		end 
		
		
		# runs experiments passed aa arguments
		# use the -o option to override configuration
		def run
		  require File.dirname(__FILE__) + "/base"

		  require "./experiments/experiment"
      Experiment::Config::init @options.env
		  
		  if @options.distributed
		    require "drb/drb"
		    require File.dirname(__FILE__) + "/work_server"
		    puts "Running in distributed mode. Run other machines with:\nexperiment worker --address #{local_ip}\n"
		    Notify::init @arguments.length * @options.cv, STDOUT, Experiment::Config::get(:growl_notifications, true)
		    ws = WorkServer.new @arguments, @options, local_ip
		    Notify::done
		    return true
  	  else
  	    Notify::init @arguments.length * @options.cv, STDOUT, Experiment::Config::get(:growl_notifications, true)
			  @arguments.each do |exp|
  			  require "./experiments/#{exp}/#{exp}"
  			  cla = eval(as_class_name(exp))
  				experiment = cla.new :normal, exp, @options.opts, @options.env
  				experiment.normal_run! @options.cv
  			end
			  Notify::done
		  end
		end
		
		
		# This is a Worker implementation. It requires an --address option
		# of it's master server and will recieve tasks (experiments and
		# cross-validations) and compute them.
		def worker
		  require "drb/drb"
		  require File.dirname(__FILE__) + "/base"
		  Experiment::Config::init @options.env
		  loop do
		    @server_uri="druby://#{@options.master}:8787"
  		  connect
  		  Notify::init 0, STDOUT, false, @master
        while item = @master.new_item
          #puts item
          exp = @master.experiment item
          require "./experiments/experiment"
          require "./experiments/#{exp}/#{exp}"
  			  cla = eval(as_class_name(exp))
  				experiment = cla.new :slave, exp, @options.opts, @options.env
  			  experiment.master = @master.instance item
  			  experiment.slave_run!
        end
      end
	  end
		
		private
		
		require 'socket'

    def connect
      begin
        puts "Connecting..."
        DRb.start_service
        @master = DRbObject.new_with_uri(@server_uri)
        @master.ready?
      rescue
        sleep 10
        connect
      end
    end

    def local_ip
      orig, Socket.do_not_reverse_lookup = Socket.do_not_reverse_lookup, true  
      UDPSocket.open do |s|
        s.connect '64.233.187.99', 1
        s.addr.last
      end
    ensure
      Socket.do_not_reverse_lookup = orig
    end
    
		
    def array_merge(h1, h2)
  	  h2.each do |key, value|
  	   h1[key] ||= []
  	   h1[key] << value
  	  end
	  end
    
    def as_class_name(str)
      str.split(/[\_\-]+/).map(&:capitalize).join
    end
    
    def as_human_name(str)
      str.split(/[\_\-]+/).map(&:capitalize).join(" ")
    end
  end

end