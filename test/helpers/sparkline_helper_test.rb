require "test_helper"

class SparklineHelperTest < ActionView::TestCase
  include SparklineHelper

  test "returns empty points with fewer than two values" do
    assert_empty sparkline_points([])
    assert_empty sparkline_points([ 10 ])
  end

  test "returns one point pair per value in order" do
    points = sparkline_points([ 10, 20, 15 ], width: 80, height: 28, pad: 2)
    assert_equal 3, points.size
    xs = points.map { |p| p.split(",").first.to_f }
    assert_operator xs.first, :<, xs.last
  end

  test "higher values get smaller y coordinates" do
    points = sparkline_points([ 0, 100 ], width: 80, height: 28, pad: 2)
    y0 = points[0].split(",").last.to_f
    y1 = points[1].split(",").last.to_f
    assert_operator y1, :<, y0
  end

  test "flat series still produces points" do
    points = sparkline_points([ 5, 5, 5 ])
    assert_equal 3, points.size
  end
end
