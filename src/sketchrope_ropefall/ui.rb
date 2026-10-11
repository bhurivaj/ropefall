require 'sketchup.rb'
Sketchup::require 'sketchrope_ropefall/config'

module SKETCHROPE_ROPEFALL

@@anim = nil
@@operationOpen = false

class RopefallTool
    def initialize(initialPoints, config)
        @initialPoints = initialPoints
        @config = config
    end

    def activate
        SKETCHROPE_ROPEFALL::startFall(@initialPoints, @config)
    rescue StandardError => e
        SKETCHROPE_ROPEFALL::failFall(e)
    end

    def deactivate(view)
        SKETCHROPE_ROPEFALL::endFall(view)
    rescue StandardError => e
        puts "Ropefall: " + e.message
    end

    def onCancel(flag, view)
        SKETCHROPE_ROPEFALL::stopFall()
    rescue StandardError => e
        puts "Ropefall: " + e.message
    end    
    
    def reset()
        @initialPoints = nil
        @config = nil
    end
end

def self.createFallCommand()
    cmd = UI::Command.new("fall") {
        activateFall()
        }
    cmd.menu_text = SKETCHROPE_ROPEFALL::FALL
    
    return cmd
end

def self.activateFall()
    begin
        initialPoints = getInitialPointsFromSelection()
        
        if (initialPoints != nil)
            if (showConfigInputBox())
                Sketchup.active_model.select_tool RopefallTool.new(initialPoints, SKETCHROPE_ROPEFALL::config)
            end
        end
    rescue StandardError => e
        puts e.full_message
        UI.messagebox("Ropefall error:\n" + e.message)
    end
end

def self.intallCommands() 
 if not file_loaded?(__FILE__) 
    submenu = UI.menu("Draw").add_submenu(SKETCHROPE_ROPEFALL::ROPEFALL)
    
    submenu.add_item(createFallCommand())
 end
 
 file_loaded(__FILE__) 
end

def self.showConfigInputBox()
    prompts = ["Rope diameter:", "What to draw:"]
    defaults = [(SKETCHROPE_ROPEFALL::config().radius * 2).to_l, SKETCHROPE_ROPEFALL::config().whatToDraw]
    lists = ["", WhatToDraw::MIDLINE + "|" + WhatToDraw::TUBE]
    results = UI.inputbox prompts, defaults, lists, SKETCHROPE_ROPEFALL::ROPEFALL + " parameters"
    return false if not results        
    
    SKETCHROPE_ROPEFALL::config().radius = results[0] / 2
    SKETCHROPE_ROPEFALL::config().whatToDraw = results[1]
    
    return true
end

def self.startFall(initialPoints, config)     
    model.start_operation(SKETCHROPE_ROPEFALL::ROPEFALL, false, false, false)
    @@operationOpen = true
    @@anim = Anim.new(initialPoints, config) 
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
        view.animation = nil
        model.abort_operation
    else
        model.commit_operation
    end
    
    @@anim = nil
end

# abort_operation also removes the collision group and helper layer created during the fall
def self.failFall(error)
    puts error.full_message
    
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

def self.isInitialPointAboveBottom(initialPoints)
    modelBounds = SKETCHROPE_ROPEFALL::model.bounds
    bottom = modelBounds.min.z
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
