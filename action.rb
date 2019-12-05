# frozen_string_literal: true

require 'active_support'
require 'active_support/all'

require_relative './lib/metrics_comment_service'

event_payload = JSON.parse(File.read(ENV['GITHUB_EVENT_PATH']), symbolize_names: true)

MetricsCommentService.execute(event_payload)
