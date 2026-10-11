# frozen_string_literal: true

# Run (no SketchUp needed): ruby tests/tc_settings.rb
require 'minitest/autorun'
require 'json'
require_relative 'stub_sketchup'
require_relative '../src/sketchrope_ropefall/settings'

class TestSettings < Minitest::Test
  S = SKETCHROPE_ROPEFALL::Settings
  LINE = [[0, 0, 100], [100, 0, 100]].freeze # 100 inch apart, polyline length 100

  def setup
    Sketchup.prefs.clear
  end

  def valid(overrides = {})
    S.normalize(S::DEFAULTS.merge(overrides))
  end

  def test_defaults
    d = S::DEFAULTS
    assert_equal 'percent', d['length_mode']
    assert_equal 125.0, d['length_percent']
    assert_equal 'line', d['display']
    assert_equal 0.25, d['diameter']
    assert_equal 12, d['sides']
    assert_equal true, d['smooth']
    assert_equal '', d['material']
  end

  def test_normalize_keeps_good_values_and_drops_bad_types
    s = S.normalize('display' => 'tube', 'sides' => 'eight', 'smooth' => 'yes', 'diameter' => 1, 'extra' => 1)
    assert_equal 'tube', s['display']
    assert_equal 12, s['sides'], 'string for a number → default'
    assert_equal true, s['smooth'], 'string for a boolean → default'
    assert_equal 1.0, s['diameter']
    refute s.key?('extra'), 'unknown keys are dropped'
    assert_equal S::DEFAULTS, S.normalize(nil)
    assert_equal 9, S.normalize('sides' => 8.7)['sides'], 'sides rounded to an Integer'
  end

  def test_parse_handles_broken_json
    assert_output(/settings could not be read/) { assert_equal S::DEFAULTS, S.parse('not json') }
    assert_silent { assert_equal S::DEFAULTS, S.parse('[1,2]') }
    assert_silent { assert_equal S::DEFAULTS, S.parse(nil) }
    assert_silent { assert_equal S::DEFAULTS, S.parse('') }
    assert_equal 'tube', S.parse('{"display":"tube"}')['display']
  end

  def test_save_then_load
    S.save(valid('display' => 'tube', 'sides' => 8))
    loaded = S.load
    assert_equal 'tube', loaded['display']
    assert_equal 8, loaded['sides']
    assert_silent { assert_equal S::DEFAULTS, (Sketchup.prefs.clear && S.load), 'nothing saved → defaults' }
  end

  def test_target_length
    assert_in_delta 125.0, S.target_length(valid, LINE), 1e-9
    assert_in_delta 250.0, S.target_length(valid('length_percent' => 250), LINE), 1e-9
    assert_in_delta 80.0, S.target_length(valid('length_mode' => 'fixed', 'length_fixed' => 80), LINE), 1e-9
  end

  def test_validate_accepts_defaults
    assert_equal [], S.validate(valid, LINE)
  end

  def test_validate_rejects_each_bad_field
    assert_includes S.validate(valid('length_mode' => 'x'), LINE).join, 'length mode'
    assert_includes S.validate(valid('display' => 'x'), LINE).join, 'display'
    assert_includes S.validate(valid('length_percent' => 5), LINE).join, 'between 10% and 1000%'
    assert_includes S.validate(valid('length_percent' => 1001), LINE).join, 'between 10% and 1000%'
    assert_includes S.validate(valid('length_mode' => 'fixed', 'length_fixed' => 0), LINE).join, 'Fixed length'
    assert_includes S.validate(valid('diameter' => 0), LINE).join, 'Diameter'
    assert_includes S.validate(valid('display' => 'tube', 'sides' => 2), LINE).join, 'Sides'
    assert_includes S.validate(valid('display' => 'tube', 'sides' => 49), LINE).join, 'Sides'
  end

  def test_fixed_length_is_capped_at_ten_times_the_polyline
    assert_equal [], S.validate(valid('length_mode' => 'fixed', 'length_fixed' => 1000), LINE), 'exactly 10x is allowed'
    assert_includes S.validate(valid('length_mode' => 'fixed', 'length_fixed' => 1001), LINE).join,
                    'Fixed length must be at most 10 times the polyline length'
  end

  def test_sides_only_checked_for_tube
    assert_equal [], S.validate(valid('display' => 'line', 'sides' => 2), LINE)
  end

  def test_rope_shorter_than_its_ends_is_rejected
    short = valid('length_mode' => 'fixed', 'length_fixed' => 99)
    assert_includes S.validate(short, LINE).join, 'shorter than the distance between its ends'
    assert_includes S.validate(valid('length_percent' => 50), LINE).join, 'shorter than the distance'
    assert_equal [], S.validate(valid('length_mode' => 'fixed', 'length_fixed' => 100), LINE), 'exactly taut is allowed'
  end

  def test_saved_value_survives_read_default_evaluation
    S.save(valid('display' => 'tube', 'material' => 'Wood "Oak" ไม้'))
    stored = Sketchup.prefs.values.first
    refute_includes stored, '"', 'stored text must not contain double quotes'
    loaded = S.load
    assert_equal 'tube', loaded['display']
    assert_equal 'Wood "Oak" ไม้', loaded['material']
  end

  def test_unreadable_stored_value_falls_back_to_defaults
    Sketchup.write_default(S::PREF_SECTION, S::PREF_KEY, 'not base64 !!')
    assert_output(/settings could not be read/) { assert_equal S::DEFAULTS, S.load }
    Sketchup.write_default(S::PREF_SECTION, S::PREF_KEY, 'a"b')
    assert_output(/settings could not be read/) { assert_equal S::DEFAULTS, S.load }
  end

  def test_method_defaults_to_drape_and_is_validated
    assert_equal 'drape', S::DEFAULTS['method']
    assert_equal 'drape', S.normalize({})['method'], 'old ropes without method'
    assert_equal [], S.validate(valid('method' => 'catenary'), LINE)
    assert_includes S.validate(valid('method' => 'x'), LINE).join, 'Unknown method'
  end
end
