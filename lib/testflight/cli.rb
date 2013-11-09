#--
# Copyright (c) 2013 Michael Berkovich
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

require 'thor'

module Testflight
  class Cli < Thor
    include Thor::Actions

    class << self
      def source_root
        File.expand_path('../../',__FILE__)
      end
    end

    map 'c' => :checkin
    desc 'checkin', 'Initializes your project configuration file and prepares it for takeoff'
    def checkin
      return unless is_project_folder?

      say("\r\nConfiguring #{Testflight::Config.application_name} #{Testflight::Config.type} for deployment to testflightapp.com...")
      ["Provisioning", "Distributions", "build"].each do |name| 
        create_folder(name)
      end

      say("\r\nPlease answer the following questions to prepare you for takeoff:")

      @company_name = ask("What is the name of your company, as it appears in your .cer file from Apple?")
      @should_increment_bundle = yes?("Would you like to automatically increment build numbers (bundle value in your app properties) for every deployment? (y/N)")

      say("\r\nConfiguring SCM commands...")
      if yes?("Do you use git as your SCM? (y/N)")
        @should_commit_changes = yes?("Would you like to commit and push your changes to git as the first step of your deployment? (y/N)")
        if @should_increment_bundle
          @should_tag_build = yes?("Would you like to tag every build in git with the version/build number of your application? (y/N)")
        end
      end

      say("\r\nConfiguring Build commands...")
      say("What iPhone SDK version are you using?")
      sdks = [
        ["1:", "iphoneos4.3"],
        ["2:", "iphoneos5.0"],
        ["3:", "iphoneos5.1"],
        ["4:", "iphoneos6.0"],
        ["5:", "iphoneos6.1"],
        ["6:", "iphoneos7.0"],
      ]
      print_table(sdks)
      num = ask_for_number(5)
      @sdk = sdks[num-1].last

      say("\r\nConfiguring testflightapp.com commands...")
      say("For the next question, please get your API TOKEN from the following URL: https://testflightapp.com/account/#api")
      @api_token = ask("Paste your API TOKEN here:")

      say("For the next question, please get your TEAM TOKEN from the following URL: https://testflightapp.com/dashboard/team/edit")
      @team_token = ask("Paste your TEAM TOKEN here:")

      @teams = ask("\r\nPlease enter your distribution lists as you have set them up on testflightapp.com (separate team names with a comma):")
      @teams = @teams.split(",").collect{|t| t.strip}

      template 'templates/testflight.yml.erb', "./#{Testflight::Config.path}"

      update_git_ignore

      say("Configuration file '.testflight' has been created. You can edit it manually or run the init command again.")
      say("\r\nOnly a few steps left, but make sure you do them all.")
      say("1). Copy your Ad Hoc Provisioning Profile (.mobileprovision) into the 'Provisioning' folder that was created earlier.")
      say("2). Follow the instructions to setup your XCode project, found here: http://help.testflightapp.com/customer/portal/articles/1333914-how-to-create-an-ipa-xcode-5-")
      say("\r\nOnce you are done, you can run: testflight takeoff")
    end

    map 't' => :takeoff
    desc 'takeoff', 'Builds and deploys your project based on your configuration.'
    method_option :cold, :type => :boolean, :aliases => "c", :required => false
    def takeoff
      return unless ready_for_takeoff?

      say("Preparing #{Testflight::Config.application_name} #{Testflight::Config.type} #{Testflight::Config.project_version} for deployment to testflightapp.com...")

      @message = ask("\r\nWhat changes did you make in this build? (will be used in git commit)")
      @teams = ask_with_multiple_options("Which team(s) would you like to distirbute the build to? Provide team number(s, separated by a comma)",
                                         Testflight::Config.distribution_lists)

      @notify = yes?("\r\nWould you like to notify the team members by email about this build? (y/N)")
      
      Testflight::Builder.new(:message => @message, :teams => @teams, :notify => @notify, :cold => options['cold'])

      say("\r\nCongratulations, the build has been deployed! Have a safe flight!")
      say
    end

    protected
    
    def is_project_folder?
      unless Testflight::Config.application_name
        say("This folder does not contain an xCode project or a workspace.")
        say("Please run this command in the folder where you have the project or workspace you want to deploy.")
        return false
      end

      true
    end

    def ready_for_takeoff?
      return false unless is_project_folder?

      unless File.exists?(Testflight::Config.path)
        say("Project configuration file does not exist. Please run 'testflight checkin' first.")
        return false
      end

      unless Testflight::Config.ad_hoc_provisioning_name
        say("Please copy your Ad Hoc Provisioning Profile into the Provisioning folder.")
        return false
      end

      unless Testflight::Config.project_info_path
        say("Cannot locate #{Testflight::Config.project_info_file_name} file. Please make sure such file exists in your project.")
        return false
      end

      true
    end

    def create_folder(name)
      return if File.exist?("#{Dir.pwd}/#{name}")
      say("Creating folder: #{name}")
      FileUtils.mkdir(name)
    end

    # Remove the new files from git commits
    def update_git_ignore
      lines = File.exist?('.gitignore') ? File.open('.gitignore').readlines : []
      
      changed = false
      ['build', 'Distributions', 'Provisioning', '.testflight'].each do |name|
        next if lines.include?(name)
        lines << name
        changed = true
      end
      return unless changed

      File.open('.gitignore', "w") do |f| 
        lines.each do |line|
          f.write(line + "\n") 
        end
      end
    end

    def ask_for_info(question=nil, prompt="> ", allow_blank=false)
      say(question) if question
      
      $stdout.print(prompt)
      
      $stdin.each_line do |line|
        value = line.strip.downcase
        return value if allow_blank 
        return value unless value.empty?
        $stdout.print(prompt)
      end  
    end

    def collect_option_selections(opts)
      lists = []
      vals = ask_for_info(nil, prompt="? ") 
      vals.split(",").each do |index|
        index = index.to_i - 1
        return nil if index<0 or index>=opts.size
        lists << opts[index]
      end
      lists
    end 

    def ask_with_multiple_options(question, opts = [])
      say(question)
      opts.each_with_index{ |opt, index| say("\t#{index+1}) #{opt}") }
      
      vals = collect_option_selections(opts)
      while vals.nil?
        say("Invalid selection, please try again.")
        vals = collect_option_selections(opts)
      end
      
      vals
    end

    def ask_for_number(max, opts = {})
      opts[:message] ||= "Choose: "
      while true
        value = ask(opts[:message])
        if /^[\d]+$/ === value
          num = value.to_i
          if num < 1 or num > max
            say("Hah?")
          else
            return num
          end
        else
          say("Hah?")
        end
      end
    end    

  end
end
