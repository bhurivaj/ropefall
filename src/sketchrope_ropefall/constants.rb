require "sketchup.rb"

module SKETCHROPE_ROPEFALL

EPSILON ||= 0.0001
ROPEFALL ||= "Ropefall"
FALL ||= "Fall"

def self.identityTrans()
	t = Geom::Transformation.new
end

@@minMoveDelta = 0.3.mm
@@maxRot = 20 * Math::PI / 180 
@@noRopePoints = 100
@@massPointMass = 0.4 / @@noRopePoints
@@springConstant = 0.6
@@springFrictionConstant = 0.02
@@surfaceFrictionConstant = 0.2
@@torsionSpringConstant = 1
@@generalFrictionConstant = 0.85
@@dt = 0.025
@@facesWarnThreshold = 20000

def self.model()
    return Sketchup.active_model
end

def self.entities()
   return Sketchup.active_model.entities 
end

def self.selection()
   return Sketchup.active_model.selection 
end

def self.minMoveDelta()
    return @@minMoveDelta
end

def self.maxRot()
    return @@maxRot
end

def self.noRopePoints
    return @@noRopePoints
end

def self.massPointMass
    return @@massPointMass
end

def self.springConstant
    return @@springConstant
end

def self.springFrictionConstant
    return @@springFrictionConstant
end

def self.surfaceFrictionConstant
    return @@surfaceFrictionConstant
end

def self.torsionSpringConstant
    return @@torsionSpringConstant
end

def self.generalFrictionConstant
    return @@generalFrictionConstant
end

def self.dt
    return @@dt
end

def self.facesWarnThreshold
    return @@facesWarnThreshold
end

end

