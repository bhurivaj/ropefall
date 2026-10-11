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
        # margin: the springs stretch, so the rope can reach a bit beyond L / 2 from the midpoint
        roomMin, roomMax = RopeData.fall_room(initialPoints, length, radius + 0.25 * length)
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
        begin
            finish(view, SKETCHROPE_ROPEFALL::ropePoints(@rope), "stopped: rope left the simulation area")
        rescue StandardError => e
            SKETCHROPE_ROPEFALL::failFall(e)
        end
        return false
    rescue StandardError => e
        SKETCHROPE_ROPEFALL::failFall(e)
        return false
    end    
   
    def finish(view, points, note = nil)
        @finished = true
        @ropeGroup.erase! if @ropeGroup.valid?

        @ropeGroup, buildNote = buildRope(points)
        length = RopeData.polyline_length(points)
        @ropeGroup.name = "Rope #{formatLength(length)}"
        RopeData.write(@ropeGroup, @initialPoints, @settings, length)
        @replace.erase! if @replace && @replace.valid?

        # collect first: erasing while iterating entities can skip items
        collisionGroups = SKETCHROPE_ROPEFALL::entities.grep(Sketchup::Group).select{|g| g.name == COLLISIONGROUPNAME}
        SKETCHROPE_ROPEFALL::entities.erase_entities(collisionGroups) unless collisionGroups.empty?
        Sketchup.active_model.layers.remove(DUPLAYERNAME)
        # select the new rope so Re-simulate can run again right away
        Sketchup.active_model.selection.clear
        Sketchup.active_model.selection.add(@ropeGroup)
        Sketchup.active_model.select_tool nil

        notes = [note, buildNote].compact
        status = "Ropefall done — length #{formatLength(length)}"
        status += " (#{notes.join('; ')})" unless notes.empty?
        Sketchup.status_text = status
    end

    # [group, note]: center line, or a tube along it; falls back to the center line if the tube fails
    def buildRope(points)
        group = SKETCHROPE_ROPEFALL::entities.add_group
        edges = group.entities.add_curve(points)
        note = nil

        if (@settings['display'] == 'tube')
            begin
                circle = group.entities.add_circle(points[0], points[0] - points[1], @settings['diameter'].to_f / 2, @settings['sides'].to_i)
                face = group.entities.add_face(circle)
                raise "followme failed" unless face && face.followme(edges)
                smoothEdges(group) if @settings['smooth']
            rescue StandardError => e
                puts "Ropefall tube: " + e.message
                group.entities.clear!
                group.entities.add_curve(points)
                note = "tube could not be built, kept the center line"
            end
        end

        if (@settings['display'] == 'tube')
            material = @settings['material'].to_s
            group.material = SKETCHROPE_ROPEFALL::model.materials[material] unless material.empty? || SKETCHROPE_ROPEFALL::model.materials[material].nil?
        end

        return [group, note]
    end

    # model units without the "~ " SketchUp adds to rounded values
    def formatLength(length)
        Sketchup.format_length(length).sub(/\A~\s*/, '')
    end

    def smoothEdges(group)
        group.entities.grep(Sketchup::Edge).each{|e|
            if (e.faces.size == 2)
                e.soft = true
                e.smooth = true
            end
        }
    end

end

end
