# frozen_string_literal: true

module Cased
  module ControllerHelpers
    extend ActiveSupport::Concern

    included do
      before_action :cased_setup_request_context
      if respond_to?(:helper_method)
        helper_method :current_guard_session
        helper_method :guard_intent_options
      end
    end

    private

    def guard_required?
      true
    end

    # rescue_from JWT::VerificationError

    def verify_guarded
      raise 'Form tampered with' unless params['guard-token'].present?
    end

    def guarded(options = {})
      @guard_intent_options = options
    end

    # private key
    # reason required
    def guard_intent
      @guard_intent_options ||= {}

      intent = Cased::CLI::Sessions::Intent.new('x', @guard_intent_options)
      intent.generate
    end

    def current_guard_session
      @current_guard_session ||= Cased::CLI::Session.new(
        reason: params.dig(:guard_session, :reason),
        metadata: guard_session_metadata,
      )
    end

    def guard_session_params
      params.require(:guard_session).permit(:reason)
    end

    def guard_session_approved?
      guard_session_id = params.dig(:guard_session, :id)
      return false unless guard_session_id.present?

      session = Cased::CLI::Session.find(guard_session_id)
      session.approved?
    end

    def guard
      # TODO: Cancel previous session if not used
      return true unless guard_required?

      if guard_session_approved?
        Cased.context.merge(guard_session: current_guard_session)
        return true
      end

      if current_guard_session.create && current_guard_session.approved?
        Cased.context.merge(guard_session: current_guard_session)
        return true
      end

      render_guard
    end

    def guard_fallback_location
      if respond_to?(:root_path)
        root_path
      else
        '/'
      end
    end

    def render_guard
      respond_to do |format|
        format.html do
          render template: 'cased/cli/sessions/new', layout: 'cased/cli'
        end

        format.json do
          render json: { error: true }
        end
      end
    end

    def guard_session_metadata
      {
        location: request.remote_ip,
        request_http_method: request.method,
        request_user_agent: request.headers['User-Agent'],
        request_url: request.original_url,
        request_id: request.request_id,
      }
    end

    def cased_setup_request_context
      Cased.context.merge(cased_initial_request_context)
    end

    def cased_initial_request_context
      {
        location: request.remote_ip,
        request_http_method: request.method,
        request_user_agent: request.headers['User-Agent'],
        request_url: request.original_url,
        request_id: request.request_id,
      }
    end
  end
end
