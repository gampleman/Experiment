module Experiment
  class Params
   
    # Return if set the value of the current param.
    #
    # If it is not defined fallback to {Experiment::Config#[]}.
    def self.[](h)
      @@params[h] || Config[h]
    end
    
    
    # @private
    def self.set(a) # :nodoc: 
      @@params = a
    end
  end
  Params.set({})
end
