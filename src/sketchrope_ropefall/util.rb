require "sketchup.rb"
Sketchup::require "sketchrope_ropefall/constants"

module SKETCHROPE_ROPEFALL

def self.min(a, b)
    return a < b ? a : b;
end

def self.max(a, b)
    return a > b ? a : b;
end

# http://forums.sketchup.com/t/count-the-total-number-of-faces-in-a-model-of-a-really-complex-model/15755/24
# def self.walk_faces(entities, transformation = Geom::Transformation.new)
#	puts "entities.length = " + entities.length.to_s
#	faces = []
# 
#	entities.each { |e|
#        next if e.is_a?(Sketchup::Edge) or e.is_a?(Sketchup::Image)
# 
#        if e.is_a?(Sketchup::Face)
#            faces << e
#        elsif (e.is_a?(Sketchup::Group))
#            puts "group found " + e.entities.length.to_s + " t = " + e.transformation.to_a.to_s
#            faces.concat(walk_faces(e.entities, transformation * e.transformation))
#        elsif (e.is_a?(Sketchup::ComponentInstance))
#            puts "instance found " + e.definition.entities.length.to_s
#            faces.concat(walk_faces(e.definition.entities, transformation * e.transformation))
#        end
#    }
# 
#                              
#	return faces
# end

# Collects every visible face that touches `bounds` as a WorldFace in world coordinates; nothing is
# added to the model. `skip` (a rope about to be replaced) and entities on hidden tags are ignored.
def self.walk_faces(entities, bounds, t, skip, faces)
    entities.each { |e|
        next if e == skip
        next unless e.is_a?(Sketchup::Face) || e.is_a?(Sketchup::Group) || e.is_a?(Sketchup::ComponentInstance)
        next if e.hidden? || !e.layer.visible?

        if e.is_a?(Sketchup::Face)
            outer = e.outer_loop.vertices.map{|v| t * v.position}
            faceBounds = Geom::BoundingBox.new
            outer.each{|p| faceBounds.add(p)}
            next unless boundsIntersect?(faceBounds, bounds)

            holes = e.loops.reject{|l| l.outer?}.map{|l| l.vertices.map{|v| t * v.position}}
            face = WorldFace.build(outer, holes)
            next if face.nil?

            faces << face

            if (faces.size == SKETCHROPE_ROPEFALL::facesWarnThreshold)
                answer = UI.messagebox("This seems to be a complex model, the Ropefall operation may take long. Please make sure your work is saved. \n\nYou can try hiding parts of the model to make Ropefall faster. \n\nDo you want to continue?", MB_YESNO)
                raise "operation aborted by user" unless answer == IDYES
            end
        else
            # skip whole groups / components that are nowhere near the fall room
            next unless boundsIntersect?(transformBounds(e.bounds, t), bounds)

            childEntities = e.is_a?(Sketchup::Group) ? e.entities : e.definition.entities
            walk_faces(childEntities, bounds, t * e.transformation, skip, faces)
        end
    }
end

def self.boundsIntersect?(b1, b2)
    return !b1.intersect(b2).empty?
end

# World bounds of a box given in the coordinates of transformation `t` (all 8 corners, so rotation is handled)
def self.transformBounds(b, t)
    transformedBounds = Geom::BoundingBox.new
    (0..7).each{|i| transformedBounds.add(t * b.corner(i))}

    return transformedBounds
end

# Lowest z of the visible top-level geometry; `skip` (a rope about to be replaced) does not count; 0 for an empty model
def self.modelBottom(skip = nil)
    bounds = Geom::BoundingBox.new
    entities().each { |e|
        next if e == skip
        next unless e.is_a?(Sketchup::Face) || e.is_a?(Sketchup::Edge) || e.is_a?(Sketchup::Group) || e.is_a?(Sketchup::ComponentInstance)
        next unless e.visible? && e.layer.visible?
        bounds.add(e.bounds)
    }
    return bounds.empty? ? 0 : bounds.min.z
end

# Collision faces for the fall room: a floor at `bottom` plus every visible model face touching `bounds`
def self.getAllFaces(bounds, skip, bottom)
    started = Time.now
    faces = []
    floor = WorldFace.build([Geom::Point3d.new(bounds.min.x, bounds.min.y, bottom), Geom::Point3d.new(bounds.min.x, bounds.max.y, bottom), Geom::Point3d.new(bounds.max.x, bounds.max.y, bottom), Geom::Point3d.new(bounds.max.x, bounds.min.y, bottom)])
    faces << floor if floor

    walk_faces(entities(), bounds, Geom::Transformation.new, skip, faces)

    puts "Ropefall: #{faces.length} collision faces collected in #{(Time.now - started).round(2)} s"

    return faces
end

# see also http://sketchucation.com/forums/viewtopic.php?f=180&t=47331
#def self.getAllFaces()
#    ### IF they aren't inside a context other than the model.entities
#    matching_faces=[]
#    @@entities.each{|face|
#      next unless face.is_a?(Sketchup::Face)
#      ### check for compliance with some 'property' and then
#      puts "1 " + face.to_s
#      matching_faces << face
#    }
#    ### then find all others...
#    @@model.definitions.each{|defn|
#      next if defn.instances.empty?
#      defn.entities.each{|face|
#        next unless face.is_a?(Sketchup::Face)
#        ### check for compliance with some 'property' and then
#        matching_faces << face
#      }
#    }
#
#    return matching_faces
#end

def self.getClosestFace(p, faces)
    if (faces == nil || faces.empty?)    
        return nil
    end

    distance = 100000.m
    closestFace = nil
    projected_p = nil
    faces.each{|f| 
        r = distanceToFace(p, f)
        distance_cand = r[0]
        projected_p_cand = r[1]
        
        if (distance_cand < distance)
            distance = distance_cand
            projected_p = projected_p_cand
            closestFace = f
        end
    }    

    return [distance, projected_p, closestFace]
end

#return [distance, projected_p]
def self.distanceToFace(p, f)
    distance = 0    
    projected_p = p.project_to_plane f.plane    
    classification = f.classify_point(projected_p)
    
    if (classification == Sketchup::Face::PointInside || classification == Sketchup::Face::PointOnEdge || classification == Sketchup::Face::PointOnVertex)
        distance = p.distance(projected_p)
    else
        distance = 100000.m
        f.edges.each{|e| 
            r = distanceToEdge(p, e)
            distance_cand = r[0]
            projected_p_cand = r[1]
            
            if (distance_cand < distance)
                distance = distance_cand
                projected_p = projected_p_cand
            end
        }
    end
    
    return [distance, projected_p]
end

def self.distanceToEdge(p, e)
    projected_p = p.project_to_line e.line
    distance = p.distance(projected_p)
    dist_to_start = projected_p.distance(e.start.position)
    dist_to_end = projected_p.distance(e.end.position)
    
    if (dist_to_start + dist_to_end > e.length + EPSILON)
        if (dist_to_start < dist_to_end)
            projected_p = e.start.position
            distance = p.distance(e.start.position)
        else
            projected_p = e.end.position
            distance = p.distance(e.end.position)            
        end        
    end    
        
    return [distance, projected_p]
end

def self.reflectionFromFace(p, projected_p, f, r)
    d = f.normal
    
    if (d.dot(p - projected_p) < 0)
        d.reverse!
    end
    
    d.length = r
    
    return d
end

#return [cross_p, projected_p, reflected point, f]
def self.isCollidedWithFace(from, to, r, f)
    cross_p = Geom.intersect_line_plane([from, to], f.plane)    
    isPaneCrossed = cross_p != nil && from.distance(to) > from.distance(cross_p) && to.distance(from) > to.distance(cross_p)        

    if (isPaneCrossed)    
        classification = f.classify_point(cross_p)
        
        if (classification == Sketchup::Face::PointInside || classification == Sketchup::Face::PointOnEdge || classification == Sketchup::Face::PointOnVertex)
            d = reflectionFromFace(from, cross_p, f, r)

            return [cross_p, cross_p, cross_p.offset(d)]
        else        
            res = distanceToFace(cross_p, f)
            distance = res[0]
            projected_p = res[1]

    #        cos_alpha = f.normal.dot((to - from).normalize)
            
    #        if (cos_alpha < EPSILON)
    #            return [cross_p, nil, nil, f]
    #        end
            
    #        dist_threshold = r / cos_alpha

            if (distance < r - EPSILON) 
                d = cross_p - projected_p
                d.length = r
                
                return [cross_p, projected_p, projected_p.offset(d), f]
            end
        end
    end
    
    distanceToFaceData = distanceToFace(to, f)
    distance = distanceToFaceData[0]
    projected_p = distanceToFaceData[1]

    if (distance < r - EPSILON)
        d = reflectionFromFace(to, projected_p, f, r)

        return [nil, projected_p, projected_p.offset(d), f]                
    end    

    return [nil, nil, nil, f]
end

def self.collosionData(from, to, r, faces)
    if (faces == nil || faces.empty?)    
        return [nil, nil, nil, nil]
    end

    crossDataRes = [nil, nil, nil, nil]
    distance = 100000.m

    faces.each{|f|
        crossData = isCollidedWithFace(from, to, r, f)
        cross_p = crossData[0]
        projected_p = crossData[1] 
        reflected_p = crossData[2]
        support_f = crossData[3]
        
        distanceToFace = 100000.m
        
        if (reflected_p != nil)
            distanceToFace = projected_p.distance(reflected_p)            
        elsif (cross_p != nil)
            distanceToFace = to.distance(cross_p)
        end
            
        if (distanceToFace < distance)
            if (crossDataRes[1] == nil || projected_p != nil)
                distance = distanceToFace
                crossDataRes = crossData
            end
        end
    }
    
    return crossDataRes
end

def self.isCylinderCollidedWithFace(a_p, b_p, r, f)    
    cross_p = Geom.intersect_line_plane([a_p, b_p], f.plane)
    
    if (cross_p == nil)
        return false
    end
    
    dist_a_cross = a_p.distance(cross_p)
    dist_b_cross = b_p.distance(cross_p)

    isPaneCrossed = a_p.distance(b_p) > dist_a_cross && b_p.distance(a_p) > dist_b_cross                

    if (!isPaneCrossed)
        return false
    end

    classification = f.classify_point(cross_p)
    isInsideFace = classification == Sketchup::Face::PointInside || classification == Sketchup::Face::PointOnEdge || classification == Sketchup::Face::PointOnVertex
    
    if (isInsideFace)
        return true
    end
    
    distData = distanceToFace(cross_p, f)
    distance_cross_projected = distData[0]
    projected_p = distData[1]                
    
    crossToProjected = projected_p - cross_p
    
    if (crossToProjected.dot(a_p - cross_p) > 0)
        dist_endpoint_cross = dist_a_cross
    else
        dist_endpoint_cross = dist_b_cross
    end
                    
    if (dist_endpoint_cross > distance_cross_projected)        
        cos_alpha = (f.normal.dot((a_p - b_p).normalize)).abs
        
        if (cos_alpha < EPSILON)
            puts "cos_alpha very small"
            return false
        end
        
        dist_threshold = r / cos_alpha

        if (distance_cross_projected < dist_threshold - EPSILON)                        
            return true
        end        
    end
    
    return false
end

def self.isCylinderCollided(a_p, b_p, r, faces)
    if (faces == nil || faces.empty?)    
        return false
    end

    faces.each{|f|
        if (isCylinderCollidedWithFace(a_p, b_p, r, f))
            return true
        end
    }    
    return false
end

def self.maxMoveByMaxRot(prevPos, dp, neighborPos)
    beta = dp.angle_between(neighborPos - prevPos)
    gamma = Math::PI - SKETCHROPE_ROPEFALL::maxRot() - beta

    if (gamma > 0)
        c = prevPos.distance(neighborPos)
    
        # a / sin(alpha) = b / sin(beta) = c / sin(b)  
        return Math.sin(SKETCHROPE_ROPEFALL::maxRot()) * c / Math.sin(gamma)  
    end
    
    return 10000000
end

def self.sortSelection() 
    polypoints = []
    endpoints = []
    origSelection = [] 
    SKETCHROPE_ROPEFALL::selection.each{|e| 
        if (e.is_a?(Sketchup::Edge))
            origSelection << e
        end
    }
    
    if (origSelection.empty?)
        return polypoints
    end
    
    origSelection.each{|e| 
        addOrRemoveEndpoint(endpoints, e.start.position)
        addOrRemoveEndpoint(endpoints, e.end.position)        
    }
    
    if (endpoints.size != 2)
        return nil
    end
    
    polypoints << endpoints[0]

    while (!origSelection.empty?)
        endpoint = polypoints[-1]
        nextedge = nil
        nextgedgeindex = origSelection.index{|e| e.start.position == endpoint}
        
        if (nextgedgeindex != nil)
            nextedge = origSelection[nextgedgeindex]
            polypoints << nextedge.end.position
        else
            nextgedgeindex = origSelection.index{|e| e.end.position == endpoint}
            
            raise "endpoint not found" unless nextgedgeindex != nil
            
            nextedge = origSelection[nextgedgeindex]
            polypoints << nextedge.start.position            
        end
        
        origSelection.delete(nextedge)
    end
    
    return polypoints
end

def self.drawVector(p1, p2)
    SKETCHROPE_ROPEFALL::entities.add_cline p1, p2
    SKETCHROPE_ROPEFALL::entities.add_cpoint p1
end

end
