class Stats
	class << self
		
		def sum(ar, &block)
			ar.reduce(0.0) {|asum, a| (block_given? ? yield(a) : a) + asum}
	  end
		
	  def variance(ar)
	    v = sum(ar) {|x| (mean(ar) - x)**2.0 }
      v/(ar.count - 1.0)
	  end

	  def standard_deviation(ar)
	    Math.sqrt(variance(ar))
	  end

	  def z_scores(ar)
	    ar.map {|x| z_score(ar, x)}
	  end

	  def z_score(ar, x)
	    (x - mean(ar)) / standard_deviation(ar)
	  end

		def range(ar)
			ar.max - ar.min
		end

	  def mean(ar)
	    sum(ar) / ar.count
	  end

	  def median(ar)
			a = ar.sort
			if ar.count.odd?
				a[(ar.count-1)/2]
			else
				(a[ar.count/2 - 1] + a[ar.count/2]) / 2.0
			end
	  end
		
	end
end
