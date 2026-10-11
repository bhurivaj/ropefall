# frozen_string_literal: true

# Minimal stub of the SketchUp API used by the pure Ropefall files (tests run with plain ruby)
module Sketchup
  class << self
    def prefs
      @prefs ||= {}
    end

    # Like SketchUp on macOS: a stored String is evaluated as a Ruby string literal on read,
    # so a value containing double quotes raises SyntaxError
    def read_default(section, key, default = nil)
      return default unless prefs.key?([section, key])

      value = prefs[[section, key]]
      value.is_a?(String) ? eval("\"#{value}\"") : value # rubocop:disable Security/Eval
    end

    def write_default(section, key, value)
      prefs[[section, key]] = value
      true
    end
  end
end

# Stand-in for Sketchup::Group attribute storage
class FakeGroup
  def initialize
    @attrs = {}
  end

  def set_attribute(dict, key, value)
    @attrs[[dict, key]] = value
  end

  def get_attribute(dict, key, default = nil)
    @attrs.fetch([dict, key], default)
  end
end
