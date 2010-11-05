require File.dirname(__FILE__) + "/../lib/experiment/stats"
#require "wrong"
class TestStats < Test::Unit::TestCase
  #include Wrong
  
  def setup
    @data = [1, 2, 3, 4]
  end
  
  def test_sum
    
    assert_equal 10, Stats::sum(@data)
    assert_equal 20, Stats::sum(@data) {|d| d * 2}
  end
  
  def test_variance
    assert_equal 1.6666666666666667, Stats::variance(@data)
  end
  
  def test_standard_deviation
    assert_equal 1.2909944487358056, Stats::standard_deviation(@data)
  end
  
  def test_z_scores
    assert_equal [-1.161895003862225,
     -0.3872983346207417,
     0.3872983346207417,
     1.161895003862225], Stats::z_scores(@data)
  end
  
  def test_median
    assert_equal 2.5, Stats::median(@data)
  end
end