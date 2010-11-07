require File.dirname(__FILE__) + "/../lib/experiment/config"
#require "wrong"
class TestConfig < Test::Unit::TestCase
  #include Wrong
  def test_get
    Experiment::Config::set "hello" => "Hello :who"
    assert_equal "Hello world", Experiment::Config::get(:hello, :who => "world")
    assert_equal "Hello world", Experiment::Config::get(:hello, "Hello jj", :what => "ganja", :who => "world")
    assert_equal "Hello world", Experiment::Config::get(:world, "Hello world", :who => "world")
  end
end