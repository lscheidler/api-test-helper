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

require 'singleton'

require 'output_helper'

module ApiTestHelper
  class Report
    include Singleton

    def initialize
      #OutputHelper::Columns::config(
      #  ascii: true
      #)
      @data = OutputHelper::Columns.new ['project', 'group', 'job', 'runtime', 'passed', 'failed', 'warnings']
    end

    def add project:, group:, job:, runtime:, passed:, failed:, warnings:
      @data << ({project: project, group: group, job: job, runtime: runtime, passed: passed, failed: failed, warnings: warnings})
    end

    def to_s
      result = ""
      result += "Report".section
      result += @data.to_s
      result
    end
  end
end
