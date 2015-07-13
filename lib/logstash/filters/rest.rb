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
  #  rest {
  #  url => "http://example.com"       # string (required, with field reference: "http://example.com?id=%{id}")
  #  json => true                      # boolean (optional, default = false)
  #  method => "post"                  # string (optional, default = "get")
  #  sprintf => true                   # boolean (optional, default = false, set this to true if you want to use field references in url, header or params)
  #  header => {                       # hash (optional)
  #    "key1" => "value1"
  #    "key2" => "value2"
  #    "key3" => "%{somefield}"        # Please set sprintf to true if you want to use field references
  #  }
  #  params => {                       # hash (optional, only available for method => "post")
  #    "key1" => "value1"
  #    "key2" => "value2"
  #    "key3" => "%{somefield}"        # Please set sprintf to true if you want to use field references
  #  }
  #  response_key => "my_key"          # string (optional, default = "rest_response")
  #  }
  #
  
  config_name "rest"
  
  config :url, :validate => :string, :required => true
  config :method, :validate => :string, :default => "get"
  config :json, :validate => :boolean, :default => false
  config :sprintf, :validate => :boolean, :default => false
  config :header, :validate => :hash, :default => {  }
  config :params, :validate => :hash, :default => {  }
  config :response_key, :validate => :string, :default => "rest_response"

  public
  def register

  end # def register

  public
  def filter(event)
    return unless filter?(event)
    
	begin
		
		if sprintf == true
			begin
				# sprintf values
				@url = event.sprintf(@url)
				@header.each do |key, value|
					@header[key] = event.sprintf(value)
				end
				@params.each do |key, value|
					@params[key] = event.sprintf(value)
				end
			rescue
				@logger.error("Error during sprintf", :url => url, :method => method, :json => json, :header => header, :params => params)
				@logger.error("Rest Error Message:", :message => $!.message)
				@logger.error("Backtrace:", :backtrace => $!.backtrace)
			end
		end
	
		case method
		when "get"
			response = RestClient.get @url, @header
		when "post"
			response = RestClient.post @url, @params, @header
		else
			response = "invalid method"	
			@logger.error("Invalid method:", :method => method)
		end
		
		if json == true
			begin
				h = JSON.parse(response)
				if response_key == ""
					h.each do |key, value|
						event[key] = value
					end
				else
					event[response_key] = { }
					event[response_key] = h
				end
			rescue
				event['jsonerror'] = "unable to parse json"
			end
		else
			event[@response_key] = response.strip
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
