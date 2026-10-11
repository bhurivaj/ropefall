require 'sketchup.rb'
Sketchup::require "sketchrope_ropefall/constants"

module SKETCHROPE_ROPEFALL

class Anim
    attr_reader :finished

    def initialize(initialPoints, settings, replace = nil)
        @initialPoints = initialPoints
        @settings = settings
        @replace = replace
        config = SKETCHROPE_ROPEFALL::config
        @torsionSpringVectorBegin = (initialPoints[0] - initialPoints[1]).normalize
        @torsionSpringVectorEnd = (initialPoints[-2] - initialPoints[-1]).normalize
        length = Settings.target_length(settings, initialPoints)
        radius = settings['diameter'].to_f / 2
        roomMin, roomMax = RopeData.fall_room(initialPoints, length, radius)
        room = Geom::BoundingBox.new
        room.add(Geom::Point3d.new(*roomMin))
        room.add(Geom::Point3d.new(*roomMax))
        @rope = Rope.new(initialPoints, length, radius, config.noRopePoints, config.massPointMass, config.springConstant, config.springFrictionConstant, config.surfaceFrictionConstant, @torsionSpringVectorBegin, @torsionSpringVectorEnd, SKETCHROPE_ROPEFALL::torsionSpringConstant, room, replace) 
        @ropeGroup = SKETCHROPE_ROPEFALL::entities.add_group
        @count = config.animIterCount
        @minCount = config.animIterCount - config.minAnimIterCount
        @dt = config.dt
        @dtFactor = 1
        @stopped = false
        @finished = false
    end
    
    def stop()
        @stopped = true
    end
    
    def nextFrame(view)
        @rope.solve()
        
        maxVelPctChange = @rope.maxVelPctChange
        
        raise "maxVelPctChange < 0" unless maxVelPctChange >= 0
            
        
#        @dtFactor = @dtFactor * (1 - (maxVelPctChange - 0.6) * 0.1)
        
        if (maxVelPctChange < 0.3)
            @dtFactor = @dtFactor * 2
        end

        if (maxVelPctChange > 0.7)
            @dtFactor = @dtFactor * 0.5
        end

        @dtFactor = SKETCHROPE_ROPEFALL::max(0.5, @dtFactor)
        @dtFactor = SKETCHROPE_ROPEFALL::min(2, @dtFactor)
        
        dt = @dt * @dtFactor         
        
        
        @rope.simulate(dt)
        
        points = SKETCHROPE_ROPEFALL::ropePoints(@rope)
        @ropeGroup.entities.clear!
        # todo use view to draw temporarily
        edges = @ropeGroup.entities.add_curve points        
        #view.draw_polyline points

        @count = @count - 1
        
        view.show_frame()

#        finished = @count < @minCount && (@count == 0 || !@rope.hasAnyMoved())
        finished = @stopped || @count == 0 || !@rope.hasAnyMoved()

        if (finished)
            finish(view, points)
	    end
        
        return !finished
    rescue OutOfRoomError
        finish(view, SKETCHROPE_ROPEFALL::ropePoints(@rope), "stopped: rope left the simulation area")
        return false
    rescue StandardError => e
        SKETCHROPE_ROPEFALL::failFall(e)
        return false
    end    
   
    def finish(view, points, note = nil)
        @finished = true
        @ropeGroup.entities.clear!
        @ropeGroup.erase!

        @ropeGroup = SKETCHROPE_ROPEFALL::entities.add_group
        points_chunk = points[0..99]
        edges = @ropeGroup.entities.add_curve points_chunk  
        
        if (@settings['display'] == 'tube')
            cirlce = @ropeGroup.entities.add_circle points_chunk[0], points_chunk[0] - points_chunk[1], @settings['diameter'].to_f / 2
        	face = @ropeGroup.entities.add_face cirlce
            face.followme(edges)
        end

        # collect first: erasing while iterating entities can skip items
        collisionGroups = SKETCHROPE_ROPEFALL::entities.grep(Sketchup::Group).select{|g| g.name == COLLISIONGROUPNAME}
        SKETCHROPE_ROPEFALL::entities.erase_entities(collisionGroups) unless collisionGroups.empty?
        Sketchup.active_model.layers.remove(DUPLAYERNAME)        
        Sketchup.active_model.select_tool nil    
        Sketchup.status_text = "Ropefall ready."
    end

end

end
