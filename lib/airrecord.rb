require "json"
require "faraday"
require "time"
require "airrecord/version"
require "airrecord/client"
require "airrecord/table"

module Airrecord
  Error = Class.new(StandardError)
end
