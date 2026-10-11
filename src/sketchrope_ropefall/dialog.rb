# frozen_string_literal: true

require 'json'
require_relative 'settings'

module SKETCHROPE_ROPEFALL
  # Settings window shown before every Fall / Re-simulate
  module SettingsDialog
    class << self
      def open(settings, points, &on_start)
        @dialog.close if @dialog && @dialog.visible?
        @settings = Settings.normalize(settings)
        @points = points
        @on_start = on_start
        @dialog = create_dialog
        @dialog.show
      end

      private

      def create_dialog
        dialog = UI::HtmlDialog.new(
          dialog_title: 'Ropefall',
          preferences_key: 'sketchrope_ropefall_dialog',
          width: 380, height: 545, resizable: false,
          style: UI::HtmlDialog::STYLE_DIALOG
        )
        dialog.set_file(File.join(PATH, 'dialog.html'))
        dialog.add_action_callback('ready') { |_ctx| guard { send_state } }
        dialog.add_action_callback('start') { |_ctx, json| guard { start(json) } }
        dialog.add_action_callback('cancel') { |_ctx| guard { @dialog.close } }
        dialog
      end

      def guard
        yield
      rescue StandardError => e
        puts "Ropefall dialog: #{e.class}: #{e.message}"
        js("ropefall.errors(#{JSON.generate([e.message])})")
      end

      def material_names
        Sketchup.active_model.materials.map(&:name).sort_by(&:downcase)
      end

      def send_state
        names = material_names
        s = @settings
        length_fixed_str = Sketchup.format_length(s['length_fixed'])
        diameter_str = Sketchup.format_length(s['diameter'])
        @shown = {
          'length_fixed' => length_fixed_str,
          'diameter' => diameter_str
        }
        state = {
          'method' => s['method'],
          'length_mode' => s['length_mode'], 'length_percent' => s['length_percent'],
          'length_fixed' => length_fixed_str,
          'display' => s['display'], 'diameter' => diameter_str,
          'sides' => s['sides'], 'smooth' => s['smooth'],
          'material' => names.include?(s['material']) ? s['material'] : '',
          'materials' => names,
          'polyline_length' => Sketchup.format_length(RopeData.polyline_length(@points))
        }
        js("ropefall.init(#{JSON.generate(state)})")
      end

      def start(json)
        @form = JSON.parse(json.to_s)
        errors = []
        # Only parse length_fixed if in fixed mode; otherwise keep current value
        length_fixed = if @form['length_mode'] == 'fixed'
                         length_from_form('length_fixed', 'fixed length', errors)
                       else
                         @settings['length_fixed']
                       end
        diameter = length_from_form('diameter', 'diameter', errors)
        settings = Settings.normalize(
          'method' => @form['method'],
          'length_mode' => @form['length_mode'], 'length_percent' => @form['length_percent'].to_f,
          'length_fixed' => length_fixed,
          'display' => @form['display'], 'diameter' => diameter,
          'sides' => @form['sides'].to_i, 'smooth' => @form['smooth'] == true, 'material' => @form['material'].to_s
        )
        unless settings['material'].empty? || Sketchup.active_model.materials[settings['material']]
          errors << "Material not found: #{settings['material']}"
        end
        errors.concat(Settings.validate(settings, @points)) if errors.empty?
        return js("ropefall.errors(#{JSON.generate(errors)})") unless errors.empty?

        Settings.save(settings)
        @dialog.close
        @on_start.call(settings)
      end

      # Parse length from form, preserving exact value if field unchanged from display
      def length_from_form(key, label, errors)
        text = @form[key].to_s
        return @settings[key] if @shown && @shown[key] == text

        text.to_l.to_f
      rescue ArgumentError
        errors << "Invalid #{label}: #{text}"
        @settings[key]
      end

      def js(code)
        @dialog.execute_script(code) if @dialog && @dialog.visible?
      end
    end
  end
end
