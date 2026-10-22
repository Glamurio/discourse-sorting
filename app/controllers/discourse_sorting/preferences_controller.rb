# frozen_string_literal: true

module DiscourseSorting
  # PUT /discourse-sorting/booru   enabled=true|false
  # Saves whether this account wants the booru view. Exposed to the client as
  # `currentUser.fluffy_booru` (true / false, or null until they have chosen).
  class PreferencesController < ::ApplicationController
    requires_plugin PLUGIN_NAME
    before_action :ensure_logged_in

    def update
      raise Discourse::InvalidParameters.new(:enabled) if !params.key?(:enabled)

      enabled = ActiveModel::Type::Boolean.new.cast(params[:enabled])
      raise Discourse::InvalidParameters.new(:enabled) if enabled.nil?

      current_user.custom_fields[BOORU_FIELD] = enabled
      current_user.save_custom_fields

      render json: success_json.merge(fluffy_booru: enabled)
    end
  end
end
