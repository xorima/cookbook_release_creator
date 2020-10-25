# frozen_string_literal: true

require 'sinatra'

require_relative 'cookbookreleasecreator/semver'
require_relative 'cookbookreleasecreator/vcs'
require_relative 'cookbookreleasecreator/hmac'

get '/' do
  'Alive'
end

post '/handler' do
  return halt 500, "Signatures didn't match!" unless validate_request(request)

  payload = JSON.parse(params[:payload])
  case request.env['HTTP_X_GITHUB_EVENT']
  when 'pull_request'
    if target_default_branch?(payload) && merged_webhook?(payload)
      vcs = CookbookReleaseCreator::Vcs.new(token: ENV['GITHUB_TOKEN'], pull_request: payload['pull_request'],
                                            repository: payload['repository'])
      semver = CookbookReleaseCreator::SemVer.new(pull_request: payload['pull_request'])

      version_metadata = vcs.current_metadata_version
      return halt 500, 'Error finding version number!' if version_metadata['error']

      version_metadata['new_version'] = semver.increment_release(version_metadata['version'])
      release_body = vcs.unreleased_changelog_entry
      vcs.create_changelog_entry(version_metadata['new_version'])
      vcs.update_metadata_version(version_metadata)

      rel = vcs.create_release(version_metadata['new_version'], release_body)
      vcs.add_release_comment("Released as: [#{version_metadata['new_version']}](#{rel['html_url']})")
      rel['tag_name']
    end
  end
end

def validate_request(request)
  true unless ENV['SECRET_TOKEN']
  request.body.rewind
  payload_body = request.body.read
  verify_signature(payload_body)
end

def merged_webhook?(payload)
  return true if payload['action'] == 'closed' && payload['pull_request']['merged']

  false
end

def target_default_branch?(payload)
  return true if payload['pull_request']['base']['ref'] == payload['repository']['default_branch']

  false
end
