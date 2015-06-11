# encoding: utf-8
require "logstash/filters/base"
require "logstash/namespace"
require "json"
require "rest_client"

# Logstash REST Filter
# This filter calls a defined URL and saves the answer into a specified field.
#
class LogStash::Filters::Rest < LogStash::Filters::Base

  # Usage:
  #
  # filter {
  #   rest {
  #     url => "http://example.com"
  #	header => {
  #		'key1' => 'value1'
  #		'key2' => 'value2'
  #		'key3' => '%{somefield}'
  #	}
  #	method => "post"
  #     json => true
  #	params => {
  #		'key1' => 'value1'
  #		'key2' => 'value2'
  #		'key3' => '%{somefield}'
  #	}
  #   }
  # }
  #
  config_name "rest"
  
  # Replace the message with this value.
  config :url, :validate => :string, :required => true
  config :method, :validate => :string, :default => "get"
  config :json, :validate => :boolean, :default => false
  config :header, :validate => :hash, :default => {  }
  config :params, :validate => :hash, :default => {  }

  public
  def register
    @resource = RestClient::Resource.new(@url, :headers => @header)
  end # def register

  public
  def filter(event)
    return unless filter?(event)
    
    	begin
		if method == "get"
	       		response = @resource.get()
		else
			response = @resource.post(@params)
		end
		
		if json == true
		   h = JSON.parse(response)
		   h.each do |key, value|
			event[key] = value
		   end
		else
	       	   event['response'] = response.strip
		end
	rescue
		@logger.error("Error in Rest Filter. Parameters:", :url => url, :method => method, :json => json, :header => header, :params => params)
		@logger.error("Rest Error Message:", :message => $!.message)
		@logger.error("Backtrace:", :backtrace => $!.backtrace)
		event['resterror'] = "Rest Filter Error. Please see Logstash Error Log for further information."
	end
	
    filter_matched(event)    
  end # def filter
end # class LogStash::Filters::Rest
