# frozen_string_literal: true

require_relative './github_api'

class MetricsCommentService
  def self.execute(event_payload)
    return unless event_payload[:pull_request][:merged_at]

    pr_id = event_payload[:pull_request][:node_id]
    comment_metrics(pr_id, collect_merge_time(event_payload))
  end

  def self.collect_merge_time(event_payload)
    login = event_payload[:repository][:owner][:login]
    repo = event_payload[:repository][:name]
    pr_number = event_payload[:pull_request][:number]

    res = GitHubApi.query(
      GitHubApi::PullRequestWithFirstCommitQuery,
      variables: { login: login, repo: repo, number: pr_number },
    )
    p res
    pr = res.data.viewer.organization.repository.pull_request

    merged_at = Time.parse(event_payload[:pull_request][:merged_at]).getlocal
    first_committed_at = pr.commits.nodes.first.commit.committed_date

    (merged_at - first_committed_at) / 3600
  end

  def self.comment_metrics(pull_request_id, merge_time)
    body = "Elapsed time to merge: #{merge_time} hours"

    GitHubApi.query(
      GitHubApi::AddCommentMutation,
      variables: { subject_id: pull_request_id, body: body },
    )
  end

  private_class_method :collect_merge_time, :comment_metrics
end
