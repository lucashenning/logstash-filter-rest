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

  config_name 'rest'

  # Configure the rest request send via HttpClient Plugin
  # with hash objects used by the mixin plugin
  #
  # For example, if you want the data to be put in the `doc` field:
  # [source,ruby]
  #    filter {
  #      rest {
  #        request => {
  #          url => "http://example.com"       # string (required, with field reference: "http://example.com?id=%{id}" or params, if defined)
  #          method => "post"                  # string (optional, default = "get")
  #          headers => {                       # hash (optional)
  #            "key1" => "value1"
  #            "key2" => "value2"
  #          }
  #          auth => {
  #            user => "AzureDiamond"
  #            password => "hunter2"
  #          }
  #          params => {                       # hash (optional, available for method => "get" and "post"; if post it will be transformed into body hash and posted as json)
  #            "key1" => "value1"
  #            "key2" => "value2"
  #            "key3" => "%{somefield}"        # Please set sprintf to true if you want to use field references
  #          }
  #        }
  #      }
  #    }
  #
  # NOTE: for further details, please reference https://github.com/logstash-plugins/logstash-mixin-http_client[logstash-mixin-http_client]
  config :request, :validate => :hash, :required => true

  # The plugin is written json centric, which defaults to true
  # the response body will be parsed to json if true
  #
  # [source,ruby]
  #     filter {
  #       rest {
  #         request => { .. }
  #         json => true
  #       }
  #     }
  config :json, :validate => :boolean, :default => true

  # If true, references to event fields can be made in
  # url, params or body by using '%{somefield}'
  #
  # [source,ruby]
  #     filter {
  #       rest {
  #         request => { .. }
  #         sprintf => true
  #       }
  #     }
  config :sprintf, :validate => :boolean, :default => false

  # Defines the field, where the parsed response is written to
  # if set to '' it will be written to event root
  #
  # For example, if you want the data to be put in the `doc` field:
  # [source,ruby]
  #     filter {
  #       rest {
  #         request => { .. }
  #         target => "doc"
  #       }
  #     }
  #
  # NOTE: if the `target` field already exists, it will be overwritten!
  config :target, :validate => :string, :default => 'rest'

  # If set, any error like json parsing or invalid http response
  # will result in this hash to be added to target instead of error tags
  #
  # For example, if you want the fallback data to be put in the `target` field:
  # [source,ruby]
  #     filter {
  #       rest {
  #         request => { .. }
  #         fallback => {
  #           'key1' => 'value1'
  #           'key2' => 'value2'
  #           ...
  #         }
  #       }
  #     }
  config :fallback, :validate => :hash, :default => {}

  # Append values to the `tags` field when there has been no
  # successful match or json parsing error
  config :tag_on_rest_failure, :validate => :array, :default => ['_restfailure']
  config :tag_on_json_failure, :validate => :array, :default => ['_jsonparsefailure']

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
          @tag_on_json_failure.each { |tag| event.tag(tag) }
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
    request = @request.clone
    request[2][:params] = sprint(@sprintf, @request[2][:params], event) if request[2].key?(:params)
    request[2][:body] = sprint(@sprintf, @request[2][:body], event) if request[2].key?(:body)
    request[1] = sprint(@sprintf, @request[1], event)

    code, body = request_http(request)
    if code.between?(200, 299)
      event = process_response(body, event)
      @logger.debug? && @logger.debug('Sucess received', :code => code, :body => body)
    else
      @logger.debug? && @logger.debug('Http error received', :code => code, :body => body)
      if @fallback.empty?
        @tag_on_rest_failure.each { |tag| event.tag(tag) }
        @logger.error('Error in Rest filter', :request => request, :json => @json, :code => code, :body => body)
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
