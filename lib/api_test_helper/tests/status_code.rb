# Copyright 2020 Lars Eric Scheidler
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

require "output_helper"

require "api_test_helper/validate"

require_relative 'common'

module ApiTestHelper
  module Tests
    class StatusCode < Common
      include Validate

      attr_reader :name

      def initialize conf
        @name   = conf['Name']
        @value  = conf['Value']

        @failed = false
      end

      def requires_json
        return false
      end

      def test response, job: nil, job_binding: nil
        test_value = @value
        test_value = ERB.new(test_value).result(job_binding) if @value.is_a? String

        if job.request_response_code != test_value.to_s
          @failed = true
        end
        success?
      rescue TypeError
        @failed = true
      end

      def success?
        (not @failed)
      end
    end
  end
end
