# encoding: utf-8
require "logstash/filters/base"
require "logstash/namespace"
require "logstash/plugin_mixins/http_client"
require "json"

# Logstash REST Filter
# This filter calls a defined URL and saves the answer into a specified field.
#
class LogStash::Filters::Rest < LogStash::Filters::Base
  include LogStash::PluginMixins::HttpClient

  # Usage:
  #
  # rest {
  #   request => {
  #     url => "http://example.com"       # string (required, with field reference: "http://example.com?id=%{id}" or params, if defined)
  #     method => "post"                  # string (optional, default = "get")
  #     headers => {                       # hash (optional)
  #       "key1" => "value1"
  #       "key2" => "value2"
  #       "key3" => "%{somefield}"        # Please set sprintf to true if you want to use field references
  #     }
  #     auth => {
  #       user => "AzureDiamond"
  #       password => "hunter2"
  #     }
  #     params => {                       # hash (optional, only available for method => "post")
  #       "key1" => "value1"
  #       "key2" => "value2"
  #       "key3" => "%{somefield}"        # Please set sprintf to true if you want to use field references
  #     }
  #   }
  #   json => true                      # boolean (optional, default = false)
  #   sprintf => true                   # boolean (optional, default = false, set this to true if you want to use field references in url, header or params)
  #   response_key => "my_key"          # string (optional, default = "rest_response")
  #   fallback => {                     # hash describing a default in case of error
  #     "key1" => "value1"
  #     "key2" => "value2"
  #   }
  # }
  
  config_name "rest"

  # configure the rest request send via HttpClient Plugin
  config :request, :validate => :hash, :required => true
  config :json, :validate => :boolean, :default => false
  config :sprintf, :validate => :boolean, :default => false
  config :response_key, :validate => :string, :default => "rest_response"
  config :fallback, :validate => :hash, :default => {  }

  public
  def register
    @request = normalize_request( @request )
  end # def register

  private
  def normalize_request(url_or_spec)
    if url_or_spec.is_a?(String)
      res = [:get, url_or_spec]
    elsif url_or_spec.is_a?(Hash)
      # The client will expect keys / values
      spec = Hash[url_or_spec.clone.map {|k,v| [k.to_sym, v] }] # symbolize keys

      # method and url aren't really part of the options, so we pull them out
      method = (spec.delete(:method) || :get).to_sym.downcase
      url = spec.delete(:url)

      # if it is a post and json, it is used as body string, not params
      if method == :post
        spec[:body] = spec.delete(:params)
      end

      # We need these strings to be keywords!
      spec[:auth] = {user: spec[:auth]["user"], pass: spec[:auth]["password"]} if spec[:auth]

      res = [method, url, spec]
    else
      raise LogStash::ConfigurationError, "Invalid URL or request spec: '#{url_or_spec}', expected a String or Hash!"
    end

    validate_request!(url_or_spec, res)
    res
  end

  private
  def validate_request!(url_or_spec, request)
    method, url, spec = request

    raise LogStash::ConfigurationError, "No URL provided for request! #{url_or_spec}" unless url
    raise LogStash::ConfigurationError, "Not supported request method #{method}" unless [ :get, :post ].include?( method )

    if spec && spec[:auth]
      if !spec[:auth][:user]
        raise LogStash::ConfigurationError, "Auth was specified, but 'user' was not!"
      end
      if !spec[:auth][:pass]
        raise LogStash::ConfigurationError, "Auth was specified, but 'password' was not!"
      end
    end

    request
  end

  private
  def request_http(request)
    @logger.debug? && @logger.debug("Fetching URL", :request => request)

    if @request[2].key?(:body)
      @request[2][:body] = @request[2][:body].to_json
    end

    method, url, *request_opts = request
    response = client.http(method, url, *request_opts)
    return response.code, response.body
  end

  private
  def process_response(response, event)
    if @json
      begin
        h = JSON.parse(response)
        if response_key == ""
          h.each do |key, value|
            event[key] = value
          end
        else
          event[response_key] = h
        end
      rescue
        if not @fallback.empty?
          event[@response_key] = @fallback
        else
          event['jsonerror'] = "unable to parse json"
        end
      end
    else
      event[@response_key] = response.strip
    end
    return event
  end

  public
  def filter(event)
    return unless filter?(event)
    if @request[2].key?(:params)
      @request[2][:params] = sprint(@sprintf, @request[2][:params], event)
    end
    if @request[2].key?(:body)
      @request[2][:body] = sprint(@sprintf, @request[2][:body], event)
    end
    @request[1] = sprint(@sprintf, @request[1], event)

    code, body = request_http(@request)
    if code.between?(200, 299)
      @logger.debug? && @logger.debug("Sucess received", :code => code, :body => body)
      event = process_response( body, event )
    else
      @logger.debug? && @logger.debug("Http error received", :code => code, :body => body)
      if not @fallback.empty?
        @logger.debug? && @logger.debug("Setting fallback", :fallback => @fallback)
        event[@response_key] = @fallback
      else
        @logger.error("Error in Rest Filter. Parameters:", :request => @request, :json => @json, :code => code, :body => body)
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
