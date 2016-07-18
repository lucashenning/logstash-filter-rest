require 'spec_helper'
require "logstash/filters/rest"

describe LogStash::Filters::Rest do
  describe "Set to Rest Filter" do
    let(:config) do <<-CONFIG
      filter {
        rest {
          url => "http://jsonplaceholder.typicode.com/users/1"
          json => true
        }
      }
    CONFIG
    end

    sample("message" => "some text") do
      expect(subject).to include("rest_response")
      expect(subject['rest_response']).to include("id")
      expect(subject['rest_response']).to_not include("fallback")
    end
  end
  describe "Fallback" do
    let(:config) do <<-CONFIG
      filter {
        rest {
          url => "http://jsonplaceholder.typicode.com/users/0"
          json => true
          fallback => {
            "fallback" => true
          }
        }
      }
    CONFIG
    end

    sample("message" => "some text") do
      expect(subject).to include("rest_response")
      expect(subject['rest_response']).to include("fallback")
      expect(subject['rest_response']).to_not include("id")
    end
  end
  describe "Empty response_key" do
    let(:config) do <<-CONFIG
      filter {
        rest {
          url => "http://jsonplaceholder.typicode.com/users/1"
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
