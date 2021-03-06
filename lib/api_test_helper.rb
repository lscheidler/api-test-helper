# Copyright 2018 Lars Eric Scheidler
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

require 'optparse'
require 'bundler/setup'

require 'output_helper'
require 'overlay_config'

require "api_test_helper/project"
require "api_test_helper/report"
require "api_test_helper/version"

module ApiTestHelper
  class CLI
    def initialize
      set_defaults
      parse_arguments
      load_local_configfile

      case @config.action
      when :generate
        generate_json_files
      when :list
        list
      when :run
        run
      else
        puts @options.to_s
      end
    end

    # set defaults
    def set_defaults
      # set STDOUT to synchronize
      STDOUT.sync = true

      @script_name = File.basename($0)
      @config = OverlayConfig::Config.new config_scope: 'api-test-helper', defaults: {
        working_directory: Dir.pwd,
        output_directory: '/tmp'
      }

      @projects = {}
      @selected_jobs = []
    end

    # load and validate local configfile
    def load_local_configfile
      Dir.glob('**/project.yml') do |filename|
        project   =  Project.new(config: @config, filename: filename)
        @projects[project.name] = project if project.valid?
      end
    end

    # parse command line arguments
    def parse_arguments
      @cmd_line_arguments = {}

      @options = OptionParser.new do |opt|
        opt.on('-C', '--change-dir DIR', 'Change working directory to DIR') do |directory|
          @cmd_line_arguments[:working_directory] = directory
        end

        opt.on('-d', '--debug', 'Debug mode') do
          @cmd_line_arguments[:debug] = true
        end

        opt.on('-e', '--environment NAME', 'set environment to NAME') do |environment|
          @cmd_line_arguments[:environment] = environment
        end

        opt.on('-G', '--generate-json', 'Generate json files, which are commited to api') do
          @cmd_line_arguments[:generate_json_file] = true
          @cmd_line_arguments[:action] ||= :generate
        end

        opt.on('--generate-report', 'Generate report csv in output directory') do
          @cmd_line_arguments[:generate_report] = true
        end

        opt.on('-g', '--group NAME[,NAME]', Array, 'set groups') do |groups|
          @cmd_line_arguments[:groups] ||= []
          @cmd_line_arguments[:groups] += groups
        end

        opt.on('-j', '--job JOB[,JOB,...]', Array, 'Limit action to JOB, which is a regexpression') do |jobs|
          @selected_jobs += jobs
        end

        opt.on('-l', '--list', 'List available jobs') do
          @cmd_line_arguments[:action] = :list
        end

        opt.on('-p', '--project NAME', 'set project') do |project|
          @cmd_line_arguments[:project] = project
        end

        opt.on('-o', '--output-directory DIR', 'generate json file into DIR directory', 'default: ' + @config.output_directory) do |directory|
          @cmd_line_arguments[:output_directory] = directory
        end

        opt.on('-q', '--quiet', 'be quiet') do
          @cmd_line_arguments[:quiet] = true
        end

        opt.on('-r', '--run', 'Run all configured jobs or all jobs passed with -j') do
          @cmd_line_arguments[:action] = :run
        end

        opt.on('-R', '--report', 'show report') do
          @cmd_line_arguments[:report] = true
        end

        opt.on('-s', '--save-response', 'save respone in output directory') do
          @cmd_line_arguments[:save_response] = true
        end

        opt.separator "

  Examples:
    # List all available jobs
    #{File.basename $0} -l

    # List all available jobs in a specific directory
    #{File.basename $0} -C api-helper -p LISU -l

    # Run all configured jobs
    #{File.basename $0} -r

    # Run all configured jobs and show a report
    #{File.basename $0} -r --report

    # Run all configured jobs in a specific directory
    #{File.basename $0} -C api-helper -p LISU -r

    # Run Job_A and Job_B, which must configured in project.yml or group.yml
    #{File.basename $0} -r -j Job_A -j Job_B

    # Run all Jobs, which beginn with JOB
    #{File.basename $0} -r -j JOB.*

    # Run all Jobs, which contains with JOB
    #{File.basename $0} -r -j .*JOB.*

    # Generate json files, which are going to be requested, for all configured jobs
    #{File.basename $0} -G

    # Generate json file, which are going to be requested, for Job_A
    #{File.basename $0} -G -j Job_A

    # Run jobs for delti group and generate json files
    #{File.basename $0} -r -G -g delti

  Available template macros:

    Variables and Responses:
      response('<job_name>', '<name>')        - return value from the response of a job (see examples)
      response('<job_name>',                  - return value from the response of a job in another group (must be run before)
               '<name>',
               group: '<group_name>')
      var('<name>',                           - return variable defined in Job in Vars section.
                    default: nil,               when default is set (not nil) and variable is undefined, return default
                    ignore_error: false)        when variable is undefined, do not throw an error

    Date and Time:
      now()                                   - returns today (now) in seconds
      yesterday()                             - returns yesterday in iso8601
      time([<day_shift>[, format: <format>]]) - returns time in specificied format
                                                defaults: day_shift = 0, format = :seconds
                                                format:
                                                  :seconds    : return time in seconds
                                                  :iso8601    : return timestamp in iso8601
                                                  :iso8601utc : return timestamp in iso8601 (utc)

    Examples:
      # get variable test
      var('test')

      # get value pdfToken from register response
      response('Delti_Create_DE', 'pdfToken')

      # get value pdfToken from register response, where job name is defined as variable in cancel job
      response(var('CreateJob'), 'pdfToken')

      # get value token from GenerateToken response in group auth
      response('GenerateToken', 'token', group: 'auth')

      # return time of today in seconds
      time()

      # return timestamp of today in iso8601
      time(format: :iso8601)

      # return timestamp of yesterday in iso8601
      time(-1, format: :iso8601)

      # return timestamp of last year in iso8601
      time(-365, format: :iso8601)

      # return timestamp of tomorrow in iso8601
      time(1, format: :iso8601)

      # return credential
      credential('PROJECT_NAME_username')

      # return basic auth header value
      basicauth('PROJECT_NAME_username', 'PROJECT_NAME_password')
  "
      end
      @options.parse!

      @config.insert 0, '<command_line>', @cmd_line_arguments

      unless File.directory?(@config.output_directory)
        Dir.mkdir @config.output_directory
      end

      Dir.chdir @config.working_directory
    end

    # generate json files in /tmp
    def generate_json_files
      # if no job is served, generate all
      filter do |project, group, job|
        job.generate_json_file
      end
    end

    # list available jobs
    def list
      job_list = OutputHelper::Columns.new ['project', 'group', 'job']

      filter do |project, group, job|
        job_list << ({project: project.name, group: group.name, job: job.name})
      end
      puts job_list
    end

    # run jobs
    def run
      filter do |project, group, job|
        job.run
      end

      if @config.report
        report = Report.instance
        puts report

        if @config.generate_report
          filename = File.join(@config.output_directory, @script_name + '.report.'+ Time.now.strftime('%Y%m%dT%H%M%S') +'.csv')
          File.open(filename, 'w') do |io|
            io.print report.to_csv
          end
        end

        #puts 'Generated report.csv in ' + filename
      end
    end

    def filter
      @projects.each do |pname, project|
        next if @config.project and @config.project != pname

        project.groups.sort.each do |gname, group|
          next if @config.groups and not @config.groups.include? gname

          group.each do |job_name, job|
            next unless @selected_jobs.empty? or @selected_jobs.find{|x| job_name =~ /^#{x}$/}

            yield project, group, job
          end
        end
      end
    end
  end
end
