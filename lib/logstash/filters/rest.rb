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
  #  fallback => {                     # hash describing a default in case of error
  #    "key1" => "value1"
  #    "key2" => "value2"
  #  }
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
  config :fallback, :validate => :hash, :default => {  }

  public
  def register

  end # def register

  public
  def filter(event)
    return unless filter?(event)
  begin
    case method
    when "get"
      response = RestClient.get sprint(@sprintf, @url, event), sprint(@sprintf, @header, event)
    when "post"
      response = RestClient.post sprint(@sprintf, @url, event), sprint(@sprintf, @params, event), sprint(@sprintf, @header, event)
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
        if fallback
          event[@response_key] = fallback
        else
          event['jsonerror'] = "unable to parse json"
        end
      end
    else
      event[@response_key] = response.strip
    end
  rescue
    if fallback
      event[@response_key] = fallback
    else
      @logger.error("Error in Rest Filter. Parameters:", :url => url, :method => method, :json => json, :header => header, :params => params)
      @logger.error("Rest Error Message:", :message => $!.message)
      @logger.error("Backtrace:", :backtrace => $!.backtrace)
      event['resterror'] = "Rest Filter Error. Please see Logstash Error Log for further information."
    end
  end
  
    filter_matched(event)
  end # def filter
  
  def sprint(sprintf, hash, event)
        if sprintf
                if hash.class == Hash
                        result = { }
                        hash.each do |key, value|
                                result[key] = event.sprintf(value)
                        end
                        return result
                else
                        return event.sprintf(hash)
                end
        else
                return hash
        end
  end

end # class LogStash::Filters::Rest
