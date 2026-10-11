require 'sketchup.rb'
Sketchup::require 'sketchrope_ropefall/config'

module SKETCHROPE_ROPEFALL

@@anim = nil
@@operationOpen = false

class RopefallTool
    def initialize(initialPoints, settings, replace = nil)
        @initialPoints = initialPoints
        @settings = settings
        @replace = replace
    end

    def activate
        SKETCHROPE_ROPEFALL::startFall(@initialPoints, @settings, @replace)
    rescue StandardError => e
        SKETCHROPE_ROPEFALL::failFall(e)
    end

    def deactivate(view)
        SKETCHROPE_ROPEFALL::endFall(view)
    rescue StandardError => e
        puts "Ropefall: " + e.message
    end

    # Esc: stop and keep the current shape
    def onCancel(flag, view)
        SKETCHROPE_ROPEFALL::stopFall()
    rescue StandardError => e
        puts "Ropefall: " + e.message
    end

    # Enter: same as Esc
    def onReturn(view)
        SKETCHROPE_ROPEFALL::stopFall()
    rescue StandardError => e
        puts "Ropefall: " + e.message
    end

    def reset()
        @initialPoints = @settings = @replace = nil
    end
end

def self.iconPath(name, size)
    File.join(PATH, 'icons', "#{name}_#{size}.png")
end

def self.createFallCommand()
    cmd = UI::Command.new("Fall…") {
        activateFall()
        }
    cmd.tooltip = "Fall"
    cmd.status_bar_text = "Simulate a rope falling from the selected polyline"
    cmd.small_icon = iconPath('fall', 16)
    cmd.large_icon = iconPath('fall', 24)

    return cmd
end

def self.createResimulateCommand()
    cmd = UI::Command.new("Re-simulate…") {
        activateResimulate()
        }
    cmd.tooltip = "Re-simulate"
    cmd.status_bar_text = "Simulate the selected rope again with new settings"
    cmd.small_icon = iconPath('resimulate', 16)
    cmd.large_icon = iconPath('resimulate', 24)
    cmd.set_validation_proc {
        begin
            selectedRope() ? MF_ENABLED : MF_GRAYED
        rescue StandardError
            MF_GRAYED
        end
    }

    return cmd
end

def self.activateFall()
    initialPoints = getInitialPointsFromSelection()
    return if initialPoints.nil?

    SettingsDialog.open(Settings.load, initialPoints) { |settings|
        Sketchup.active_model.select_tool RopefallTool.new(initialPoints, settings)
    }
rescue StandardError => e
    puts e.full_message
    UI.messagebox("Ropefall error:\n" + e.message)
end

# [group, data] for a single selected rope created by Ropefall 2.1+, otherwise nil
def self.selectedRope()
    selection = Sketchup.active_model.selection
    return nil unless selection.size == 1 && selection.first.is_a?(Sketchup::Group)

    data = RopeData.read(selection.first)
    return data ? [selection.first, data] : nil
end

def self.activateResimulate()
    group, data = selectedRope()
    if (group.nil?)
        UI.messagebox("Please select one rope created by Ropefall 2.1 or later.")
        return
    end

    # stored in the coordinates the rope had when created (top level, identity); follow moves / copies
    points = data['points'].map{|p| Geom::Point3d.new(*p).transform(group.transformation)}
    if (!isInitialPointAboveBottom(points, group))
        UI.messagebox("Initial polyline must be above the bottom of the model!")
        return
    end

    SettingsDialog.open(Settings.normalize(data['settings']), points) { |settings|
        Sketchup.active_model.select_tool RopefallTool.new(points, settings, group)
    }
rescue StandardError => e
    puts e.full_message
    UI.messagebox("Ropefall error:\n" + e.message)
end

def self.intallCommands()
 if not file_loaded?(__FILE__)
    fall = createFallCommand()
    resimulate = createResimulateCommand()

    submenu = UI.menu("Extensions").add_submenu(SKETCHROPE_ROPEFALL::ROPEFALL)
    submenu.add_item(fall)
    submenu.add_item(resimulate)

    toolbar = UI::Toolbar.new(SKETCHROPE_ROPEFALL::ROPEFALL)
    toolbar.add_item(fall)
    toolbar.add_item(resimulate)
    toolbar.get_last_state == TB_NEVER_SHOWN ? toolbar.show : toolbar.restore
 end

 file_loaded(__FILE__)
end

def self.startFall(initialPoints, settings, replace)
    model.start_operation(SKETCHROPE_ROPEFALL::ROPEFALL, false, false, false)
    @@operationOpen = true
    @@anim = Anim.new(initialPoints, settings, replace)
    model.active_view.animation = @@anim
end

def self.stopFall()
    if (@@anim != nil)
        @@anim.stop()
    end
end

# called when the tool is deactivated: keep the finished rope, or discard
# everything if the user switched to another tool while the rope was falling
def self.endFall(view)
    return if !@@operationOpen
    @@operationOpen = false

    if (@@anim != nil && !@@anim.finished)
        @@anim.cancel
        view.animation = nil
        model.abort_operation
    else
        model.commit_operation
    end

    @@anim = nil
end

# abort_operation also removes everything the fall added to the model
def self.failFall(error)
    puts error.full_message

    @@anim.cancel if @@anim
    if (@@operationOpen)
        @@operationOpen = false
        model.abort_operation
    end

    @@anim = nil
    # leave the tool after the current callback has returned
    UI.start_timer(0, false) { model.select_tool(nil) }
    UI.messagebox("Ropefall stopped:\n" + error.message)
end

def self.getInitialPointsFromSelection()
    initialPoints = SKETCHROPE_ROPEFALL::sortSelection()

    if (initialPoints == nil || initialPoints.length < 2)
        UI.messagebox("Please create an open polyline and then select it!")

        return nil
    end

    if (!isInitialPointAboveBottom(initialPoints))
        UI.messagebox("Initial polyline must be above the bottom of the model!")

        return nil
    end

    return initialPoints
end

def self.isInitialPointAboveBottom(initialPoints, skip = nil)
    bottom = SKETCHROPE_ROPEFALL::modelBottom(skip)
    initialPoints.each{|p|
        if (p.z <= bottom + EPSILON)
            return false
        end
    }

    return true
end

def self.addOrRemoveEndpoint(endpoints, p)
    if (endpoints.include?(p))
        endpoints.delete(p)
    else
        endpoints << p
    end
end

def self.printEdge(e)
    puts "start = " + e.start.position.to_s + ", end = " + e.end.position.to_s
end

end
