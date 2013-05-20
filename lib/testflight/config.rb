#--
# Copyright (c) 2012 Michael Berkovich
#
# Permission is hereby granted, free of charge, to any person obtaining
# a copy of this software and associated documentation files (the
# "Software"), to deal in the Software without restriction, including
# without limitation the rights to use, copy, modify, merge, publish,
# distribute, sublicense, and/or sell copies of the Software, and to
# permit persons to whom the Software is furnished to do so, subject to
# the following conditions:
#
# The above copyright notice and this permission notice shall be
# included in all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
# EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
# MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
# NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
# LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
# OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
# WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
#++

require 'fileutils'
require 'yaml'
require 'plist'

module Testflight
  class Config

    def self.path
      '.testflight'
    end

    ##################################################
    ## Configuration Attributes
    ##################################################

    def self.config
      @config ||= YAML::load(File.open(path)) 
    end

    def self.build
      config["build"]
    end

    def self.developer_name
      build["developer_name"]
    end

    def self.increment_bundle?
      build["increment_bundle"]
    end

    def self.sdk_version
      build["sdk"]
    end

    def self.git
      config["git"]
    end

    def self.commit_changes?
      git["commit_changes"]
    end

    def self.tag_build?
      git["tag_build"]
    end

    def self.testflight
      config["testflight"]
    end

    def self.distribution_lists
      testflight["distribution_lists"]
    end

    def self.api_token
      testflight["api_token"]
    end

    def self.team_token
      testflight["team_token"]
    end

    ##################################################
    ## Helper Methods
    ##################################################

    def self.project_dir
      Dir.pwd
    end

    def self.project_files 
      @project_files ||= Dir.entries(project_dir)
    end

    def self.file_name_by_ext(ext)
      project_files.select{|file| file.match(/#{ext}$/)}.first
    end

    def self.workspace_name
      @workspace_name ||= file_name_by_ext('xcworkspace')
    end

    def self.project_name
      @project_name ||= file_name_by_ext('xcodeproj')
    end

    def self.type
      return "unknown" if workspace_name.nil? and project_name.nil?
      @type ||= workspace_name ? 'workspace' : 'project'
    end

    def self.workspace?
      type == "workspace"
    end

    def self.project?
      type == "project"
    end

    def self.application_name
      @application_name ||= begin
        name = workspace_name || project_name
        name = name.split(".")[0..-2].join(".") if name
        name
      end  
    end

    def self.build_dir
      "#{project_dir}/build"
    end

    def self.provisioning_dir
      "#{project_dir}/Provisioning"
    end

    def self.distributions_dir
      "#{project_dir}/Distributions"
    end

    def self.ad_hoc_provisioning_name
      @ad_hoc_provisioning_name ||= begin
        files = Dir.entries(provisioning_dir)
        files.select{|file| file.match(/mobileprovision$/)}.first
      end
    end

    def self.distribution_file
      "#{distributions_dir}/#{application_name}_#{project_version_short}.ipa"
    end

    def self.project_info_file_name
      "#{application_name}-Info.plist"
    end

    def self.project_info_path
      files = Dir["**/#{project_info_file_name}"]
      return nil if files.empty? 
      files.first
    end

    def self.project_info
      @project_info ||= Plist::parse_xml(project_info_path)
    end

    def self.version
      project_info["CFBundleShortVersionString"]
    end

    def self.build_number
      project_info["CFBundleVersion"]
    end

    def self.project_version
      "#{version} (#{build_number})"
    end

    def self.project_version_short
      "#{version}.#{build_number}"
    end

  end
end
