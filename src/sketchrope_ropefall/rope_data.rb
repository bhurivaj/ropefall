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

    # Box holding every point a rope of rope_length can reach with its ends fixed at the first and
    # last point: |PA| + |PB| <= L implies |PM| <= L / 2 for the midpoint M. The polyline itself is
    # included too (a rope shorter than its polyline starts outside that box).
    def fall_room(points, rope_length, margin)
      pts = points.map { |p| xyz(p) }
      first = pts.first
      last = pts.last
      half = rope_length / 2.0
      min = (0..2).map { |i| [pts.map { |p| p[i] }.min, (first[i] + last[i]) / 2.0 - half].min - margin }
      max = (0..2).map { |i| [pts.map { |p| p[i] }.max, (first[i] + last[i]) / 2.0 + half].max + margin }
      [min, max]
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
