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

  def assert_vector(expected, actual)
    expected.each_with_index { |v, i| assert_in_delta v, actual[i], 1e-6 }
  end

  def test_fall_room_uses_the_ellipsoid_and_the_polyline
    points = [[0, 0, 10], [50, 0, 30], [10, 0, 10]]
    min, max = R.fall_room(points, 20.0, 1.0)
    # ends (0,0,10)-(10,0,10), rope 20 stretched 10% → a = 11 along x, b = sqrt(11² - 5²) across;
    # the polyline reaches x = 50 and z = 30 (also the ceiling); then +/- margin 1
    b = Math.sqrt(11**2 - 5**2)
    assert_vector [-7.0, -b - 1, 10 - b - 1], min
    assert_vector [51.0, b + 1, 31.0], max
  end

  def test_fall_room_is_tighter_than_a_sphere_for_a_taut_rope
    a = [0.0, 0.0, 100.0]
    b = [100.0, 0.0, 100.0]
    min, max = R.fall_room([a, b], 125.0, 0.0)
    assert_operator max[1] - min[1], :<, 125.0 * 0.85, 'sideways extent well below the rope length'
    assert_in_delta 100.0, max[2], 1e-9, 'no room above the highest polyline point'
  end

  def test_every_reachable_point_is_inside_the_room
    a = [0.0, 0.0, 100.0]
    b = [40.0, 10.0, 120.0]
    length = R.distance(a, b) * 10 # 1000 %
    min, max = R.fall_room([a, b], length, 0.0)
    mid = [0, 1, 2].map { |i| (a[i] + b[i]) / 2 }
    top = [a[2], b[2]].max
    rng = Random.new(42)
    checked = 0
    20_000.times do
      p = [0, 1, 2].map { |i| mid[i] + (rng.rand * 2 - 1) * length }
      # reachable: within the rope length of both ends (ellipsoid), and not above the start (gravity)
      next if R.distance(p, a) + R.distance(p, b) > length || p[2] > top

      checked += 1
      [0, 1, 2].each do |i|
        assert_operator p[i], :>=, min[i]
        assert_operator p[i], :<=, max[i]
      end
    end
    assert_operator checked, :>, 100, 'sampling must actually hit reachable points'
  end

  def test_fall_room_with_coincident_ends
    min, max = R.fall_room([[0, 0, 50], [5, 0, 60], [0, 0, 50]], 20.0, 0.0)
    assert_vector [-11.0, -11.0, 39.0], min
    assert_vector [11.0, 11.0, 60.0], max
  end

  def test_grid_box_reaches_down_to_the_model_bottom
    # 1 m rope (39.37 in) hanging 25 m (984.25 in) above the model bottom at z = 0: a sagging rope
    # stretches downward, so the grid goes down to the floor; the cell count stays bounded
    length = 39.37
    cube = 1.5 * length / 99
    room_min, room_max = R.fall_room([[0, 0, 984.25], [10, 0, 984.25]], length, 0.1)
    min, max, size = R.grid_box(room_min, room_max, 0.0, cube)
    assert_in_delta 0.0 - size, min[2], 1e-9
    assert_in_delta room_max[2] + size, max[2], 1e-9
    (0..2).each { |i| assert_operator ((max[i] - min[i]) / size).floor + 1, :<=, 103 }
  end

  def test_grid_box_keeps_a_bottom_inside_the_room
    min, _max, size = R.grid_box([0, 0, -10], [20, 20, 30], 5.0, 0.1)
    assert_in_delta 5.0 - size, min[2], 1e-9, 'floor at the model bottom stays inside the grid'
  end

  def test_grid_box_floors_the_cube_size
    # long folded polyline: tiny springs, big room
    room_min = [0.0, 0.0, 0.0]
    room_max = [5000.0, 3000.0, 4000.0]
    min, max, size = R.grid_box(room_min, room_max, -100.0, 0.01)
    assert_in_delta 50.0, size, 1e-9, 'largest side / 100'
    (0..2).each do |i|
      bins = ((max[i] - min[i]) / size).floor + 1
      assert_operator bins, :<=, 103
    end
    _min, _max, small_room_size = R.grid_box([0, 0, 0], [10, 10, 10], 0.0, 2.0)
    assert_in_delta 3.0, small_room_size, 1e-9, 'cube * 1.5 when it is the larger'
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
