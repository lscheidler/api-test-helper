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

require 'erb'
require "output_helper"

require "api_test_helper/validate"

require_relative 'common'

module ApiTestHelper
  module Tests
    class Regexp < Common
      include Validate

      attr_reader :name

      def initialize conf
        @name   = conf['Name']
        @key    = conf['Key']
        @value  = conf['Value']

        @failed = false
      end

      def test response, job_binding: nil
        value = get_value response, @key
        value = value.to_s if value.nil? or value.is_a? TrueClass or value.is_a? FalseClass or value.is_a? Numeric

        if value !~ /#{ERB.new(@value).result(job_binding)}/
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
