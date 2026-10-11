# frozen_string_literal: true

require_relative 'face_geometry'

module SKETCHROPE_ROPEFALL
  # In-memory copy of a model face in world coordinates. It answers the Sketchup::Face methods the
  # collision code uses (plane, normal, edges, bounds, classify_point), so collisions can be computed
  # without copying faces into the model (which made big models take minutes).
  class WorldFace
    # position is shared, not copied like Sketchup::Vertex#position — callers must not mutate it
    Vertex = Struct.new(:position)

    # Answers the Sketchup::Edge methods the collision code uses
    class Edge
      attr_reader :start, :end, :length

      def initialize(a, b)
        @start = Vertex.new(a)
        @end = Vertex.new(b)
        @length = a.distance(b)
      end

      def line
        [@start.position, @end.position - @start.position]
      end
    end

    attr_reader :plane, :edges, :bounds

    # outer, holes: Geom::Point3d loops in world coordinates; nil for a face without area
    def self.build(outer, holes = [])
      normal = FaceGeometry.normal(outer.map { |p| xyz(p) })
      normal ? new(outer, holes, normal) : nil
    end

    def self.xyz(point)
      [point.x.to_f, point.y.to_f, point.z.to_f]
    end

    def initialize(outer, holes, normal)
      @outer = outer.map { |p| WorldFace.xyz(p) }
      @holes = holes.map { |hole| hole.map { |p| WorldFace.xyz(p) } }
      @normal = normal
      origin = @outer.first
      @plane = [normal[0], normal[1], normal[2], -FaceGeometry.dot(normal, origin)]
      @edges = ([outer] + holes).flat_map { |loop| loop.each_with_index.map { |p, i| Edge.new(p, loop[(i + 1) % loop.size]) } }
      @bounds = Geom::BoundingBox.new
      outer.each { |p| @bounds.add(p) }
      @min = (0..2).map { |i| @outer.map { |p| p[i] }.min - FaceGeometry::TOLERANCE }
      @max = (0..2).map { |i| @outer.map { |p| p[i] }.max + FaceGeometry::TOLERANCE }
    end

    # A new vector on every call — callers modify it (reverse!, length=)
    def normal
      Geom::Vector3d.new(*@normal)
    end

    def classify_point(point)
      xyz = WorldFace.xyz(point)
      # cheap reject before the per-vertex / per-edge checks
      return Sketchup::Face::PointOutside if (0..2).any? { |i| xyz[i] < @min[i] || xyz[i] > @max[i] }

      case FaceGeometry.classify(xyz, @outer, @holes, @normal)
      when :inside then Sketchup::Face::PointInside
      when :on_edge then Sketchup::Face::PointOnEdge
      when :on_vertex then Sketchup::Face::PointOnVertex
      else Sketchup::Face::PointOutside
      end
    end
  end
end
