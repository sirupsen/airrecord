require "json"
require "faraday"
require "airrecord/version"
require "airrecord/client"
require "airrecord/table"

module Airrecord
  Error = Class.new(StandardError)
end
