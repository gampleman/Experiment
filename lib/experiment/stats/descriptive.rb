module Experiment
  module Stats
    module Descriptive

  		def sum(ar = self, &block)
  			ar.reduce(0.0) {|asum, a| (block_given? ? yield(a) : a) + asum}
  	  end

  	  def variance(ar = self)
  	    v = sum(ar) {|x| (mean(ar) - x)**2.0 }
        v/(ar.count - 1.0)
  	  end

  	  def standard_deviation(ar = self)
  	    Math.sqrt(variance(ar))
  	  end

  	  def z_scores(ar = self)
  	    ar.map {|x| z_score(ar, x)}
  	  end

  	  def z_score(ar = self, x)
  	    (x - mean(ar)) / standard_deviation(ar)
  	  end

  		def range(ar = self)
  			ar.max - ar.min
  		end

  	  def mean(ar = self)
  	    sum(ar) / ar.count
  	  end

  	  def median(ar = self)
  			a = ar.sort
  			if ar.count.odd?
  				a[(ar.count-1)/2]
  			else
  				(a[ar.count/2 - 1] + a[ar.count/2]) / 2.0
  			end
  	  end

    end
    
    class << self
      	# Monkey pathces the Array class to accept the methods in this class 
      	# as it's own - so instead of `Stats::variance([1, 2, 3])`
      	# you can call [1, 2, 3].variance
    		def monkey_patch!
    		  Array.send :include, Descriptive
    		end
    		
    		include Descriptive
    end
    
  end
end

