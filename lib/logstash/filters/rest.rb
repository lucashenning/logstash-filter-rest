# encoding: utf-8
require "logstash/filters/base"
require "logstash/namespace"

# Logstash REST Filter
# This filter calls a defined URL and saves the answer into a specified field.
#
class LogStash::Filters::Rest < LogStash::Filters::Base

  # Usage:
  #
  # filter {
  #   rest {
  #     url => "http://example.com"
  #   }
  # }
  #
  config_name "rest"
  
  # Replace the message with this value.
  config :url, :validate => :string, :required => true
  config :timestamp, :validate => :string, :default => "12345"

  public
  def register
    require "json"
    require "rest_client"
    @resource = RestClient::Resource.new(@url)
  end # def register

  public
  def filter(event)
    return unless filter?(event)
    response = @resource.get(:params => {:timestamp => timestamp})
    event['response'] = response
    filter_matched(event)    
  end # def filter
end # class LogStash::Filters::Rest
