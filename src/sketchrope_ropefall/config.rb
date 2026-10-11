require 'sketchup.rb'

module SKETCHROPE_ROPEFALL

def self.config()
    return @@config
end

class Config
    attr_accessor :minMoveDelta
    attr_accessor :noRopePoints
    attr_accessor :massPointMass
    attr_accessor :springConstant
    attr_accessor :springFrictionConstant
    attr_accessor :surfaceFrictionConstant
    attr_accessor :torsionSpringConstant
    attr_accessor :generalFrictionConstant
    attr_accessor :animIterCount
    attr_accessor :minAnimIterCount
    attr_accessor :dt

    def initialize()
        @animIterCount = 800
        @minAnimIterCount = 100
        @minMoveDelta = SKETCHROPE_ROPEFALL::minMoveDelta
        @noRopePoints = SKETCHROPE_ROPEFALL::noRopePoints
        @massPointMass = SKETCHROPE_ROPEFALL::massPointMass
        @springConstant = SKETCHROPE_ROPEFALL::springConstant
        @springFrictionConstant = SKETCHROPE_ROPEFALL::springFrictionConstant
        @surfaceFrictionConstant = SKETCHROPE_ROPEFALL::surfaceFrictionConstant
        @torsionSpringConstant = SKETCHROPE_ROPEFALL::torsionSpringConstant
        @generalFrictionConstant = SKETCHROPE_ROPEFALL::generalFrictionConstant
        @dt = SKETCHROPE_ROPEFALL::dt
    end
        
end

@@config = Config.new

end
