require 'spec_helper'
require "logstash/filters/rest"

describe LogStash::Filters::Rest do
  describe "Set to Rest Filter Get without params" do
    let(:config) do <<-CONFIG
      filter {
        rest {
          request => {
            url => "http://jsonplaceholder.typicode.com/users/10"
          }
          json => true
        }
      }
    CONFIG
    end

    sample("message" => "some text") do
      expect(subject).to include("rest_response")
      expect(subject['rest_response']).to include("id")
      expect(subject['rest_response']['id']).to eq(10)
      expect(subject['rest_response']).to_not include("fallback")
    end
  end
  describe "Set to Rest Filter Get without params and sprintf" do
    let(:config) do <<-CONFIG
      filter {
        rest {
          request => {
            url => "http://jsonplaceholder.typicode.com/users/%{message}"
          }
          json => true
          sprintf => true
        }
      }
    CONFIG
    end

    sample("message" => "10") do
      expect(subject).to include("rest_response")
      expect(subject['rest_response']).to include("id")
      expect(subject['rest_response']['id']).to eq(10)
      expect(subject['rest_response']).to_not include("fallback")
    end
  end
  describe "Set to Rest Filter Get without params http error" do
    let(:config) do <<-CONFIG
      filter {
        rest {
          request => {
            url => "http://httpstat.us/404"
          }
          json => true
        }
      }
    CONFIG
    end

    sample("message" => "some text") do
      expect(subject).to_not include("rest_response")
      expect(subject).to include("resterror")
    end
  end
  describe "Set to Rest Filter Get with params" do
    let(:config) do <<-CONFIG
      filter {
        rest {
          request => {
            url => "https://jsonplaceholder.typicode.com/posts"
            params => { 
              userId => 10
            }
            headers => {
              "Content-Type" => "application/json"
            }
          }
          json => true
        }
      }
    CONFIG
    end

    sample("message" => "some text") do
      expect(subject).to include("rest_response")
      expect(subject['rest_response'][0]).to include("userId")
      expect(subject['rest_response'][0]['userId']).to eq(10)
      expect(subject['rest_response']).to_not include("fallback")
    end
  end
  describe "Set to Rest Filter Get with params sprintf" do
    let(:config) do <<-CONFIG
      filter {
        rest {
          request => {
            url => "https://jsonplaceholder.typicode.com/posts"
            params => { 
              userId => "%{message}"
            }
            headers => {
              "Content-Type" => "application/json"
            }
          }
          json => true
          sprintf => true
        }
      }
    CONFIG
    end

    sample("message" => "10") do
      expect(subject).to include("rest_response")
      expect(subject['rest_response'][0]).to include("userId")
      expect(subject['rest_response'][0]['userId']).to eq(10)
      expect(subject['rest_response']).to_not include("fallback")
    end
  end
  describe "Set to Rest Filter Post with params" do
    let(:config) do <<-CONFIG
      filter {
        rest {
          request => {
            url => "https://jsonplaceholder.typicode.com/posts"
            method => "post"
            params => { 
              title => 'foo'
              body => 'bar'
              userId => 42
            }
            headers => {
              "Content-Type" => "application/json"
            }
          }
          json => true
        }
      }
    CONFIG
    end

    sample("message" => "some text") do
      expect(subject).to include("rest_response")
      expect(subject['rest_response']).to include("id")
      expect(subject['rest_response']['userId']).to eq(42)
      expect(subject['rest_response']).to_not include("fallback")
    end
  end
  describe "Set to Rest Filter Post with params sprintf" do
    let(:config) do <<-CONFIG
      filter {
        rest {
          request => {
            url => "https://jsonplaceholder.typicode.com/posts"
            method => "post"
            params => { 
              title => 'foo'
              body => 'bar'
              userId => "%{message}"
            }
            headers => {
              "Content-Type" => "application/json"
            }
          }
          json => true
          sprintf => true
        }
      }
    CONFIG
    end

    sample("message" => "42") do
      expect(subject).to include("rest_response")
      expect(subject['rest_response']).to include("id")
      expect(subject['rest_response']['userId']).to eq(42)
      expect(subject['rest_response']).to_not include("fallback")
    end
  end
  describe "Fallback" do
    let(:config) do <<-CONFIG
      filter {
        rest {
          request => {
            url => "http://jsonplaceholder.typicode.com/users/0"
          }
          json => true
          fallback => {
            "fallback1" => true
            "fallback2" => true
          }
        }
      }
    CONFIG
    end

    sample("message" => "some text") do
      expect(subject).to include("rest_response")
      expect(subject['rest_response']).to include("fallback1")
      expect(subject['rest_response']).to include("fallback2")
      expect(subject['rest_response']).to_not include("id")
    end
  end
  describe "Empty response_key" do
    let(:config) do <<-CONFIG
      filter {
        rest {
          request => {
            url => "http://jsonplaceholder.typicode.com/users/1"
          }
          json => true
          response_key => ""
        }
      }
    CONFIG
    end

    sample("message" => "some text") do
      expect(subject).to include("id")
      expect(subject).to_not include("fallback")
    end
  end
end
