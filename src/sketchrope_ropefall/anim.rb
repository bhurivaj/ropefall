require 'sketchup.rb'
Sketchup::require "sketchrope_ropefall/constants"

module SKETCHROPE_ROPEFALL

class Anim
    attr_reader :finished

    def initialize(initialPoints, config)
        @torsionSpringVectorBegin = (initialPoints[0] - initialPoints[1]).normalize
        @torsionSpringVectorEnd = (initialPoints[-2] - initialPoints[-1]).normalize
        @rope = Rope.new(initialPoints, polylineLength(initialPoints) * config.lengthPercent, config.radius, config.noRopePoints, config.massPointMass, config.springConstant, config.springFrictionConstant, config.surfaceFrictionConstant, @torsionSpringVectorBegin, @torsionSpringVectorEnd, SKETCHROPE_ROPEFALL::torsionSpringConstant) 
        @ropeGroup = SKETCHROPE_ROPEFALL::entities.add_group
        @count = config.animIterCount
        @minCount = config.animIterCount - config.minAnimIterCount
        @dt = config.dt
        @dtFactor = 1
        @stopped = false
        @finished = false
    end
    
    def polylineLength(initialPoints)
        last = nil
        len = 0
        initialPoints.each{|p| 
            if (last != nil) 
               len = len + last.distance(p) 
            end
            
            last = p
        }
        
        return len
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
    rescue StandardError => e
        SKETCHROPE_ROPEFALL::failFall(e)
        return false
    end    
   
    def finish(view, points)
        @finished = true
        @ropeGroup.entities.clear!
        @ropeGroup.erase!

        @ropeGroup = SKETCHROPE_ROPEFALL::entities.add_group
        points_chunk = points[0..99]
        edges = @ropeGroup.entities.add_curve points_chunk  
        
        if (SKETCHROPE_ROPEFALL::config().whatToDraw == SKETCHROPE_ROPEFALL::WhatToDraw::TUBE)
            cirlce = @ropeGroup.entities.add_circle points_chunk[0], points_chunk[0] - points_chunk[1], SKETCHROPE_ROPEFALL::config.radius
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
