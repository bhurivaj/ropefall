require 'sketchup.rb'
Sketchup::require "sketchrope_ropefall/constants"

module SKETCHROPE_ROPEFALL

class Anim
    attr_reader :finished

    def initialize(initialPoints, settings, replace = nil)
        @model = Sketchup.active_model # the timer in stop() must not touch another open document
        @initialPoints = initialPoints
        @settings = settings
        @replace = replace
        config = SKETCHROPE_ROPEFALL::config
        @torsionSpringVectorBegin = (initialPoints[0] - initialPoints[1]).normalize
        @torsionSpringVectorEnd = (initialPoints[-2] - initialPoints[-1]).normalize
        length = Settings.target_length(settings, initialPoints)
        @targetLength = length
        radius = settings['diameter'].to_f / 2
        # spring stretch is allowed for inside fall_room; the margin only covers the rope's thickness
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
        @finished = false
        @cancelled = false
        @finishScheduled = false
        @frames = 0
        @frameSeconds = 0.0
    end

    # Esc, Enter, or SketchUp stopping the animation itself (e.g. a camera tool): keep the current
    # shape right away instead of waiting for a next frame — frames can be slow, or never come again
    def stop()
        return if @finished || @cancelled || @finishScheduled
        @finishScheduled = true
        # stop the timer first: a message box inside a non-repeating timer makes it repeat (SketchUp bug)
        timer = UI.start_timer(0, false) {
            UI.stop_timer(timer)
            finishNow()
        }
    end

    # the tool was switched mid-fall or the fall failed: the operation is aborted, never finish
    def cancel()
        @cancelled = true
    end

    def finishNow()
        return if @finished || @cancelled
        return unless @model.valid?
        view = @model.active_view
        view.animation = nil # calls stop() again, which returns early now
        finish(view, SKETCHROPE_ROPEFALL::ropePoints(@rope))
    rescue StandardError => e
        SKETCHROPE_ROPEFALL::failFall(e)
    end

    def nextFrame(view)
        return false if @finished || @cancelled || @finishScheduled
        frameStart = Process.clock_gettime(Process::CLOCK_MONOTONIC)
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
        Sketchup.status_text = "Ropefall: falling… Esc or Enter keeps the rope as it is now"
        logFrameTime(frameStart)

#        finished = @count < @minCount && (@count == 0 || !@rope.hasAnyMoved())
        finished = @count == 0 || !@rope.hasAnyMoved()

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

    # Ruby Console: average frame time every 50 frames, to see how heavy a model is for the simulation
    def logFrameTime(frameStart)
        @frames += 1
        @frameSeconds += Process.clock_gettime(Process::CLOCK_MONOTONIC) - frameStart
        return unless (@frames % 50).zero?

        puts "Ropefall: frame #{@frames}, #{(@frameSeconds / 50 * 1000).round} ms per frame"
        @frameSeconds = 0.0
    end

    # Ruby Console: how far the rope reached, as max(|PA| + |PB|) / target length — the fall room
    # assumes RopeData::STRETCH sideways; this shows real values to tune it
    def logReach(points)
        a = points.first
        b = points.last
        reach = points.map{|p| p.distance(a) + p.distance(b)}.max / @targetLength
        puts "Ropefall: reach #{reach.round(2)} × target length (sideways room allows #{1 + RopeData::STRETCH})"
    end

    # Another tool is being activated: keep the current shape (like Esc). The tool is already being
    # left, so finish must not call select_tool itself.
    def keepNow(view)
        return if @finished || @cancelled
        @finishScheduled = true
        view.animation = nil # calls stop(), which returns early now
        finish(view, SKETCHROPE_ROPEFALL::ropePoints(@rope), nil, false)
    end

    def finish(view, points, note = nil, leaveTool = true)
        @finished = true
        @ropeGroup.erase! if @ropeGroup.valid?

        @ropeGroup, buildNote = buildRope(points)
        length = RopeData.polyline_length(points)
        logReach(points)
        @ropeGroup.name = "Rope #{formatLength(length)}"
        RopeData.write(@ropeGroup, @initialPoints, @settings, length)
        @replace.erase! if @replace && @replace.valid?

        # select the new rope so Re-simulate can run again right away
        @model.selection.clear
        @model.selection.add(@ropeGroup)
        @model.select_tool nil if leaveTool

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
