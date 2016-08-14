# encoding: utf-8
require 'logstash/filters/base'
require 'logstash/namespace'
require 'logstash/plugin_mixins/http_client'
require 'logstash/json'

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
  #   target => "my_key"                # string (optional, default = "rest")
  #   fallback => {                     # hash describing a default in case of error
  #     "key1" => "value1"
  #     "key2" => "value2"
  #   }
  # }

  config_name 'rest'

  # configure the rest request send via HttpClient Plugin
  config :request, :validate => :hash, :required => true
  config :json, :validate => :boolean, :default => true
  config :sprintf, :validate => :boolean, :default => false
  config :target, :validate => :string, :default => 'rest'
  config :fallback, :validate => :hash, :default => { }

  # Append values to the `tags` field when there has been no
  # successful match
  config :tag_on_failure, :validate => :array, :default => ['_restfailure']

  public
  def register
    @request = normalize_request(@request)
  end # def register

  private
  def normalize_request(url_or_spec)
    if url_or_spec.is_a?(String)
      res = [:get, url_or_spec]
    elsif url_or_spec.is_a?(Hash)
      # The client will expect keys / values
      spec = Hash[url_or_spec.clone.map { |k, v| [k.to_sym, v] }]

      # method and url aren't really part of the options, so we pull them out
      method = (spec.delete(:method) || :get).to_sym.downcase
      url = spec.delete(:url)

      # if it is a post and json, it is used as body string, not params
      spec[:body] = spec.delete(:params) if method == :post

      # We need these strings to be keywords!
      spec[:auth] = { user: spec[:auth]['user'], pass: spec[:auth]['password'] } if spec[:auth]

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
      raise LogStash::ConfigurationError, "Auth was specified, but 'user' was not!" unless spec[:auth][:user]
      raise LogStash::ConfigurationError, "Auth was specified, but 'password' was not!" unless spec[:auth][:pass]
    end

    request
  end

  private
  def request_http(request)
    @logger.debug? && @logger.debug('Fetching URL', :request => request)

    request[2][:body] = LogStash::Json.dump(request[2][:body]) if request[2].key?(:body)

    method, url, *request_opts = request
    response = client.http(method, url, *request_opts)
    [response.code, response.body]
  end

  private
  def process_response(response, event)
    if @json
      begin
        parsed = LogStash::Json.load(response)
        event = add_to_event(parsed, event)
      rescue
        if @fallback.empty?
          event.tag('_jsonparsefailure')
          @logger.warn('JSON parsing error', :response => response, :event => event)
        else
          event = add_to_event(@fallback, event)
        end
      end
    else
      event.set(@target, response.strip)
    end
    event
  end

  public
  def filter(event)
    return unless filter?(event)
    @request[2][:params] = sprint(@sprintf, @request[2][:params], event) if @request[2].key?(:params)
    @request[2][:body] = sprint(@sprintf, @request[2][:body], event) if @request[2].key?(:body)
    @request[1] = sprint(@sprintf, @request[1], event)

    code, body = request_http(@request)
    if code.between?(200, 299)
      event = process_response(body, event)
      @logger.debug? && @logger.debug('Sucess received', :code => code, :body => body)
    else
      @logger.debug? && @logger.debug('Http error received', :code => code, :body => body)
      if @fallback.empty?
        @tag_on_failure.each { |tag| event.tag(tag) }
        @logger.error('Error in Rest filter', :request => @request, :json => @json, :code => code, :body => body)
      else
        event = add_to_event(@fallback, event)
        @logger.debug? && @logger.debug('Setting fallback', :fallback => @fallback)
      end
    end
    filter_matched(event)
  end # def filter

  private
  def sprint(sprintf, hash, event)
    return hash unless sprintf
    return event.sprintf(hash) unless hash.is_a?(Hash)
    result = {}
    hash.each { |k, v| result[k] = event.sprintf(v) }
    result
  end

  private
  def add_to_event(to_add, event)
    if @target.empty?
      to_add.each { |k, v| event[k] = v }
    else
      event[@target] = to_add
    end
    event
  end
end # class LogStash::Filters::Rest
