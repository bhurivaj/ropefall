# frozen_string_literal: true

# Run (no SketchUp needed): ruby tests/tc_rope_data.rb
require 'minitest/autorun'
require 'json'
require_relative 'stub_sketchup'
require_relative '../src/sketchrope_ropefall/rope_data'

class TestRopeData < Minitest::Test
  R = SKETCHROPE_ROPEFALL::RopeData
  Pt = Struct.new(:x, :y, :z)

  def test_xyz_accepts_arrays_and_point_objects
    assert_equal [1.0, 2.0, 3.0], R.xyz([1, 2, 3])
    assert_equal [1.0, 2.0, 3.0], R.xyz(Pt.new(1, 2, 3))
  end

  def test_polyline_length
    assert_in_delta 7.0, R.polyline_length([[0, 0, 0], [3, 4, 0], [3, 4, 2]]), 1e-9
    assert_in_delta 0.0, R.polyline_length([[1, 1, 1]]), 1e-9
  end

  def test_fall_room_covers_midpoint_box_and_polyline
    points = [[0, 0, 10], [50, 0, 30], [10, 0, 10]]
    min, max = R.fall_room(points, 20.0, 1.0)
    # midpoint (5,0,10) +/- 10, polyline reaches x=50 and z=30, then +/- margin 1
    assert_equal [-6.0, -11.0, -1.0], min
    assert_equal [51.0, 11.0, 31.0], max
  end

  def test_every_reachable_point_is_inside_the_room
    a = [0.0, 0.0, 100.0]
    b = [40.0, 10.0, 120.0]
    length = R.distance(a, b) * 10 # 1000 %
    min, max = R.fall_room([a, b], length, 0.0)
    mid = [0, 1, 2].map { |i| (a[i] + b[i]) / 2 }
    rng = Random.new(42)
    checked = 0
    20_000.times do
      p = [0, 1, 2].map { |i| mid[i] + (rng.rand * 2 - 1) * length }
      next if R.distance(p, a) + R.distance(p, b) > length

      checked += 1
      [0, 1, 2].each do |i|
        assert_operator p[i], :>=, min[i]
        assert_operator p[i], :<=, max[i]
      end
    end
    assert_operator checked, :>, 100, 'sampling must actually hit reachable points'
  end

  def test_write_then_read_round_trip
    group = FakeGroup.new
    settings = { 'display' => 'tube', 'sides' => 8 }
    R.write(group, [Pt.new(1, 2, 3), Pt.new(4, 5, 6)], settings, 12.5)
    data = R.read(group)
    assert_equal [[1.0, 2.0, 3.0], [4.0, 5.0, 6.0]], data['points']
    assert_equal settings, data['settings']
    assert_equal 12.5, group.get_attribute(R::DICT, 'length')
  end

  def test_read_rejects_missing_or_damaged_data
    assert_nil R.read(FakeGroup.new), 'no data'
    assert_nil R.read(Object.new), 'not a group'

    bad = lambda do |version, points_json, settings_json = '{}'|
      g = FakeGroup.new
      g.set_attribute(R::DICT, 'version', version)
      g.set_attribute(R::DICT, 'initial_points', points_json)
      g.set_attribute(R::DICT, 'settings', settings_json)
      R.read(g)
    end
    assert_nil bad.call(2, '[[0,0,0],[1,1,1]]'), 'wrong version'
    assert_nil bad.call(1, 'not json'), 'broken points JSON'
    assert_nil bad.call(1, '[[0,0,0]]'), 'fewer than 2 points'
    assert_nil bad.call(1, '[[0,0,0],[1,"x",1]]'), 'non-numeric coordinate'
    assert_nil bad.call(1, '[[0,0,0],[1,1]]'), 'point without 3 values'
    assert_equal({}, bad.call(1, '[[0,0,0],[1,1,1]]', 'not json')['settings'], 'broken settings → empty Hash')
  end
end
