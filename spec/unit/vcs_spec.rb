# frozen_string_literal: true

require 'spec_helper'

describe CookbookReleaseCreator::Vcs, :vcr do
  # Check Vcs creates an OctoKit client
  before(:each) do
    @client = CookbookReleaseCreator::Vcs.new({
                                        token: ENV['GITHUB_TOKEN'] || 'temp_token',
                                        pull_request: {'number' => 30},
                                        repository: {
                                          'full_name' => 'Xorima/xor_test_cookbook', 'default_branch' => 'master'
                                        }
                                      })
  end

  it 'creates an octkit client' do
    expect(@client).to be_kind_of(CookbookReleaseCreator::Vcs)
  end

  it 'returns the version number from metadata.rb' do
    result = @client.current_metadata_version
    expect(result['version']).to eq '3.2.0'
  end

  it 'updates the metadata.rb with the new version number' do
    result = @client.current_metadata_version
    result['new_version'] = '3.5.999'
    updated_version = @client.update_metadata_version(result)
    expect(updated_version).to eq 'Update metadata for 3.5.999'
  end

  it 'returns the unreleased section from the changelog' do
    expect(@client.unreleased_changelog_entry).to eq "- Added 'Testing stuff'"
  end

  it 'updates the changelog as expected' do
    expect(@client.create_changelog_entry('1.2.3')).to eq 'Update changelog for 1.2.3'
  end

  it 'creates a release' do
    body = '- this is my body'
    version = '3.9999.9999'
    release = @client.create_release(version, body)
    expect(release['tag_name']).to eq version
    expect(release['body']).to eq body
  end

  it 'comments on the closed pr with the release number' do
    body = 'This is my comment'
    comment = @client.add_release_comment(body)
    expect(comment['body']).to eq body
  end
end
