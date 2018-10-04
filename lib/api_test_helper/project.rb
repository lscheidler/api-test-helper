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

require "api_helper/authorization"
require "api_helper/group"
require "api_helper/validate"

module ApiHelper
  class Project
    include Validate

    attr_accessor :domain, :groups, :name, :authorization, :dir

    def initialize filename:
      conf = YAML::load_file(filename)

      @filename = filename
      @domain   = conf['Domain']
      @name     = conf['Name']
      @dir      = File.dirname(filename)
      @groups   = {}

      begin
        @authorization = Authorization.new File.dirname(filename), project: @name if @name
      rescue KeyError
      end

      Dir.glob(File.dirname(filename) + '/**/group.yml') do |group_filename|
        group = Group.new domain: @domain, filename: group_filename, project: self
        @groups[group.name] = group
      end

      if conf['Jobs']
        default_group = Group.new(domain: @domain, filename: nil, project: self)
        default_group.name = 'default'
        default_group.load_jobs conf['Jobs']
        if @groups['default'].nil?
          @groups['default'] = default_group
        else
          puts @filename + ': group with name default already exists, please remove Jobs or rename group with Name=default'
        end
      end
    end

    def valid?
      result = [true]
      result << isset(@domain, 'Domain must be set')
      result << isset(@name,   'Name must be set')
      result << isset(@groups, 'No group or job found')

      @groups.each do |group_name, group|
        result << group.valid?
      end
      result.reduce{|a,b| a and b}
    end

    def [] name
      @groups[name]
    end
  end
end
