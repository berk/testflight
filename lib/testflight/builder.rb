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

require 'appscript'
require 'yaml'

module Testflight
  class Builder

    XCODE_BUILDER       = "/usr/bin/xcodebuild"
    XCODE_PACKAGER      = "/usr/bin/xcrun"
    TESTFLIGHT_ENDPOINT = "http://testflightapp.com/api/builds.json"

    include Appscript

    def initialize(opts = {})
      t0 = Time.now

      if Testflight::Config.commit_changes?
        commit_changes(opts)
      end

      if Testflight::Config.tag_build?
        tag_build(opts)
      end

      if Testflight::Config.workspace?
        build_workspace(opts)
        package_workspace(opts)
      else
        build_project(opts)
        package_project(opts)
      end

      package_dSYM(opts)

      upload_to_testflightapp(opts)

      append_log_entry(opts)

      if Testflight::Config.increment_bundle?
        increment_bundle_version(opts)
        if Testflight::Config.commit_changes?
          commit_changes(opts.merge(:message => "Incrementing build number to #{Testflight::Config.project_version}"))
        end
      end

      t1 = Time.now

      puts("Build took #{t1-t0} seconds.")
    end

    ####################################################################################
    ## Building Project
    ####################################################################################

    def build_workspace(opts = {})
      cmd = "#{XCODE_BUILDER} -workspace '#{Testflight::Config.workspace_name}' "
      cmd << "-scheme '#{Testflight::Config.application_name}' "
      cmd << "-sdk '#{Testflight::Config.sdk_version}' "
      cmd << "-configuration 'AdHoc' "
      cmd << "-arch 'armv6 armv7' "
      cmd << "CONFIGURATION_BUILD_DIR='#{Testflight::Config.build_dir}' "
      execute(cmd, opts)
    end

    def build_project(opts = {})
      cmd = "#{XCODE_BUILDER} -target '#{Testflight::Config.application_name}' "
      cmd << "-sdk 'iphoneos6.0' "
      cmd << "-configuration 'AdHoc' "
      execute(cmd, opts)
    end

    ####################################################################################
    ## Packaging Project
    ####################################################################################

    def package_workspace(opts = {})
      cmd = "#{XCODE_PACKAGER} -sdk iphoneos PackageApplication "
      cmd << "-v '#{Testflight::Config.build_dir}/#{Testflight::Config.build_name}.app' "
      cmd << "-o '#{Testflight::Config.distribution_file}' "
      cmd << "--sign '#{Testflight::Config.developer_name}' "
      cmd << "--embed '#{Testflight::Config.provisioning_dir}/#{Testflight::Config.ad_hoc_provisioning_name}'"
      execute(cmd, opts)
    end

    def package_project(opts = {})
      cmd = "#{XCODE_PACKAGER} -sdk iphoneos PackageApplication "
      cmd << "-v '#{Testflight::Config.build_dir}/AdHoc-iphoneos/#{Testflight::Config.application_name}.app' "
      cmd << "-o '#{Testflight::Config.distribution_file}' "
      cmd << "--sign '#{Testflight::Config.developer_name}' "
      cmd << "--embed '#{Testflight::Config.provisioning_dir}/#{Testflight::Config.ad_hoc_provisioning_name}'"
      execute(cmd, opts)
    end

    def package_dSYM(opts = {})
      cmd = "zip -r '#{Testflight::Config.build_dir}/#{Testflight::Config.build_name}.app.dSYM.zip' '#{Testflight::Config.build_dir}/#{Testflight::Config.build_name}.app.dSYM'"
      execute(cmd, opts)
    end

    ####################################################################################
    ## Uploading Project
    ####################################################################################

    def upload_to_testflightapp(opts = {})
      cmd = "curl #{TESTFLIGHT_ENDPOINT} "
      cmd << "-F file=@#{Testflight::Config.distribution_file} "
      cmd << "-F dsym=@#{Testflight::Config.build_dir}/#{Testflight::Config.build_name}.app.dSYM.zip "
      cmd << "-F api_token=#{Testflight::Config.api_token} "
      cmd << "-F team_token=#{Testflight::Config.team_token} "
      cmd << "-F notify=#{opts[:notify]} "
      cmd << "-F distribution_lists=#{opts[:teams].join(",")} "
      cmd << "-F notes='#{opts[:message]}'"
      execute(cmd, opts)
    end

    ####################################################################################
    ## Project Versioning
    ####################################################################################

    def increment_bundle_version(opts = {})
      # Check if build numbers are numeric
      build_number = Testflight::Config.build_number.to_i
      build_number += 1

      puts("\r\nIncrementing build number to #{build_number}...")

      return if opts[:cold]
      Testflight::Config.project_info["CFBundleVersion"] = build_number.to_s

      File.open(Testflight::Config.project_info_path, "w") do |f|
        f.write(Testflight::Config.project_info.to_plist)
      end
    end

    ####################################################################################
    ## Git Support
    ####################################################################################
    def commit_changes(opts = {})
      execute("git add .", opts.merge(:ignore_result => true))
      execute("git add . --update", opts.merge(:ignore_result => true))
      execute("git commit -m '#{opts[:message]}'", opts.merge(:ignore_result => true))
      execute("git push", opts.merge(:ignore_result => true))
    end

    def tag_build(opts = {})
      execute("git tag -a #{Testflight::Config.project_version_short} -m 'Release #{Testflight::Config.project_version}'", opts.merge(:ignore_result => true))
    end

    ####################################################################################
    ## FlightLog Support
    ####################################################################################
    def append_log_entry(opts)
      lines = []
      lines << "#{Testflight::Config.application_name} #{Testflight::Config.project_version}"
      lines << "Deplyed On: #{Time.now}"
      lines << "Distributed To: #{opts[:teams].join(", ")}"
      lines << "Notified By Email: #{opts[:notify]}"
      lines << "Notes: #{opts[:message]}"
      lines << "---------------------------------------------------------------------------"

      log = "FLIGHTLOG"
      tmp = log + "~"

      File.open(tmp, "w") do |newfile|
        lines.each do |line|
          newfile.puts(line)
        end

        if File.exist?(log)
          File.open(log, "r+") do |oldfile|
            oldfile.each_line do |line|
              newfile.puts(line)
            end
          end
        end
      end

      File.delete(log) if File.exist?(log)
      File.rename(tmp, log)
    end

    ####################################################################################
    ## Command Support
    ####################################################################################
    def execute(cmd, opts = {})
      puts("\r\n$ " + cmd)
      return if opts[:cold]

      result = system(cmd)
      return if opts[:ignore_result]

      unless result
        puts("Build failed.")
        exit 1
      end
    end

  end
end
