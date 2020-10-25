# frozen_string_literal: true

require 'octokit'

module CookbookReleaseCreator
  # Used to handle calls to VCS
  class Vcs
    def initialize(token:, pull_request:, repository:, changelog_name: 'CHANGELOG.md')
      @client = Octokit::Client.new(access_token: token)
      @repository = repository
      @pull_request = pull_request
      @repository_name = repository['full_name']
      @changelog_name = changelog_name
      @default_branch = repository['default_branch']
      @metadata_name = 'metadata.rb'
      @comment_base = 'This has been released as'
    end

    def current_metadata_version
      file = get_file_contents(@metadata_name)
      response = file
      m = response['content'].match(/\n(version\s+'(\d+\.\d+\.\d+)')\n/m)
      if m
        response['full_string'] = m[1]
        response['version'] = m[2]
      else
        response['error'] = true
      end
      response
    end

    def update_metadata_version(version_metadata)
      new_version = version_metadata['new_version']
      current_version_string = version_metadata['full_string']
      new_version_string = current_version_string.gsub(version_metadata['version'], new_version)
      content = version_metadata['content'].gsub(current_version_string, new_version_string)
      update_file_contents(@metadata_name, "Update metadata for #{new_version}", version_metadata['sha'], content)
    end

    def unreleased_changelog_entry
      content = get_file_contents(@changelog_name)['content']
      result = /##\s+(Unreleased)([\s\S]*?)(\n##\s+\d+\.\d+\.\d+|\Z)/im.match(content)
      return result[2].strip if result

      nil
    end

    def create_changelog_entry(new_version)
      file = get_file_contents(@changelog_name)
      changelog_heading = "#{new_version} - *#{Time.now.strftime('%Y-%m-%d')}*"
      file['content'] = file['content'].gsub(/unreleased/i, changelog_heading)
      update_file_contents(@changelog_name, "Update changelog for #{new_version}", file['sha'], file['content'])
    end

    def create_release(new_version, release_body)
      @client.create_release(@repository_name, new_version, {
                               target_commitish: @default_branch,
                               name: new_version,
                               body: release_body
                             })
    end

    def add_release_comment(body)
      @client.add_comment(@repository_name,
                          @pull_request['number'],
                          body)
    end

    private

    def get_file_contents(file_path)
      file_content = @client.contents(@repository_name, path: file_path, ref: @default_branch)
      content = Base64.decode64(file_content[:content])
      response = {}
      response['content'] = content
      response['sha'] = file_content[:sha]
      response
    end

    def update_file_contents(file_path, commit_message, file_sha, file_content)
      begin
        @client.update_contents(@repository_name, file_path,
                                commit_message, file_sha, file_content, branch: @default_branch)
      rescue StandardError => e
        puts(e)
        return e
      end
      commit_message
    end
  end
end
