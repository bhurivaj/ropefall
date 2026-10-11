# frozen_string_literal: true

module SKETCHROPE_ROPEFALL
  # Hanging-chain curve between two points (pure Ruby — unit tested)
  module Catenary
    module_function

    # `count` points spaced evenly along a rope of `length` hanging from a to b ([x, y, z], z up)
    def points(a, b, length, count)
      a = a.map(&:to_f)
      b = b.map(&:to_f)
      dx = b[0] - a[0]
      dy = b[1] - a[1]
      v = b[2] - a[2]
      h = Math.sqrt(dx * dx + dy * dy)
      chord = Math.sqrt(h * h + v * v)
      return sample([a, b], count) if length <= chord + 1e-9
      # (nearly) vertical: the catenary solver loses precision, a U is accurate enough
      return hanging_u(a, b, length, count) if h < 1e-3 * chord

      span = Math.sqrt(length**2 - v**2)
      t = solve_t(span / h)
      k = h / (2 * t) # catenary parameter
      x0 = h / 2 - k * Math.asinh(v / span) # x of the lowest point, measured from a
      c = a[2] - k * Math.cosh(-x0 / k)
      s0 = Math.sinh(-x0 / k)
      result = (0...count).map do |i|
        s = length * i / (count - 1)
        x = x0 + k * Math.asinh(s / k + s0)
        [a[0] + dx / h * x, a[1] + dy / h * x, c + k * Math.cosh((x - x0) / k)]
      end
      result[0] = a
      result[-1] = b
      result
    end

    # t > 0 with sinh(t) / t = ratio (ratio > 1); bisection
    def solve_t(ratio)
      low = 0.0
      high = 1.0
      high *= 2 while Math.sinh(high) / high < ratio
      100.times do
        mid = (low + high) / 2
        if Math.sinh(mid) / mid < ratio
          low = mid
        else
          high = mid
        end
      end
      (low + high) / 2
    end

    # ends straight above each other: down from a, under the lower end, up to b
    def hanging_u(a, b, length, count)
      depth = (length - (b[2] - a[2]).abs) / 2
      bottom = [a[0], a[1], [a[2], b[2]].min - depth]
      points = sample([a, bottom, b], count)
      # the turn must be a vertex, otherwise the polyline cuts it short
      turn = depth_index(a, bottom, b, count)
      points[turn] = bottom if turn > 0 && turn < count - 1
      points
    end

    # index of the sample nearest to the bottom turn
    def depth_index(a, bottom, b, count)
      down = (bottom[2] - a[2]).abs
      up = (b[2] - bottom[2]).abs
      ((count - 1) * down / (down + up)).round
    end

    # `count` points evenly spaced along a polyline
    def sample(path, count)
      lengths = path.each_cons(2).map { |p, q| Math.sqrt((0..2).inject(0.0) { |s, i| s + (q[i] - p[i])**2 }) }
      total = lengths.inject(0.0, :+)
      (0...count).map do |i|
        target = total * i / (count - 1)
        segment = 0
        while segment < lengths.size - 1 && target > lengths[segment]
          target -= lengths[segment]
          segment += 1
        end
        f = lengths[segment].zero? ? 0.0 : [target / lengths[segment], 1.0].min
        p = path[segment]
        q = path[segment + 1]
        (0..2).map { |j| p[j] + (q[j] - p[j]) * f }
      end
    end
  end
end
