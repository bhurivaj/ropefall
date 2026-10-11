require 'sketchup.rb'

Sketchup::require 'sketchrope_ropefall/constants'
Sketchup::require 'sketchrope_ropefall/util'
Sketchup::require 'sketchrope_ropefall/grid'
Sketchup::require 'sketchrope_ropefall/model'
Sketchup::require 'sketchrope_ropefall/config'
require_relative 'rope_data'
require_relative 'settings'
require_relative 'dialog'
Sketchup::require 'sketchrope_ropefall/anim'
Sketchup::require 'sketchrope_ropefall/ui'

module SKETCHROPE_ROPEFALL

def self.run()
    intallCommands() 
end

end

SKETCHROPE_ROPEFALL.run()

