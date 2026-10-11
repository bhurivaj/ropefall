# frozen_string_literal: true

module SKETCHROPE_ROPEFALL
  # Planar polygon math for collision faces, on [x, y, z] arrays (pure Ruby — unit tested)
  module FaceGeometry
    TOLERANCE = 0.001 # inch, SketchUp's own geometric tolerance

    module_function

    # Unit normal of a planar polygon (Newell's method), or nil when it has no area
    def normal(points)
      n = [0.0, 0.0, 0.0]
      points.each_with_index do |p, i|
        q = points[(i + 1) % points.size]
        n[0] += (p[1] - q[1]) * (p[2] + q[2])
        n[1] += (p[2] - q[2]) * (p[0] + q[0])
        n[2] += (p[0] - q[0]) * (p[1] + q[1])
      end
      length = Math.sqrt(dot(n, n))
      return nil if length < 1e-9

      n.map { |v| v / length }
    end

    # :on_vertex, :on_edge, :inside or :outside — `point` is assumed to lie on the polygon's plane
    def classify(point, outer, holes, normal, tolerance = TOLERANCE)
      point = floats(point)
      outer = outer.map { |p| floats(p) }
      holes = holes.map { |hole| hole.map { |p| floats(p) } }
      loops = [outer] + holes
      loops.each { |loop| loop.each { |v| return :on_vertex if distance(point, v) <= tolerance } }
      loops.each do |loop|
        each_segment(loop) { |a, b| return :on_edge if distance_to_segment(point, a, b) <= tolerance }
      end

      axis = dominant_axis(normal)
      return :outside unless inside_2d?(point, outer, axis)
      return :outside if holes.any? { |hole| inside_2d?(point, hole, axis) }

      :inside
    end

    # Even-odd test after dropping the axis the polygon faces most
    def inside_2d?(point, polygon, axis)
      u, v = [0, 1, 2] - [axis]
      inside = false
      each_segment(polygon) do |a, b|
        next if (a[v] > point[v]) == (b[v] > point[v])

        cross = a[u] + (point[v] - a[v]) * (b[u] - a[u]) / (b[v] - a[v])
        inside = !inside if point[u] < cross
      end
      inside
    end

    def dominant_axis(normal)
      abs = normal.map(&:abs)
      abs.index(abs.max)
    end

    def each_segment(loop)
      loop.each_with_index { |a, i| yield a, loop[(i + 1) % loop.size] }
    end

    def distance_to_segment(p, a, b)
      ab = sub(b, a)
      len2 = dot(ab, ab)
      return distance(p, a) if len2.zero?

      t = [[dot(sub(p, a), ab) / len2, 0.0].max, 1.0].min
      distance(p, [a[0] + ab[0] * t, a[1] + ab[1] * t, a[2] + ab[2] * t])
    end

    def distance(a, b)
      d = sub(a, b)
      Math.sqrt(dot(d, d))
    end

    # Integer coordinates would make the divisions above truncate
    def floats(point)
      point.map(&:to_f)
    end

    def sub(a, b)
      [a[0] - b[0], a[1] - b[1], a[2] - b[2]]
    end

    def dot(a, b)
      a[0] * b[0] + a[1] * b[1] + a[2] * b[2]
    end
  end
end
