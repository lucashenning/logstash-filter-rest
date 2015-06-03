require 'spec_helper'
require "logstash/filters/rest"

describe LogStash::Filters::Rest do
  describe "Set to Rest Filter" do
    let(:config) do <<-CONFIG
      filter {
        rest {
          url => "http://icanhazip.com"
        }
      }
    CONFIG
    end

    sample("message" => "some text") do
      expect(subject).to include("message")
    end
  end
end
