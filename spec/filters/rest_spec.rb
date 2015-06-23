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
      expect(subject).to include("username")
    end
  end
end
