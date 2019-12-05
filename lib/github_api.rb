# frozen_string_literal: true

require 'graphql/client'
require 'graphql/client/http'

module GitHubApi
  HTTP = GraphQL::Client::HTTP.new('https://api.github.com/graphql') do
    def headers(_)
      {
        'Authorization' => "Bearer #{ENV['GITHUB_TOKEN']}",
      }
    end

    def connection
      Net::HTTP.new(uri.host, uri.port).tap do |client|
        client.use_ssl = uri.scheme == 'https'
        client.max_retries = 3
      end
    end
  end

  Schema = GraphQL::Client.load_schema(HTTP)
  Client = GraphQL::Client.new(schema: Schema, execute: HTTP)

  PullRequestWithFirstCommitQuery = GitHubApi::Client.parse <<~GRAPHQL
    query($login: String!, $repo: String!, $number: Int!) {
      viewer {
        organization(login: $login) {
          repository(name: $repo) {
            pullRequest(number: $number) {
              commits(first: 1) {
                nodes {
                  commit {
                    committedDate
                  }
                }
              }
            }
          }
        }
      }
    }
  GRAPHQL

  AddCommentMutation = GitHubApi::Client.parse <<~GRAPHQL
    mutation($subjectId: ID!, $body: String!) {
      addComment(input: { subjectId: $subjectId, body: $body }) {
        commentEdge {
          node {
            body
          }
        }
      }
    }
  GRAPHQL

  def self.query(query, **params)
    res = GitHubApi::Client.query(query, **params)
    raise "GraphQLError: #{res.errors.inspect}" if res.errors&.messages&.present?

    res
  end

  def self.enumerator(query, page_info:, nodes:, **params)
    after = nil

    Enumerator.new do |yielder|
      loop do
        page = query(query, **params.with_defaults(variables: { after: after }))

        nodes.call(page).each do |item|
          yielder << item
        end

        info = page_info.call(page)
        break unless info.has_next_page

        after = info.end_cursor
      end
    end
  end
end
