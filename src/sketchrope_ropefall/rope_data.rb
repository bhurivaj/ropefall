# frozen_string_literal: true

require 'json'

module SKETCHROPE_ROPEFALL
  # Rope geometry helpers and the data stored on every rope group (pure Ruby — unit tested)
  module RopeData
    DICT = 'sketchrope_ropefall'
    DATA_VERSION = 1

    module_function

    # [x, y, z] floats from an Array or anything with x/y/z (Geom::Point3d)
    def xyz(point)
      return [point.x.to_f, point.y.to_f, point.z.to_f] if point.respond_to?(:x)

      point.map(&:to_f)
    end

    def distance(a, b)
      pa = xyz(a)
      pb = xyz(b)
      Math.sqrt((0..2).inject(0.0) { |sum, i| sum + (pa[i] - pb[i])**2 })
    end

    def polyline_length(points)
      points.each_cons(2).inject(0.0) { |sum, (a, b)| sum + distance(a, b) }
    end

    STRETCH = 0.1 # the springs let the rope get a little longer than its target length

    # Box holding every point the rope can reach: with its ends A, B fixed, a rope of length L
    # (stretched by STRETCH) satisfies |PA| + |PB| <= L — an ellipsoid with foci A, B. The box is that
    # ellipsoid's bounding box joined with the polyline's, capped at the polyline's highest point
    # (gravity only pulls down), then grown by `margin`. If the rope still leaves it, the fall stops
    # and keeps its shape (OutOfRoomError).
    def fall_room(points, rope_length, margin)
      pts = points.map { |p| xyz(p) }
      first = pts.first
      last = pts.last
      a = rope_length * (1 + STRETCH) / 2.0
      half_distance = distance(first, last) / 2.0
      b = Math.sqrt([a**2 - half_distance**2, 0.0].max)
      axis = half_distance.zero? ? [0.0, 0.0, 0.0] : (0..2).map { |i| (last[i] - first[i]) / (2 * half_distance) }
      # half extent of an ellipsoid of revolution along each world axis
      half = (0..2).map { |i| Math.sqrt(a**2 * axis[i]**2 + b**2 * (1 - axis[i]**2)) }
      mid = (0..2).map { |i| (first[i] + last[i]) / 2.0 }

      min = (0..2).map { |i| [pts.map { |p| p[i] }.min, mid[i] - half[i]].min - margin }
      max = (0..2).map { |i| [pts.map { |p| p[i] }.max, mid[i] + half[i]].max + margin }
      max[2] = pts.map { |p| p[2] }.max + margin
      [min, max]
    end

    # [min, max, cube_size] of the collision grid around the room. Z starts at the model bottom only
    # when that is inside the room (the floor face lives there); otherwise at the room's own bottom.
    # Buckets are at least 1/100 of the largest room side so the bin count stays bounded.
    def grid_box(room_min, room_max, bottom, cube)
      largest_side = (0..2).map { |i| room_max[i] - room_min[i] }.max
      size = [cube * 1.5, largest_side / 100.0].max
      min = [room_min[0] - size, room_min[1] - size, [bottom, room_min[2]].max - size]
      max = (0..2).map { |i| room_max[i] + size }
      [min, max, size]
    end

    def write(group, points, settings, length)
      group.set_attribute(DICT, 'version', DATA_VERSION)
      group.set_attribute(DICT, 'initial_points', JSON.generate(points.map { |p| xyz(p) }))
      group.set_attribute(DICT, 'settings', JSON.generate(settings))
      group.set_attribute(DICT, 'length', length.to_f)
    end

    # { 'points' => [[x, y, z], ...], 'settings' => Hash } or nil when the group has no valid rope data
    def read(group)
      return nil unless group.respond_to?(:get_attribute)
      return nil unless group.get_attribute(DICT, 'version') == DATA_VERSION

      points = JSON.parse(group.get_attribute(DICT, 'initial_points', '').to_s)
      return nil unless valid_points?(points)

      { 'points' => points.map { |p| p.map(&:to_f) }, 'settings' => parse_hash(group.get_attribute(DICT, 'settings', '')) }
    rescue JSON::ParserError
      nil
    end

    def valid_points?(points)
      points.is_a?(Array) && points.size >= 2 &&
        points.all? { |p| p.is_a?(Array) && p.size == 3 && p.all? { |v| v.is_a?(Numeric) } }
    end

    def parse_hash(text)
      value = JSON.parse(text.to_s)
      value.is_a?(Hash) ? value : {}
    rescue JSON::ParserError
      {}
    end
  end
end
