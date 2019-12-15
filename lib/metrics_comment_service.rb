# frozen_string_literal: true

require_relative './github_api'

class MetricsCommentService
  def self.execute(event_payload)
    return unless event_payload[:pull_request][:merged_at]

    pr_id = event_payload[:pull_request][:node_id]
    comment_metrics(
      pr_id,
      merge_time: collect_merge_time(event_payload),
      lead_times: collect_leadtimes(event_payload),
    )
  end

  def self.collect_merge_time(event_payload)
    repo = event_payload[:repository][:name]
    pr_number = event_payload[:pull_request][:number]
    owner = event_payload[:repository][:owner][:login]

    res = GitHubApi.query(
      GitHubApi::PullRequestCommitsWithAssociationsQuery,
      variables: { owner: owner, repo: repo, number: pr_number },
    )

    pr = res.data.repository.pull_request

    merged_at = Time.parse(event_payload[:pull_request][:merged_at]).getlocal
    first_committed_at = Time.parse(pr.commits.nodes.first.commit.committed_date).getlocal

    ActiveSupport::Duration.build(merged_at - first_committed_at)
  end

  def self.collect_leadtimes(event_payload)
    repo = event_payload[:repository][:name]
    pr_number = event_payload[:pull_request][:number]
    owner = event_payload[:repository][:owner][:login]
    merged_at = Time.parse(event_payload[:pull_request][:merged_at]).getlocal

    GitHubApi
      .enumerator(
        GitHubApi::PullRequestCommitsWithAssociationsQuery,
        page_info: ->(page) { page.data.repository.pull_request.commits.page_info },
        nodes: ->(page) { page.data.repository.pull_request.commits.nodes },
        variables: { owner: owner, repo: repo, number: pr_number },
      )
      .lazy
      .map { |commit| commit.commit.associated_pull_requests.nodes[0] }
      .uniq(&:number)
      .map do |pr|
        first_committed_at = Time.parse(pr.commits.nodes[0].commit.committed_date).getlocal

        {
          number: pr.number,
          title: pr.title,
          url: pr.url,
          leadtime: ActiveSupport::Duration.build(merged_at - first_committed_at),
        }
      end
      .to_a
  end

  def self.comment_metrics(pull_request_id, merge_time:, lead_times:)
    body = <<~MARKDOWN
      Elapsed time to merge: #{merge_time.inspect}

      #{lead_times.map { |time| "* #{time[:title]} / leadtime: #{time[:leadtime].inspect}" }.join("\n")}
    MARKDOWN

    GitHubApi.query(
      GitHubApi::AddCommentMutation,
      variables: { subject_id: pull_request_id, body: body },
    )
  end

  private_class_method :collect_merge_time, :comment_metrics
end
