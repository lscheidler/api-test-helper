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

require 'base64'
require 'benchmark'
require 'erb'
require 'json'
require 'net/http'

require "output_helper"

require "api_test_helper/report"
require "api_test_helper/tests"

module ApiTestHelper
  # represents a Job
  class Job
    include OutputHelper

    attr_reader :name, :uri, :request_response, :runtime
    attr_reader :print_body, :ignore_body, :save_body, :download_directory

    def initialize name, cfg, config:, project:, group:
      @config = config

      @project  = project
      @group    = group

      @name               = name
      @output_directory   = @config.output_directory
      @working_directory  = @config.working_directory
      @failed_tests       = 0
      @warnings           = 0

      @request_method     = get_setting cfg, 'Method', required: false, default: 'Post'
      if @request_method != 'GET'
        @template         = get_setting cfg, 'Template', required: false
      end
      @endpoint           = get_setting cfg, 'Endpoint'
      @authorization      = get_setting cfg, 'Authorization', required: false
      @headers            = get_setting cfg, 'Headers', required: false, default: {}
      @wait               = get_setting cfg, 'Wait', required: false
      @vars               = get_setting cfg, 'Vars', required: false, default: {}

      @tests              = get_setting cfg, 'Tests', required: false, default: []
      @tests.map!{|test| klass = Kernel::const_get "ApiTestHelper::Tests::#{test["Type"]}"; klass.new test}

      @ignore_body        = get_setting cfg, 'Ignore_Body'        , required: false, default: false
      @print_body         = get_setting cfg, 'Print_Body'         , required: false, default: true
      @save_body          = get_setting cfg, 'Save_Body'          , required: false, default: false
      @download_directory = get_setting cfg, 'Download_Directory' , required: false, default: @output_directory
    end

    def valid?
      (not @failed)
    end

    def run
      @request_output_io  = File.open(File.join(@output_directory, File.basename($0) + '.' + [ @project.name, @group.name, @name ].join('-') + '.request.txt'), 'w') if @config.save_response

      unless @config.quiet
        puts
        print_section 'Running ' + @name
      end
      generate_json_file if @config.generate_json_file

      wait

      @runtime = Benchmark.realtime do
        send_request
      end

      @tests.each do |test|
        if @request_response.nil?
          error '  WARNING: No json response available to test against'
          @failed_tests += 1
          next
        end

        test.test @request_response, job_binding: binding
        if not test.success?
          @failed_tests += 1
          error test.name + ' failed'
        end
      end

      if @config.report
        #add project:, group:, job:, runtime:, failed:, warnings:
        Report.instance.add(
          project: @project.name,
          group: @group.name,
          job: @name,
          runtime: @runtime.runtime,
          passed: @tests.length - @failed_tests,
          failed: @failed_tests,
          warnings: @warnings
        )
      end

      print_section(@runtime.runtime) unless @config.quiet
    end

    def print_section msg
      puts (sprintf "%s | %-54s", Time.now.strftime("%FT%H:%M:%S"), msg).section color: :yellow
    end

    # return HTTP::Request for job
    def get_request
      @uri ||= URI(@project.domain+ERB.new(@endpoint).result(binding))

      @headers.map{|k, v| v.replace(ERB.new(v).result(binding))}

      @headers['authorization'] = ERB.new(@authorization).result(binding) unless @authorization.nil?

      @request ||= if @request_method == 'GET'

                     request = Net::HTTP::Get.new(@uri, @headers)
                   else
                     @headers['content_type'] = 'application/json'

                     request = Kernel.const_get('Net::HTTP::' + @request_method.capitalize).new(@uri, @headers)
                     request.body = get_json_doc if @template
                     request.content_type = 'application/json'

                     exit 1 if request.body.nil? and not @template.nil?

                     request
                   end
    end

    # sleep for *@wait* seconds, if Wait is defined in configuration
    def wait
      if not @wait.nil?
        message 'Waiting for ' + @wait.to_s + ' before sending request.'
        sleep @wait
      end
    end

    # helper to get options from configuration file
    def get_setting cfg, name, required: true, default: nil, msg: nil
      if required and (cfg.nil? or cfg[name].nil?)
        msg = ( not msg.nil? ) ? msg : name + ' is missing in configuration file for job ' + @name
        error msg
        @failed = true
      end

      ( cfg.nil? or cfg[name].nil? ) ? default : cfg[name]
    end

    # run through templating and return string of result
    def get_json_doc check_json: true
      begin
        template = get_template
        if template
          json_doc = ERB.new(File.read(template)).result(binding)
          JSON::parse(json_doc) if check_json
          json_doc
        else
          error 'No template ' + @template + ' found.'
          exit 1
        end
      rescue JSON::ParserError => exception
        error '  WARNING: Parsing json failed with: ' + exception.class.to_s + ' - ' + exception.message
        generate_json_file json_doc: json_doc, suppress_warning: true
      end
    end

    def get_template
      arr = [
        [@project.dir, @group.dir, 'templates', @template].join('/'),
        [@group.dir, 'templates', @template].join('/'),
        [@project.dir, 'templates', @template].join('/'),
        ['templates', @template].join('/')
      ]
      arr.find{|x| File.exist? x}
    end

    # generate json file
    def generate_json_file json_doc: nil, suppress_warning: false
      return unless @template

      json_doc = get_json_doc check_json: false if json_doc.nil?

      filename = File.join(@output_directory, File.basename($0) + '.' + [@project.name, @group.name, @name].join('-') + '.json')
      if @output_directory.start_with? '/'
        message 'Generate json for ' + @name + ' in ' + filename
      else
        message 'Generate json for ' + @name + ' in ' + File.join(@working_directory, filename)
      end
      
      File.open(filename, 'w') do |io|
        io.print json_doc
      end

      begin
        JSON::parse(json_doc)
      rescue JSON::ParserError => exception
        error '  WARNING: Parsing json failed with: ' + exception.class.to_s + ' - ' + exception.message unless suppress_warning
      end
    end

    def send_request
      get_request
      message get_request.method + ' ' + @uri.to_s, without_prefix: true
      @request_output_io and @request_output_io.puts get_request.method + ' ' + @uri.to_s
      
      http = Net::HTTP.new(@uri.hostname, @uri.port) 
      http.use_ssl = @uri.scheme == 'https'
      @config.debug and http.set_debug_output $stderr

      response = http.start do
        http.request(get_request)
      end

      request_output = ['HTTP/' + response.http_version + ' ' + response_color(response.code)]
      response.header.each_header {|key,value| request_output << "#{key}: #{value}" }
      request_output << ""
      request_output << response.body if @print_body and response['content-type'] and response['content-type'].include? 'application/json'

      puts request_output.join("\n") unless @config.quiet
      @request_output_io and @request_output_io.puts request_output.join("\n")

      # assuming, api returns a json string
      begin
        @request_response = JSON::parse(response.body) if not @ignore_body and response['content-type'] and response['content-type'].include? 'application/json'
      rescue JSON::ParserError => exception
        error '  WARNING: Parsing body as json failed with: ' + exception.class.to_s + ' - ' + exception.message
      end

      # save body
      if @save_body
        Dir.mkdir @download_directory if not File.directory? @download_directory

        extension = '.txt'
        case response['content-type']
        when /json/
          extension = '.json'
        when /pdf/
          extension = '.pdf'
        end

        filename = File.join(@download_directory, [@project.name, @group.name, @name].join('-') + extension)
        File.open(filename, 'w') do |io|
          io.print response.body
        end

        unless @config.quiet
          puts 'Saved body to ' + filename
          puts
        end
      end
    end

    def response_color response_code
      case response_code
      when '200'
        response_code.green
      when /^(40(1|3)|5)/
        response_code.red
      else
        response_code.yellow
      end
    end

    ## template macros

    #
    def basicauth username_key, password_key
      if @config.has_key? username_key and @config.has_key? password_key
        'Basic ' + Base64.encode64(@config[username_key] + ':' + @config[password_key])
      else
        error 'Cannot create basic auth header, because either ' + username_key + ' or ' + password_key + ' is missing'
        exit 1
      end
    end

    #
    def credential key
      if @config.has_key? key
        @config[key]
      else
        error 'Credential ' + key + ' not found'
        exit 1
      end
    end

    # return now in seconds
    def now
      time
    end

    # return value from *job_name* for *var*
    def response job_name, var
      if not @group[job_name].nil? and not @group[job_name].request_response.nil? and not @group[job_name].request_response[var].nil?
        @group[job_name].request_response[var]
      elsif not @group[job_name].nil? and not @group[job_name].request_response.nil?
        error '[' + job_name + '] Variable ' + var + ' not found in job response'
        exit 1
      else
        error 'No job response found for ' + job_name
        exit 1
      end
    end

    def time day_shift=0, format: :seconds
      time = Time.now

      if day_shift != 0
        time = Time.at(Time.now.to_i+day_shift*24*60*60)
      end

      case format
      when :seconds
        time.to_i
      when :iso8601
        time.strftime('%FT%T%:z')
      else
        error 'Format ' + format.to_s + ' is unknown for time(). Available formats: :seconds, :iso8601.'
        exit 1
      end
    end

    # return variable specified in config file
    def var name, default: nil, ignore_error: false
      if @vars.has_key? name
        if @vars[name].nil?
          warning 'Content of variable ' + name + ' is nil, which could lead to errors in templates.'
          @warnings += 1
        end
        if @vars[name].nil? or @vars[name].is_a? Numeric or @vars[name].is_a? TrueClass or @vars[name].is_a? FalseClass
          @vars[name]
        else
          ERB.new(@vars[name]).result(binding)
        end
      elsif not default.nil?
        default
      elsif not ignore_error
        error 'Variable ' + name + ' not found in job configuration for ' + @name
        exit 1
      end
    end

    # return yesterday in iso8601
    def yesterday
      time(-1, format: :iso8601)
    end

    def message msg, without_prefix: false
      return if @config.quiet

      if without_prefix
        puts msg
      else
        puts msg.subsection prefix: '▆', color: :green
      end
    end

    def error msg
      return if @config.quiet

      warn msg.subsection prefix: '▆', color: :red
    end

    def warning msg
      return if @config.quiet

      warn msg.subsection prefix: '▆', color: :yellow
    end
  end
end
