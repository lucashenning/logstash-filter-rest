# encoding: utf-8
require 'logstash/filters/base'
require 'logstash/namespace'
require 'logstash/plugin_mixins/http_client'
require 'logstash/json'

# Monkey Patch hsh with a recursive compact and deep freeze
class Hash
  def compact
    delete_if { |_k, v| v.respond_to?(:each) ? v.compact.empty? : v.nil? }
  end

  def deep_freeze
    each { |_k, v| v.deep_freeze if v.respond_to? :deep_freeze }
    freeze
  end
end

#  Monkey Patch Array with deep freeze
class Array
  def compact
    delete_if { |v| v.respond_to?(:each) ? v.compact.empty? : v.nil? }
  end

  def deep_freeze
    each { |j| j.deep_freeze if j.respond_to? :deep_freeze }
    freeze
  end
end

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
  #          headers => {                      # hash (optional)
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
  #            "key3" => "%{somefield}"        # Field references are found implicitly on startup
  #          }
  #        }
  #        target => "doc"
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
  config :sprintf, :validate => :boolean, :default => false, :deprecated => true

  # Define the target field for placing the response data. This setting is
  # required and may not be omitted. It is not possible to place the response
  # into the event top-level.
  #
  # For example, if you want the data to be put in the `doc` field:
  # [source,ruby]
  #     filter {
  #       rest {
  #         target => "doc"
  #       }
  #     }
  #
  # Rest response will be expanded into a data structure in the `target` field.
  #
  # NOTE: if the `target` field already exists, it will be overwritten!
  config :target, :validate => :string, :required => true

  # If set, any error like json parsing or invalid http response
  # will result in this hash to be added to target instead of error tags
  #
  # For example, if you want the fallback data to be put in the `target` field:
  # [source,ruby]
  #     filter {
  #       rest {
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
    @request = normalize_request(@request).deep_freeze
    @sprintf_fields = find_sprintf(
      LogStash::Util.deep_clone(@request)
    ).deep_freeze
    @sprintf_needed = !@sprintf_fields.empty?
    @target = normalize_target(@target).freeze
  end # def register

  private

  def normalize_target(target)
    # make sure @target is in the format [field name] if defined,
    # i.e. not empty and surrounded by brakets
    raise LogStash::ConfigurationError, 'target config string is empty, please set a valid field name' if target.empty?
    target = "[#{target}]" if target && target !~ /^\[[^\[\]]+\]$/
    target
  end

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
      spec[:body] = spec.delete(:params) if method == :post && spec[:params]

      # We need these strings to be keywords!
      spec[:auth] = { user: spec[:auth]['user'], pass: spec[:auth]['password'] } if spec[:auth]

      res = [method.freeze, url, spec]
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

  def find_sprintf(config)
    field_matcher = /%\{[^}]+\}/
    if config.is_a?(Hash)
      config.keep_if do |_k, v|
        find_sprintf(v)
      end.compact
    elsif config.is_a?(Array)
      config.keep_if do |v|
        find_sprintf(v)
      end.compact
    elsif config.is_a?(String) && config =~ field_matcher
      config
    end
  end

  private

  def request_http(request)
    if request[2].key?(:body) && @json
      request[2][:body] = LogStash::Json.dump(request[2][:body])
    end
    @logger.debug? && @logger.debug('fetching request',
                                    :request => request)

    method, url, *request_opts = request
    response = client.http(method, url, *request_opts)
    [response.code, response.body]
  end

  private

  def process_response(response, event)
    if @json
      begin
        parsed = LogStash::Json.load(response)
        if parsed.empty?
          @logger.warn('rest response empty',
                       :response => response, :event => event)
          @tag_on_rest_failure.each { |tag| event.tag(tag) }
        else
          event.set(@target, parsed)
        end
      rescue
        if @fallback.empty?
          @logger.warn('JSON parsing error',
                       :response => response, :event => event)
          @tag_on_json_failure.each { |tag| event.tag(tag) }
        else
          event.set(@target, @fallback)
        end
      end
    else
      event.set(@target, response.strip)
    end
  end

  private

  def field_intrpl(intrpl_fields, event)
    case intrpl_fields
    when String
      result = event.sprintf(intrpl_fields)
    when Array
      result = []
      intrpl_fields.each do |v|
        result << field_intrpl(v, event)
      end
    when Hash
      result = {}
      intrpl_fields.each do |k, v|
        result[k] = field_intrpl(v, event)
      end
    else
      result = intrpl_fields
    end
    result
  end

  public

  def filter(event)
    return unless filter?(event)
    request = LogStash::Util.deep_clone(@request)
    @logger.debug? && @logger.debug('processing request',
                                    :request => request,
                                    :sprintf_needed => @sprintf_needed)

    if @sprintf_needed
      request = field_intrpl(request, event)
      @logger.debug? && @logger.debug('interpolated request',
                                      :request => request)
    end

    client_error = nil
    begin
      code, body = request_http(request)
    rescue StandardError => e
      client_error = e
    end

    if !client_error && code.between?(200, 299)
      @logger.debug? && @logger.debug('success received',
                                      :code => code, :body => body)
      process_response(body, event)
    else
      @logger.debug? && @logger.debug('http error received',
                                      :code => code, :body => body,
                                      :client_error => client_error)
      if @fallback.empty?
        @logger.error('error in rest filter',
                      :request => request, :json => @json,
                      :code => code, :body => body,
                      :client_error => client_error)
        @tag_on_rest_failure.each { |tag| event.tag(tag) }
      else
        @logger.debug? && @logger.debug('setting fallback',
                                        :fallback => @fallback)
        event.set(@target, @fallback)
      end
    end
    filter_matched(event)
  end # def filter
end # class LogStash::Filters::Rest
