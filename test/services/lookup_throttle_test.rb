require "test_helper"

class LookupThrottleTest < ActiveSupport::TestCase
  test "bloqueia depois do limite" do
    throttle = Exchange::LookupThrottle.new(cache: ActiveSupport::Cache::MemoryStore.new)

    Exchange::LookupThrottle::LIMIT.times { assert throttle.allow?("1.2.3.4") }
    assert_not throttle.allow?("1.2.3.4")
    assert throttle.allow?("5.6.7.8")
  end
end
