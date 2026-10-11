# frozen_string_literal: true

module SKETCHROPE_ROPEFALL
  # Keeps a chain of points from stretching: no segment may end up longer than `rest` (pure Ruby — unit tested)
  module LengthConstraint
    module_function

    # points: [[x, y, z], ...] Floats, modified in place; frozen: [Boolean, ...].
    # A segment longer than `rest` is pulled back to `rest` (shorter ones are left alone — a rope can
    # bend, not stretch). The block gets (index, from, to) and returns the position actually reached
    # (collisions). Returns the sorted indices of the points that moved.
    def project(points, frozen, rest, iterations, &mover)
      moved = {}
      iterations.times do
        (0...points.size - 1).each do |k|
          a = points[k]
          b = points[k + 1]
          d = (0..2).map { |i| b[i] - a[i] }
          length = Math.sqrt(d.inject(0.0) { |sum, c| sum + c * c })
          next if length <= rest

          share_a, share_b = shares(frozen[k], frozen[k + 1])
          excess = (length - rest) / length
          shift(points, k, d.map { |c| c * excess * share_a }, moved, &mover) if share_a > 0
          shift(points, k + 1, d.map { |c| -c * excess * share_b }, moved, &mover) if share_b > 0
        end
      end
      moved.keys.sort
    end

    # how much of a correction each end of a segment takes
    def shares(frozen_a, frozen_b)
      return [0.0, 0.0] if frozen_a && frozen_b
      return [0.0, 1.0] if frozen_a
      return [1.0, 0.0] if frozen_b

      [0.5, 0.5]
    end

    def shift(points, index, delta, moved)
      from = points[index]
      to = (0..2).map { |i| from[i] + delta[i] }
      reached = block_given? ? yield(index, from, to) : to
      points[index] = reached.map(&:to_f)
      moved[index] = true unless points[index] == from
    end
  end
end
