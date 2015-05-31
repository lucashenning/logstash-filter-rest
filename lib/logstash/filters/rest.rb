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
  #		header => {
  #			'key1' => 'value1'
  #			'key2' => 'value2'
  #			'key3' => '%{somefield}'
  #		}
  #		method => "post"
  #     json => true
  #   }
  # }
  #
  config_name "rest"
  
  # Replace the message with this value.
  config :url, :validate => :string, :required => true
  config :method, :validate => :string, :default => "get"
  config :json, :validate => :boolean, :default => false
  config :header, :validate => :hash, :default => {  }

  public
  def register
    require "json"
    require "rest_client"
    @resource = RestClient::Resource.new(@url, :headers => @header)
  end # def register

  public
  def filter(event)
    return unless filter?(event)
	
	if method == "get"
       response = @resource.get(:params => {:timestamp => event['timestamp']})
	else
	   response = @resource.post(:params => {:timestamp => event['timestamp']})
	end
	
	if json == true
	   event['response'] = JSON.parse(response)
	else
       event['response'] = response
	end
	
    filter_matched(event)    
  end # def filter
end # class LogStash::Filters::Rest
