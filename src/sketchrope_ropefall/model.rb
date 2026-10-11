require "sketchup.rb"
Sketchup::require "sketchrope_ropefall/constants"
Sketchup::require "sketchrope_ropefall/util"
Sketchup::require "sketchrope_ropefall/grid"

module SKETCHROPE_ROPEFALL

class MassPoint
    attr_reader :mass
    attr_reader :radius
    attr_reader :prevPos
    attr_reader :pos
    attr_reader :vel
    attr_reader :force
    attr_reader :frozen
    attr_reader :id
    attr_reader :supportPoint
    attr_reader :faceInFront
    attr_reader :velDiff
    attr_reader :prevVel
    attr_writer :left
    attr_writer :right

def initialize(id, mass, pos, radius, surfaceFrictionConstant, grid)
    @mass = mass
    @pos = pos
    @radius = radius
    @surfaceFrictionConstant = surfaceFrictionConstant
    @grid = grid
    @prevPos = Geom::Point3d.new(pos)
    @vel = Geom::Vector3d.new
    @force = Geom::Vector3d.new
    @frozen = false
    @id = id
    @supportPoint = nil
    @faceInFront = nil
    @velDiff = Geom::Vector3d.new
    @prevVel = Geom::Vector3d.new
end    

def simulate(dt)
    @prevPos.set!(@pos.x, @pos.y, @pos.z)
    @prevVel.set!(@vel.x, @vel.y, @vel.z)

    if (@frozen)
        return
    end

    applySurfaceForces()

    if (@force.length > 0)
        dv = Geom::Vector3d.new(@force)
        dv.length = dv.length / @mass * dt
        @velDiff = dv
        @vel = @vel + @velDiff;
    end
    
    dp = Geom::Vector3d.new(@vel)
    
    if (dp.length > 0)
        dp.length = @vel.length * dt
    end
    
    if (dp.length > 0)
        if (@left != nil)
            maxRotDist = SKETCHROPE_ROPEFALL::maxMoveByMaxRot(@prevPos, dp, @left.pos)
            
            if (maxRotDist < dp.length)
                dp.length = maxRotDist
            end
        end

#        if (@right != nil)
#            maxRotDist = SKETCHROPE_ROPEFALL::maxMoveByMaxRot(@prevPos, dp, @right.pos)
#            
#            if (maxRotDist < dp.length)
#                dp.length = maxRotDist
#            end
#        end
    end

    @pos = @pos + dp;     
            
    faces = @grid.getFaces(@prevPos, @pos)
    
    collosionData = SKETCHROPE_ROPEFALL::collosionData(@prevPos, @pos, @radius, faces)
    @faceInFront = collosionData[3]
        
    cross_p = collosionData[0]
    projected_p = collosionData[1] 
    reflected_p = collosionData[2]
    
    @supportPoint = nil
    if (projected_p != nil)
        @pos = reflected_p
        @vel = Geom::Vector3d.new

        distance = @pos.distance(projected_p)

        if ((distance - @radius).abs < SKETCHROPE_ROPEFALL::EPSILON)
            @supportPoint = projected_p
        end
    end
                    
    cylinderCollided = false
    
    if (@left != nil)
        raise "wrong left neighbor" unless @left.id == @id - 1
        cylinderCollided = SKETCHROPE_ROPEFALL::isCylinderCollided(@pos, @left.pos, @radius, @grid.getFaces(@pos, @left.pos))
    end
    
    if (!cylinderCollided && @right != nil)
        raise "wrong right neighbor" unless @right.id == @id + 1
        cylinderCollided = SKETCHROPE_ROPEFALL::isCylinderCollided(@pos, @right.pos, @radius, @grid.getFaces(@pos, @right.pos))
    end

    if (cylinderCollided)

        @pos = @prevPos

        if (@vel.length > 0)
            @vel.length = @vel.length / 2
        end

        @supportPoint = nil
    end

    slowDown()
        
    @force = Geom::Vector3d.new
end

def slowDown()
    if (@vel.length > 0)
        @vel.length = SKETCHROPE_ROPEFALL::generalFrictionConstant * @vel.length
    end
end

def applySurfaceForces()
    closestFaceData = SKETCHROPE_ROPEFALL::getClosestFace(@pos, @grid.getFaces(@pos, @pos))
    
    if (closestFaceData == nil)
        return
    end
    
    distance = closestFaceData[0]
    projected_p = closestFaceData[1]
    closestFace = closestFaceData[2]
    
    if ((distance - @radius).abs < SKETCHROPE_ROPEFALL::EPSILON)
        support_v = @pos - projected_p # normal force if touching the surface
        support_v.normalize!
        l = @force.dot(support_v.reverse)
        
        if (l > 0)
            support_v.length = l
        
            applyForce(support_v)
            applyFrictionForce(support_v)
        end
    end
end

def applyFrictionForce(normalForce)
    if (@force.length == 0)
        return
    end
    
    maxFrictionMagnitude = normalForce.length * @surfaceFrictionConstant
    
    if (@force.length > maxFrictionMagnitude) 
        @force.length = @force.length - maxFrictionMagnitude
    else
        @force = Geom::Vector3d.new
    end
end

def applyForce(f)
    @force = @force + f
end

def applyG()
    g = Geom::Vector3d.new(0, 0, -1)
    g.length = 9.81 * @mass
    applyForce(g)
end

def freeze()
    @frozen = true
    @vel = Geom::Vector3d.new
end

# Length constraint: move toward `target`, stopping at a face like simulate does; returns the position reached
def constrainTo(target)
    return @pos if @frozen

    data = SKETCHROPE_ROPEFALL::collosionData(@pos, target, @radius, @grid.getFaces(@pos, target))
    candidate = data[1] != nil ? data[2] : target
    # like simulate: a segment to a neighbour must not cut through a face (rope over a thin edge)
    return @pos if segmentBlocked?(candidate)

    @pos = candidate
    @supportPoint = (data[1] != nil && (@pos.distance(data[1]) - @radius).abs < SKETCHROPE_ROPEFALL::EPSILON) ? data[1] : nil
    return @pos
end

def segmentBlocked?(pos)
    [@left, @right].any?{|n| n != nil && SKETCHROPE_ROPEFALL::isCylinderCollided(pos, n.pos, @radius, @grid.getFaces(pos, n.pos))}
end

# after a constrained move the velocity is the step actually taken (otherwise it keeps building up)
def followConstraint(dt)
    v = @pos - @prevPos
    v.length = v.length / dt if v.length > 0
    @vel = v
end

def hasMoved()
    m = (@pos - @prevPos).length
    return m > SKETCHROPE_ROPEFALL::minMoveDelta
end

def movedDiff()
    return (@pos - @prevPos)
end

def closestPoint(g, pos, prevPos)
    line = [prevPos, pos - prevPos]
    minDist = 999999999    
    closestPoint = nil
    g.entities.each{ |e|
        if (e.is_a?(Sketchup::Edge)) 
            e.vertices.each{|v|
                if (v.position.distance_to_line(line) == 0)
                    dist = prevPos.distance(v.position)
                    if (dist < minDist)
                        minDist = dist
                        closestPoint = v.position
                    end
                end
            }
        end
    }    
    
    return closestPoint
end

end

class Spring
    attr_reader :massPoint1
    attr_reader :massPoint2
    attr_reader :springConstant
    attr_reader :springlength
    attr_reader :frictionConstant
    
    def initialize(massPoint1, massPoint2, springConstant, springlength, frictionConstant)
        @massPoint1 = massPoint1
        @massPoint2 = massPoint2
        @springConstant = springConstant
        @springlength = springlength
        @frictionConstant = frictionConstant
    end
    
    def solve()
        springVector = massPoint1.pos - massPoint2.pos

        if (springVector.length > 0)
            springForce = Geom::Vector3d.new(springVector)                
            springForce.length = (springVector.length - @springlength) * @springConstant
            
            frictionForce = Geom::Vector3d.new(massPoint1.vel - massPoint2.vel)
            
            if (frictionForce.length > 0)
                frictionForce.length = frictionForce.length * @frictionConstant
            end
            
            springForce = springForce + frictionForce
            
            massPoint1.applyForce(springForce.reverse)        
            massPoint2.applyForce(springForce)                
        end
    end
end

class ConstantVectorProvider
    def initialize(vector)
        @vector = vector
    end    
    
    def getVector()
        return @vector
    end
    
    def getMassPoint()
        return nil
    end
end

class RopeSegmentVectorProvider
    def initialize(from, to)
        @from = from
        @to = to
    end    

    def getVector()
        return @to.pos() - @from.pos()
    end

    def getMassPoint()
        return @to
    end
end

class TorsionSpring
#    attr_reader :force

    def initialize(vectorProvider1, vectorProvider2, massPoint, targetRadian, springConstant)
        @vectorProvider1 = vectorProvider1
        @vectorProvider2 = vectorProvider2
        @massPoint = massPoint
        @targetRadian = targetRadian
        @springConstant = springConstant
    end
    
    def solve()
        v1 = @vectorProvider1.getVector().normalize()
        v2 = @vectorProvider2.getVector().normalize()
        
        loadAngle = Math::PI - v1.angle_between(v2) - @targetRadian
        
        if (loadAngle.abs > SKETCHROPE_ROPEFALL::EPSILON)   
            @force = v1 + v2
            
            if (@force.length == 0)
                @force = Geom::Vector3d.new(v1.y(), -v1.x(), v1.z()).cross(v1)
            end

            if (@force.length > 0)
                @force.length = @springConstant * loadAngle
                
                if (!isBlocked(@force))
                    @massPoint.applyForce(@force)
                else                
                    leftAvailable = @vectorProvider1.getMassPoint() != nil
                    rightAvailable = @vectorProvider2.getMassPoint() != nil
                    
                    if (leftAvailable || rightAvailable)    
                        portion = (leftAvailable && rightAvailable) ? 0.5 : 1.0               
                        
                        if (leftAvailable)
                            @force = v1.cross(v2).cross(v1).reverse
                            
                            if (@force.length > 0)
                                @force.length = portion * @springConstant * loadAngle  
                                mp = @vectorProvider1.getMassPoint()
                                mp.applyForce(@force)                        
                            end
                        end

                        if (rightAvailable)
                            @force = v2.cross(v1).cross(v2).reverse
                            if (@force.length > 0)
                                @force.length = portion * @springConstant * loadAngle
                                mp = @vectorProvider2.getMassPoint()
                                mp.applyForce(@force)                        
                            end
                        end
                    end
                end
            end
        end
    end
    
    def isBlocked(dir)
        return @massPoint.frozen() || (@massPoint.supportPoint() != nil && (@massPoint.pos() - @massPoint.supportPoint()).dot(dir) < -SKETCHROPE_ROPEFALL::EPSILON)
    end
end

class Rope
    attr_reader :radius
    attr_reader :massPoints
    attr_reader :springs
    attr_reader :noRopePoints
    attr_reader :massPointMass
    attr_reader :maxVelPctChange
    attr_reader :hasAnyMoved
    
    
    def initialize(initialPath, length, radius, noRopePoints, massPointMass, springConstant, springFrictionConstant, surfaceFrictionConstant, torsionSpringVectorBegin, torsionSpringVectorEnd, torsionSpringConstant, roomBounds, skip = nil)  
        @radius = radius
        @noRopePoints = noRopePoints
        @massPointMass = massPointMass
        springLength = length / (@noRopePoints - 1)
        @segmentLength = springLength
        @grid = Grid.new(springLength, roomBounds, skip)
        initialPathLength = pathLength(initialPath)
        stepLength = initialPathLength / (@noRopePoints - 1)
        
        @massPoints = []
        @massPoints << MassPoint.new(0, @massPointMass, initialPath[0], @radius, surfaceFrictionConstant, @grid)
        j = 0
        step = (initialPath[j + 1] - initialPath[j])
        availableLength = step.length
        step.length = stepLength
        
        i = 1
        while (i < @noRopePoints - 1) do
            if (availableLength < step.length)
                j = j + 1
                step = (initialPath[j + 1] - initialPath[j])
                newSectionInitialStepLength = stepLength - availableLength
                step.length = newSectionInitialStepLength
                @massPoints << MassPoint.new(i, @massPointMass, initialPath[j] + step, @radius, surfaceFrictionConstant, @grid)

                step = (initialPath[j + 1] - initialPath[j])
                availableLength = step.length - newSectionInitialStepLength
                step.length = stepLength
            else
                @massPoints << MassPoint.new(i, @massPointMass, @massPoints[i - 1].pos + step, @radius, surfaceFrictionConstant, @grid)
                availableLength = availableLength - step.length                
            end            
            
            i = i + 1
        end
        
        @massPoints << MassPoint.new(i, @massPointMass, initialPath.last, @radius, surfaceFrictionConstant, @grid)
        @massPoints[0].freeze()
        @massPoints[1].freeze()
        @massPoints[-1].freeze()
        @massPoints[-2].freeze()
        
        i = 1
        while (i < @noRopePoints - 1) do
            @massPoints[i].left = @massPoints[i - 1]
            @massPoints[i].right = @massPoints[i + 1]
            i = i + 1
        end   
        @massPoints[0].right = @massPoints[1]
        @massPoints[@noRopePoints - 1].left = @massPoints[@noRopePoints - 2]

        @springs = []
        i = 0
        while (i < @noRopePoints - 1) do
            @springs << Spring.new(@massPoints[i], @massPoints[i + 1], springConstant, springLength, springFrictionConstant)
            i = i + 1
        end   
        
        @torsionSprings = []
        targetRadian = 0

        @torsionSprings << TorsionSpring.new(ConstantVectorProvider.new(torsionSpringVectorBegin), RopeSegmentVectorProvider.new(@massPoints[0], @massPoints[1]), @massPoints[0], 0, torsionSpringConstant)
        i = 1
        targetRadian = 0
        while (i < @noRopePoints - 1) do
            @torsionSprings << TorsionSpring.new(RopeSegmentVectorProvider.new(@massPoints[i], @massPoints[i - 1]), RopeSegmentVectorProvider.new(@massPoints[i], @massPoints[i + 1]), @massPoints[i], targetRadian, torsionSpringConstant)
            i = i + 1
        end   
        @torsionSprings << TorsionSpring.new(RopeSegmentVectorProvider.new(@massPoints[@noRopePoints - 1], @massPoints[@noRopePoints - 2]), ConstantVectorProvider.new(torsionSpringVectorEnd), @massPoints[@noRopePoints - 1], 0, torsionSpringConstant)
         
         @maxVelPctChange = 0    
    end    
    
    def pathLength(path)
        raise "path consists of at least two points" unless path.length >=2

        l = 0
        i = 1
                
        while (i < path.length) do
            l = l + (path[i] - path[i - 1]).length
            i = i + 1
        end
        
        return l
    end
    
    def solve()
        @springs.each{|s| s.solve()}
        @torsionSprings.each{|s| s.solve()}
        @massPoints.each{|mp| mp.applyG()}        
    end
    
    def simulate(dt)
        @massPoints.each{|mp| mp.simulate(dt)}
        enforceLength(dt)

        @maxVelPctChange = 0
        @hasAnyMoved = false

        @massPoints.each{|mp|
            prevVel = mp.prevVel
            velDiff = mp.velDiff

            velPctChange = 0

            if (mp.hasMoved() && prevVel.length > 0.5)
                velPctChange = velDiff.length / prevVel.length
            end

            @maxVelPctChange = SKETCHROPE_ROPEFALL::max(velPctChange, @maxVelPctChange)

            if (mp.hasMoved())
                @hasAnyMoved = true
            end
        }
    end

    CONSTRAINT_PASSES = 16

    # no stretching: segments longer than the rope's segment length are pulled back (moves are
    # collision-checked like normal steps)
    def enforceLength(dt)
        points = @massPoints.map{|mp| RopeData.xyz(mp.pos)}
        frozen = @massPoints.map{|mp| mp.frozen}
        moved = LengthConstraint.project(points, frozen, @segmentLength, CONSTRAINT_PASSES) { |i, from, to|
            RopeData.xyz(@massPoints[i].constrainTo(Geom::Point3d.new(*to)))
        }
        moved.each{|i| @massPoints[i].followConstraint(dt)}
    end
end

def self.ropePoints(rope)
    ropePoints = []
    rope.massPoints.each{|mp| ropePoints << mp.pos}
    
    return ropePoints
end

end

