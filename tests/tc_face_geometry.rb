# frozen_string_literal: true

# Run (no SketchUp needed): ruby tests/tc_face_geometry.rb
require 'minitest/autorun'
require_relative '../src/sketchrope_ropefall/face_geometry'

class TestFaceGeometry < Minitest::Test
  G = SKETCHROPE_ROPEFALL::FaceGeometry
  UP = [0.0, 0.0, 1.0].freeze

  SQUARE = [[0, 0, 5], [10, 0, 5], [10, 10, 5], [0, 10, 5]].freeze
  # concave L: the notch (6..10, 6..10) is outside
  L_SHAPE = [[0, 0, 0], [10, 0, 0], [10, 6, 0], [6, 6, 0], [6, 10, 0], [0, 10, 0]].freeze
  HOLE = [[3, 3, 5], [7, 3, 5], [7, 7, 5], [3, 7, 5]].freeze

  def assert_vector(expected, actual)
    expected.each_with_index { |v, i| assert_in_delta v, actual[i], 1e-9 }
  end

  def test_normal_of_horizontal_square
    assert_vector [0, 0, 1], G.normal(SQUARE)
    assert_vector [0, 0, -1], G.normal(SQUARE.reverse)
  end

  def test_normal_of_vertical_and_slanted_faces
    wall = [[0, 0, 0], [10, 0, 0], [10, 0, 10], [0, 0, 10]]
    assert_vector [0, -1, 0], G.normal(wall)
    slope = [[0, 0, 0], [10, 0, 10], [10, 10, 10], [0, 10, 0]]
    s = Math.sqrt(0.5)
    assert_vector [-s, 0, s], G.normal(slope)
  end

  def test_normal_of_degenerate_polygon_is_nil
    assert_nil G.normal([[0, 0, 0], [1, 1, 1], [2, 2, 2]])
    assert_nil G.normal([[0, 0, 0], [0, 0, 0], [0, 0, 0]])
  end

  def test_classify_square
    assert_equal :inside, G.classify([5, 5, 5], SQUARE, [], UP)
    assert_equal :outside, G.classify([15, 5, 5], SQUARE, [], UP)
    assert_equal :on_edge, G.classify([5, 0, 5], SQUARE, [], UP)
    assert_equal :on_vertex, G.classify([10, 10, 5], SQUARE, [], UP)
  end

  def test_classify_uses_tolerance
    assert_equal :on_edge, G.classify([5, 0.0005, 5], SQUARE, [], UP)
    assert_equal :inside, G.classify([5, 0.01, 5], SQUARE, [], UP)
    assert_equal :on_vertex, G.classify([10.0005, 10, 5], SQUARE, [], UP)
  end

  def test_classify_concave_polygon
    assert_equal :inside, G.classify([2, 8, 0], L_SHAPE, [], UP)
    assert_equal :inside, G.classify([8, 2, 0], L_SHAPE, [], UP)
    assert_equal :outside, G.classify([8, 8, 0], L_SHAPE, [], UP), 'the notch is outside'
    assert_equal :on_vertex, G.classify([6, 6, 0], L_SHAPE, [], UP), 'reflex vertex'
  end

  def test_classify_polygon_with_hole
    assert_equal :inside, G.classify([1, 1, 5], SQUARE, [HOLE], UP)
    assert_equal :outside, G.classify([5, 5, 5], SQUARE, [HOLE], UP), 'inside the hole'
    assert_equal :on_edge, G.classify([5, 3, 5], SQUARE, [HOLE], UP), 'on the hole edge'
    assert_equal :on_vertex, G.classify([7, 7, 5], SQUARE, [HOLE], UP)
  end

  def test_classify_vertical_face_uses_the_right_projection
    wall = [[0, 0, 0], [10, 0, 0], [10, 0, 10], [0, 0, 10]]
    n = G.normal(wall)
    assert_equal :inside, G.classify([5, 0, 5], wall, [], n)
    assert_equal :outside, G.classify([5, 0, 15], wall, [], n)
    assert_equal :on_edge, G.classify([0, 0, 5], wall, [], n)
  end

  def test_classify_ignores_distance_from_the_plane
    # callers project onto the plane first; a point slightly off it is classified by its projection
    assert_equal :inside, G.classify([5, 5, 5.3], SQUARE, [], UP)
  end
end
