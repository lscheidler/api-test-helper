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

module ApiTestHelper
  module Tests
    class Common
      def requires_json
        return true
      end

      def get_value data, key
        if key.is_a? String
          data[key]
        elsif key.is_a? Array
          if key.empty?
            data
          else
            cur = key.shift
            get_value data[cur], key
          end
        end
      end
    end
  end
end
