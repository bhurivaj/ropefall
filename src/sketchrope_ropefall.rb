#-------------------------------------------------------------------------------
#
# Balazs Torma, PhD
# ropefall [at] sketchrope [dot] com
# Copyright 2010-2016
#
#-------------------------------------------------------------------------------

require 'sketchup.rb'
require 'extensions.rb'

module SKETCHROPE_ROPEFALL

  unless file_loaded?( __FILE__ )   
    ### CONSTANTS ### ----------------------------------------------------------
    PLUGIN_NAME = 'Ropefall'.freeze
    VERSION    = '2.2.1'.freeze
    
    file = __FILE__.dup
    file.force_encoding("UTF-8") if file.respond_to?(:force_encoding)
    ROOT_PATH       = File.dirname( file ).freeze
    PATH            = File.join(ROOT_PATH, 'sketchrope_ropefall').freeze
    
    ### EXTENSION ### ----------------------------------------------------------
    PROXY_LOADER = File.join(PATH, 'cable').freeze
    
    @ex = SketchupExtension.new( PLUGIN_NAME, PROXY_LOADER )
    @ex.description = "Tool to model ropes, wires by physics simulation.\n\nhttps://github.com/bhurivaj/ropefall"
    @ex.version = VERSION
    @ex.copyright = 'Balazs Torma, PhD © 2016'
    @ex.creator = 'Balazs Torma, PhD (ropefall@sketchrope.com)'
    Sketchup.register_extension(@ex, true)
  end

end

file_loaded( __FILE__ )


