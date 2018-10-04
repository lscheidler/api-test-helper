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

module ApiHelper
  # Wrapper class for credential files
  class Authorization
    def initialize cwd, project: nil
      load_configuration cwd, project: project
    end

    # load local or global credentials file and check, if all necessary elements are available
    def load_configuration cwd, project: nil
      global = false
      local_filename = project + '/credentials.yml'
      global_filename = Dir.home + '/.api-helper-credentials.yml'

      if File.exist?(local_filename)
        @filename = local_filename
      elsif File.exist?(global_filename)
        @filename = global_filename
        global = true
      end

      if @filename.nil?
        warn 'No credentials file found. Neither in ' + local_filename + ' nor in ' + global_filename + '.'
        raise KeyError
      end

      @credentials = YAML::load_file(@filename)

      unless @credentials.is_a? Hash and @credentials['Authorization']
        warn 'Authorization is missing in credentials file ' + @filename + '.'
        raise KeyError
      end

      if not global
        @credentials = @credentials['Authorization']
      else
        if @credentials['Authorization'][project]
          @credentials = @credentials['Authorization'][project]
        else
          warn "No section #{project.inspect} found in Authorization (#{@filename})."
          raise KeyError
        end
      end
    end

    # return entry from authorization hash
    def [] name
      @credentials[name]
    end
  end
end
