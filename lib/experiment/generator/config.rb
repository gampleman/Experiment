require "yaml"

module Experiment
	class Config
		def self.load(experiment, env = :development)
			conf = YAML::load_file(File.dirname(__FILE__) + "/config.yaml")
			expath = File.expand_path(File.dirname(__FILE__) + "/../experiments/#{experiment}/config.yml")
			#puts expath
			if File.exists? expath
				exp = YAML::load_file(expath)
			else
				exp = { "experiment" => {"#{env}" => {} } }
			end
			@@config = conf["environments"][env.to_s].merge exp["experiment"][env.to_s]
		end

		def self.[](v)
			@@config[v.to_s]
		end
	end
end