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

require 'yaml'

require "api_helper/job"
require "api_helper/validate"

module ApiHelper
  class Group
    include Validate

    attr_accessor :name, :jobs, :dir

    def initialize project:, domain:, filename:
      @project  = project
      @domain   = domain
      @jobs     = {}

      if filename
        conf = YAML::load_file(filename)

        @filename = filename
        @name = conf['Name']
        @dir = File.dirname(filename)

        load_jobs conf['Jobs']
      end
    end

    def load_jobs jobs
      jobs and jobs.each do |job_name, job_conf|
        job = Job.new job_name, job_conf, project: @project, group: self
        @jobs[job_name] = job
      end
    end

    def valid?
      result = [true]
      result << isset(@name, 'Name must be set')
      result << isset(@jobs, 'Jobs must be set')

      @jobs.each do |job_name, job|
        result << job.valid?
      end

      result.reduce{|a,b| a and b}
    end

    def each
      @jobs.each do |job_name, job|
        yield job_name, job
      end
    end

    def [] name
      @jobs[name]
    end
  end
end
