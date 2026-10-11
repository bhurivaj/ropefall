# frozen_string_literal: true

# Run (no SketchUp needed): ruby tests/tc_catenary.rb
require 'minitest/autorun'
require_relative '../src/sketchrope_ropefall/catenary'

class TestCatenary < Minitest::Test
  C = SKETCHROPE_ROPEFALL::Catenary

  def length_of(points)
    points.each_cons(2).inject(0.0) { |s, (a, b)| s + Math.sqrt((0..2).inject(0.0) { |t, i| t + (b[i] - a[i])**2 }) }
  end

  def assert_point(expected, actual, delta = 1e-6)
    (0..2).each { |i| assert_in_delta expected[i], actual[i], delta }
  end

  def assert_finite(points)
    points.flatten.each { |v| assert v.finite?, "not finite: #{v}" }
  end

  def test_level_ends_sag_like_a_real_catenary
    pts = C.points([0, 0, 100], [10, 0, 100], 10.5, 101)
    assert_equal 101, pts.size
    assert_point [0, 0, 100], pts.first
    assert_point [10, 0, 100], pts.last
    assert_in_delta 10.5, length_of(pts), 10.5 * 0.005
    mid = pts[50]
    assert_in_delta 5.0, mid[0], 1e-6, 'symmetric'
    assert_in_delta 1.40, 100 - mid[2], 0.05, 'sag of a 10.5 rope over a 10 span'
    assert_equal pts.map { |p| p[2] }.min, mid[2]
  end

  def test_near_vertical_ends_stay_finite_and_keep_length
    pts = C.points([0, 0, 100], [0.01, 0, 0], 110.0, 101)
    assert_finite(pts)
    assert_point [0, 0, 100], pts.first
    assert_point [0.01, 0, 0], pts.last
    assert_in_delta 110.0, length_of(pts), 110.0 * 0.005
  end

  def test_ends_at_different_heights
    pts = C.points([0, 0, 50], [20, 0, 80], 45.0, 100)
    assert_finite(pts)
    assert_point [0, 0, 50], pts.first
    assert_point [20, 0, 80], pts.last
    assert_in_delta 45.0, length_of(pts), 45.0 * 0.005
    assert_operator pts.map { |p| p[2] }.min, :<, 50
  end

  def test_works_in_any_horizontal_direction
    pts = C.points([1, 2, 30], [7, 10, 30], 12.0, 100)
    assert_point [7, 10, 30], pts.last
    assert_in_delta 12.0, length_of(pts), 12.0 * 0.005
    pts.each { |p| assert_in_delta 0.0, (p[0] - 1) * 8 - (p[1] - 2) * 6, 1e-6 } # stays in the vertical plane
  end

  def test_taut_rope_is_a_straight_line
    pts = C.points([0, 0, 0], [3, 4, 0], 5.0, 11)
    assert_point [1.5, 2.0, 0.0], pts[5]
    assert_in_delta 5.0, length_of(pts), 1e-9
  end

  def test_vertical_ends_hang_as_a_narrow_u
    pts = C.points([0, 0, 100], [0, 0, 90], 30.0, 100)
    assert_finite(pts)
    assert_point [0, 0, 100], pts.first
    assert_point [0, 0, 90], pts.last
    assert_in_delta 90 - 10, pts.map { |p| p[2] }.min, 0.5, 'lowest point (30 - 10) / 2 below the lower end'
    assert_in_delta 30.0, length_of(pts), 30.0 * 0.01
  end

  def test_very_slack_rope_stays_finite
    pts = C.points([0, 0, 0], [10, 0, 0], 100.0, 100)
    assert_finite(pts)
    assert_in_delta 100.0, length_of(pts), 100.0 * 0.01
  end
end
