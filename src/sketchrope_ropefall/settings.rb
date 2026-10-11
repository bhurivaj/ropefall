# frozen_string_literal: true

require 'json'
require_relative 'rope_data'

module SKETCHROPE_ROPEFALL
  # Rope settings shared by the dialog, the simulation and the data stored on each rope (pure Ruby)
  module Settings
    PREF_SECTION = 'sketchrope_ropefall'
    DEFAULTS = {
      'length_mode' => 'percent',
      'length_percent' => 125.0,
      'length_fixed' => 39.37, # 1 m in inch
      'display' => 'line',
      'diameter' => 0.25,
      'sides' => 12,
      'smooth' => true,
      'material' => ''
    }.freeze
    MIN_PERCENT = 10
    MAX_PERCENT = 1000
    MIN_SIDES = 3
    MAX_SIDES = 48

    module_function

    # Defaults overlaid with the values of `hash` that have the right type; unknown keys are dropped
    def normalize(hash)
      result = DEFAULTS.dup
      return result unless hash.is_a?(Hash)

      DEFAULTS.each { |key, default| result[key] = hash[key] if same_type?(default, hash[key]) }
      %w[length_percent length_fixed diameter].each { |key| result[key] = result[key].to_f }
      result['sides'] = result['sides'].round
      result
    end

    def same_type?(default, value)
      case default
      when true, false then value == true || value == false
      when Numeric then value.is_a?(Numeric)
      else value.is_a?(String)
      end
    end

    def parse(json_text)
      return DEFAULTS.dup if json_text.to_s.strip.empty? # nothing saved yet

      normalize(JSON.parse(json_text.to_s))
    rescue JSON::ParserError
      puts 'Ropefall: settings could not be read, using defaults'
      DEFAULTS.dup
    end

    def load
      parse(Sketchup.read_default(PREF_SECTION, 'settings', ''))
    end

    def save(settings)
      Sketchup.write_default(PREF_SECTION, 'settings', JSON.generate(normalize(settings)))
    end

    def target_length(settings, points)
      return settings['length_fixed'].to_f if settings['length_mode'] == 'fixed'

      RopeData.polyline_length(points) * settings['length_percent'].to_f / 100.0
    end

    # Error messages (empty when the settings can be used); material is checked by the dialog
    def validate(settings, points)
      errors = []
      errors << 'Unknown length mode' unless %w[percent fixed].include?(settings['length_mode'])
      errors << 'Unknown display' unless %w[line tube].include?(settings['display'])
      if settings['length_mode'] == 'percent' && !settings['length_percent'].between?(MIN_PERCENT, MAX_PERCENT)
        errors << "Length must be between #{MIN_PERCENT}% and #{MAX_PERCENT}% of the polyline"
      end
      if settings['length_mode'] == 'fixed' && settings['length_fixed'] <= 0
        errors << 'Fixed length must be greater than 0'
      elsif settings['length_mode'] == 'fixed' &&
            settings['length_fixed'] > RopeData.polyline_length(points) * MAX_PERCENT / 100.0 + 1e-6
        errors << 'Fixed length must be at most 10 times the polyline length'
      end
      errors << 'Diameter must be greater than 0' unless settings['diameter'] > 0
      if settings['display'] == 'tube' && !settings['sides'].between?(MIN_SIDES, MAX_SIDES)
        errors << "Sides must be between #{MIN_SIDES} and #{MAX_SIDES}"
      end
      if errors.empty? && target_length(settings, points) < RopeData.distance(points.first, points.last) - 1e-6
        errors << 'Rope is shorter than the distance between its ends'
      end
      errors
    end
  end
end
