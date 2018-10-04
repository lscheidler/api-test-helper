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

require 'output_helper'

require "api_helper/config"
require "api_helper/project"
require "api_helper/report"
require "api_helper/version"

module ApiHelper
  class CLI
    def initialize
      set_defaults
      parse_arguments
      load_local_configfile

      case @action
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

      @config = Config.instance

      @initial_working_directory = Dir.pwd
      @config.output_directory = '/tmp/'

      @projects = {}
      @selected_jobs = []

      @config.working_directory = './'
    end

    # load and validate local configfile
    def load_local_configfile

      Dir.glob('**/project.yml') do |filename|
        project   =  Project.new(filename: filename)
        @projects[project.name] = project if project.valid?
      end
    end

    # parse command line arguments
    def parse_arguments
      @options = OptionParser.new do |opt|
        opt.on('-C', '--change-dir DIR', 'Change working directory to DIR') do |directory|
          @config.working_directory = directory
          @config.working_directory += '/' if not @config.working_directory.end_with? '/'

          Dir.chdir @config.working_directory
        end

        opt.on('-d', '--debug', 'Debug mode') do
          @debug = true
        end

        opt.on('-G', '--generate-json', 'Generate json files, which are commited to api') do
          @generate_json_file = true
          @action ||= :generate
        end

        opt.on('-g', '--group NAME', 'set group') do |group|
          @group = group
        end

        opt.on('-j', '--job JOB', Array, 'Limit action to JOB') do |jobs|
          @selected_jobs += jobs
        end

        opt.on('-l', '--list', 'List available jobs') do
          @action = :list
        end

        opt.on('-p', '--project NAME', 'set project') do |project|
          @project = project
        end

        opt.on('-o', '--output-directory DIR', 'generate json file into DIR directory', 'default: ' + @config.output_directory) do |directory|
          @config.output_directory = directory
          @config.output_directory += '/' unless @config.output_directory.end_with? '/'
          unless File.directory?(@config.output_directory)
            Dir.mkdir @config.output_directory
          end
        end

        opt.on('-r', '--run', 'Run all configured jobs or all jobs passed with -j') do
          @action = :run
        end

        opt.on('--report', 'show report') do
          @config.report = true
        end

        opt.separator "

  Examples:
    # List all available jobs
    #{File.basename $0} -l

    # List all available jobs in a specific directory
    #{File.basename $0} -C api-helper/LISU -l

    # Run all configured jobs
    #{File.basename $0} -r

    # Run all configured jobs in a specific directory
    #{File.basename $0} -C api-helper/LISU -r

    # Run Job_A and Job_B, which must configured in ./config.yml
    #{File.basename $0} -r -j Job_A -j Job_B

    # Generate json files, which are going to be requested, for all configured jobs
    #{File.basename $0} -G

    # Generate json file, which are going to be requested, for Job_A
    #{File.basename $0} -G -j Job_A

    # Run jobs for delti group and generate json files
    #{File.basename $0} -r -G -g delti

  Available template macros:

    Variables and Responses:
      response('<job_name>', '<name>')        - return value from the response of a job (see examples)
      var('<name>')                           - return variable defined in Job in Vars section

    Date and Time:
      now()                                   - returns today (now) in seconds
      yesterday()                             - returns yesterday in iso8601
      time([<day_shift>[, format: <format>]]) - returns time in specificied format
                                                defaults: day_shift = 0, format = :seconds
                                                format:
                                                  :seconds : return time in seconds
                                                  :iso8601 : return timestamp in iso8601

    Examples:
      # get variable test
      var('test')

      # get value pdfToken from register response
      response('Delti_Create_DE', 'pdfToken')

      # get value pdfToken from register response, where job name is defined as variable in cancel job
      response(var('CreateJob'), 'pdfToken')

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
  "
      end
      @options.parse!
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
        puts Report.instance
      end
    end

    def filter
      @projects.each do |pname, project|
        next if @project and @project != pname

        project.groups.each do |gname, group|
          next if @group and @group != gname

          group.each do |job_name, job|
            next unless @selected_jobs.empty? or @selected_jobs.find{|x| job_name =~ /#{x}/}

            yield project, group, job
          end
        end
      end
    end
  end
end

ApiHelper::CLI.new
