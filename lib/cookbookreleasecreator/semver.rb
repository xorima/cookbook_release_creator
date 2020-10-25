# frozen_string_literal: true

require 'semantic'

module CookbookReleaseCreator
  # Used to handle calls to VCS
  class SemVer
    def initialize(pull_request:)
      @pull_request = pull_request
      @label = release_label
      @increment_by = increment_by
    end

    def increment_release(semver_release)
      rel = Semantic::Version.new(semver_release)
      rel.increment!(@increment_by).to_s
    end

    protected

    def release_label
      release_labels = @pull_request['labels'].select { |l| l['name'] =~ /^release:\s(major|minor|patch)/i }
      release_labels[0]['name']
    end

    def increment_by
      inc = /(major|minor|patch)/i.match(@label)
      inc[1].downcase.to_sym
    end
  end
end
