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
require 'pp'
require 'plist'

module Testflight
  class Config

    def self.path
      '.testflight'
    end

    def self.defaults
      {
        "build"       => {
          "developer_name"      => "As it appears in your Apple certificate",
          "increment_bundle"    => true,
          "commit_changes"      => true
        },
        "testflight"  => {
          "api_token"           => "Get it from https://testflightapp.com/account/#api",
          "team_token"          => "Get it from https://testflightapp.com/dashboard/team/edit/",
          "distribution_lists"  => [""]
        }
      }
    end

    def self.config
      @config ||= begin
        if File.exist?(path) 
          YAML::load(File.open(path)) 
        else
          File.open(path, "w") do |f| 
            f.write(defaults.to_yaml) 
          end
          raise "Please update #{path} with all necessary properties."
        end
      end
    end

    def self.commit_changes?
      config["build"]["commit_changes"]
    end

    def self.increment_bundle?
      config["build"]["increment_bundle"]
    end

    def self.developer_name
      config["build"]["developer_name"]
    end

    def self.distribution_lists
      config["testflight"]["distribution_lists"]
    end

    def self.api_token
      config["testflight"]["api_token"]
    end

    def self.team_token
      config["testflight"]["team_token"]
    end

    def self.valid?
      return false unless config
      return false if config.empty?
      return false if config["build"].nil? 
      return false if config["build"]["developer_name"].nil?
      return false if config["testflight"].nil? 
      return false if config["testflight"]["api_token"].nil?
      return false if config["testflight"]["team_token"].nil?
      return false if config["testflight"]["distribution_lists"].nil?
      true
    end

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
      "#{distributions_dir}/#{application_name}.ipa"
    end

    def self.setup
      unless application_name
        pp "This folder does not contain an xCode project or a workspace."
        exit 1
      end

      unless valid?
        pp "Ensure that you have provided all of the information in the #{config_file} config file"
        exit 1
      end

      unless project_files.include?("Distributions")
        FileUtils.mkdir("Distributions")
        @project_files = nil
      end

      unless project_files.include?("Provisioning")
        FileUtils.mkdir("Provisioning")
        @project_files = nil
      end

      unless ad_hoc_provisioning_name
        pp "Please copy your Ad Hoc Provisioning Profile into the provisioning folder."
        exit 1
      end
    end

    def self.project_info_path
      files = Dir["**/#{application_name}-Info.plist"]
      if files.empty?
        pp "Cannot locate #{application_name}-Info.plist file. Please make sure such file exists in your project."
        exit 1
      end
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
