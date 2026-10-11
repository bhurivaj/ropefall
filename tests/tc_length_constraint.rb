# frozen_string_literal: true

# Run (no SketchUp needed): ruby tests/tc_length_constraint.rb
require 'minitest/autorun'
require_relative '../src/sketchrope_ropefall/length_constraint'

class TestLengthConstraint < Minitest::Test
  C = SKETCHROPE_ROPEFALL::LengthConstraint

  def segment_lengths(points)
    points.each_cons(2).map { |a, b| Math.sqrt((0..2).inject(0.0) { |s, i| s + (b[i] - a[i])**2 }) }
  end

  def test_stretched_chain_is_pulled_back_to_rest_length
    points = [[0.0, 0.0, 0.0], [3.0, 0.0, 0.0], [6.0, 0.0, 0.0], [9.0, 0.0, 0.0]]
    C.project(points, [true, false, false, false], 1.0, 50)
    segment_lengths(points).each { |len| assert_operator len, :<=, 1.0 + 1e-6 }
  end

  def test_frozen_points_never_move
    points = [[0.0, 0.0, 0.0], [5.0, 0.0, 0.0], [10.0, 0.0, 0.0]]
    C.project(points, [true, false, true], 3.0, 20)
    assert_equal [0.0, 0.0, 0.0], points[0]
    assert_equal [10.0, 0.0, 0.0], points[2]
  end

  def test_short_segments_are_left_alone
    points = [[0.0, 0.0, 0.0], [0.5, 0.0, 0.0], [1.0, 0.2, 0.0]]
    before = points.map(&:dup)
    moved = C.project(points, [false, false, false], 1.0, 10)
    assert_equal before, points
    assert_equal [], moved
  end

  def test_block_can_refuse_a_move
    points = [[0.0, 0.0, 0.0], [4.0, 0.0, 0.0]]
    calls = []
    C.project(points, [true, false], 1.0, 3) { |i, from, _to| calls << i; from }
    assert_equal [4.0, 0.0, 0.0], points[1], 'blocked by the collision check'
    assert_includes calls, 1
  end

  def test_returns_moved_indices
    points = [[0.0, 0.0, 0.0], [3.0, 0.0, 0.0], [3.5, 0.0, 0.0]]
    assert_equal [1, 2], C.project(points, [true, false, false], 1.0, 5)
  end

  def test_two_free_ends_share_the_correction
    points = [[0.0, 0.0, 0.0], [4.0, 0.0, 0.0]]
    C.project(points, [false, false], 2.0, 1)
    assert_in_delta 1.0, points[0][0], 1e-9
    assert_in_delta 3.0, points[1][0], 1e-9
  end
end
