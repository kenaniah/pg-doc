require "test_helper"

class GemTest < MiniTest::Test

  def test_pg_loaded
    refute_nil PG
  end

end
