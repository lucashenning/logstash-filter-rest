require 'logstash/devutils/rspec/spec_helper'
require 'logstash/filters/rest'

describe LogStash::Filters::Rest do
  describe 'Set to Rest Filter Get without params' do
    let(:config) do <<-CONFIG
      filter {
        rest {
          request => {
            url => 'http://jsonplaceholder.typicode.com/users/10'
          }
          json => true
          target => 'rest'
        }
      }
    CONFIG
    end

    sample('message' => 'some text') do
      expect(subject).to include('rest')
      expect(subject.get('rest')).to include('id')
      expect(subject.get('[rest][id]')).to eq(10)
      expect(subject.get('rest')).to_not include('fallback')
    end
  end
  describe 'Set to Rest Filter Get without params custom target' do
    let(:config) do <<-CONFIG
      filter {
        rest {
          request => {
            url => 'http://jsonplaceholder.typicode.com/users/10'
          }
          json => true
          target => 'testing'
        }
      }
    CONFIG
    end

    sample('message' => 'some text') do
      expect(subject).to include('testing')
      expect(subject.get('testing')).to include('id')
      expect(subject.get('[testing][id]')).to eq(10)
      expect(subject.get('testing')).to_not include('fallback')
    end
  end
  describe 'Set to Rest Filter Get without params and sprintf' do
    let(:config) do <<-CONFIG
      filter {
        rest {
          request => {
            url => "http://jsonplaceholder.typicode.com/users/%{message}"
          }
          json => true
          sprintf => true
          target => 'rest'
        }
      }
    CONFIG
    end

    sample('message' => '10') do
      expect(subject).to include('rest')
      expect(subject.get('rest')).to include('id')
      expect(subject.get('[rest][id]')).to eq(10)
      expect(subject.get('rest')).to_not include('fallback')
    end
    sample('message' => '9') do
      expect(subject).to include('rest')
      expect(subject.get('rest')).to include('id')
      expect(subject.get('[rest][id]')).to eq(9)
      expect(subject.get('rest')).to_not include('fallback')
    end
  end
  describe 'Set to Rest Filter Get without params http error' do
    let(:config) do <<-CONFIG
      filter {
        rest {
          request => {
            url => 'http://httpstat.us/404'
          }
          json => true
          target => 'rest'
        }
      }
    CONFIG
    end

    sample('message' => 'some text') do
      expect(subject).to_not include('rest')
      expect(subject.get('tags')).to include('_restfailure')
    end
  end
  describe 'Set to Rest Filter Get with params' do
    let(:config) do <<-CONFIG
      filter {
        rest {
          request => {
            url => 'https://jsonplaceholder.typicode.com/posts'
            params => {
              userId => 10
            }
            headers => {
              'Content-Type' => 'application/json'
            }
          }
          json => true
          target => 'rest'
        }
      }
    CONFIG
    end

    sample('message' => 'some text') do
      expect(subject).to include('rest')
      expect(subject.get('[rest][0]')).to include('userId')
      expect(subject.get('[rest][0][userId]')).to eq(10)
      expect(subject.get('rest')).to_not include('fallback')
    end
  end
  describe 'empty response' do
    let(:config) do <<-CONFIG
      filter {
        rest {
          request => {
            url => 'https://jsonplaceholder.typicode.com/posts'
            params => {
              userId => 0
            }
            headers => {
              'Content-Type' => 'application/json'
            }
          }
          target => 'rest'
        }
      }
    CONFIG
    end

    sample('message' => 'some text') do
      expect(subject).to_not include('rest')
      expect(subject.get('tags')).to include('_restfailure')
    end
  end
  describe 'Set to Rest Filter Get with params sprintf' do
    let(:config) do <<-CONFIG
      filter {
        rest {
          request => {
            url => 'https://jsonplaceholder.typicode.com/posts'
            params => {
              userId => "%{message}"
              id => "%{message}"
            }
            headers => {
              'Content-Type' => 'application/json'
            }
          }
          json => true
          target => 'rest'
        }
      }
    CONFIG
    end

    sample('message' => '1') do
      expect(subject).to include('rest')
      expect(subject.get('[rest][0]')).to include('userId')
      expect(subject.get('[rest][0][userId]')).to eq(1)
      expect(subject.get('[rest][0][id]')).to eq(1)
      expect(subject.get('rest').length).to eq(1)
      expect(subject.get('rest')).to_not include('fallback')
    end
  end
  describe 'Set to Rest Filter Post with params' do
    let(:config) do <<-CONFIG
      filter {
        rest {
          request => {
            url => 'https://jsonplaceholder.typicode.com/posts'
            method => 'post'
            params => {
              title => 'foo'
              body => 'bar'
              userId => 42
            }
            headers => {
              'Content-Type' => 'application/json'
            }
          }
          json => true
          target => 'rest'
        }
      }
    CONFIG
    end

    sample('message' => 'some text') do
      expect(subject).to include('rest')
      expect(subject.get('rest')).to include('id')
      expect(subject.get('[rest][userId]')).to eq(42)
      expect(subject.get('rest')).to_not include('fallback')
    end
  end
  describe 'Set to Rest Filter Post with params sprintf' do
    let(:config) do <<-CONFIG
      filter {
        rest {
          request => {
            url => 'https://jsonplaceholder.typicode.com/posts'
            method => 'post'
            params => {
              title => '%{message}'
              body => 'bar'
              userId => "%{message}"
            }
            headers => {
              'Content-Type' => 'application/json'
            }
          }
          json => true
          target => 'rest'
        }
      }
    CONFIG
    end

    sample('message' => '42') do
      expect(subject).to include('rest')
      expect(subject.get('rest')).to include('id')
      expect(subject.get('[rest][title]')).to eq(42)
      expect(subject.get('[rest][userId]')).to eq(42)
      expect(subject.get('rest')).to_not include('fallback')
    end
    sample('message' => ':5e?#!-_') do
      expect(subject).to include('rest')
      expect(subject.get('rest')).to include('id')
      expect(subject.get('[rest][title]')).to eq(':5e?#!-_')
      expect(subject.get('[rest][userId]')).to eq(':5e?#!-_')
      expect(subject.get('rest')).to_not include('fallback')
    end
    sample('message' => ':4c43=>') do
      expect(subject).to include('rest')
      expect(subject.get('rest')).to include('id')
      expect(subject.get('[rest][title]')).to eq(':4c43=>')
      expect(subject.get('[rest][userId]')).to eq(':4c43=>')
      expect(subject.get('rest')).to_not include('fallback')
    end
  end
  describe 'Set to Rest Filter Post with body sprintf' do
    let(:config) do <<-CONFIG
      filter {
        rest {
          request => {
            url => 'https://jsonplaceholder.typicode.com/posts'
            method => 'post'
            body => {
              title => 'foo'
              body => 'bar'
              userId => "%{message}"
            }
            headers => {
              'Content-Type' => 'application/json'
            }
          }
          json => true
          target => 'rest'
        }
      }
    CONFIG
    end

    sample('message' => '42') do
      expect(subject).to include('rest')
      expect(subject.get('rest')).to include('id')
      expect(subject.get('[rest][userId]')).to eq(42)
      expect(subject.get('rest')).to_not include('fallback')
    end
  end
  describe 'Set to Rest Filter Post with body sprintf nested params' do
    let(:config) do <<-CONFIG
      filter {
        rest {
          request => {
            url => 'https://jsonplaceholder.typicode.com/posts'
            method => 'post'
            body => {
              key1 => [
                {
                  "filterType" => "text"
                  "text" => "salmon"
                  "boolean" => false
                },
                {
                  "filterType" => "unique"
                }
              ]
              key2 => [
                {
                  "message" => "123%{message}"
                  "boolean" => true
                }
              ]
              key3 => [
                {
                  "text" => "%{message}123"
                  "filterType" => "text"
                  "number" => 44
                },
                {
                  "filterType" => "unique"
                  "null" => nil
                }
              ]
              userId => "%{message}"
            }
            headers => {
              'Content-Type' => 'application/json'
            }
          }
          target => 'rest'
        }
      }
    CONFIG
    end

    sample('message' => '42') do
      expect(subject).to include('rest')
      expect(subject.get('rest')).to include('key1')
      expect(subject.get('[rest][key1][0][boolean]')).to eq('false')
      expect(subject.get('[rest][key1][1][filterType]')).to eq('unique')
      expect(subject.get('[rest][key2][0][message]')).to eq('12342')
      expect(subject.get('[rest][key2][0][boolean]')).to eq('true')
      expect(subject.get('[rest][key3][0][text]')).to eq('42123')
      expect(subject.get('[rest][key3][0][filterType]')).to eq('text')
      expect(subject.get('[rest][key3][0][number]')).to eq(44)
      expect(subject.get('[rest][key3][1][filterType]')).to eq('unique')
      expect(subject.get('[rest][key3][1][null]')).to eq('nil')
      expect(subject.get('[rest][userId]')).to eq(42)
      expect(subject.get('rest')).to_not include('fallback')
    end
  end
  describe 'fallback' do
    let(:config) do <<-CONFIG
      filter {
        rest {
          request => {
            url => 'http://jsonplaceholder.typicode.com/users/0'
          }
          json => true
          fallback => {
            'fallback1' => true
            'fallback2' => true
          }
          target => 'rest'
        }
      }
    CONFIG
    end

    sample('message' => 'some text') do
      expect(subject).to include('rest')
      expect(subject.get('rest')).to include('fallback1')
      expect(subject.get('rest')).to include('fallback2')
      expect(subject.get('rest')).to_not include('id')
    end
  end
  describe 'empty target exception' do
    let(:config) do <<-CONFIG
      filter {
        rest {
          request => {
            url => 'http://jsonplaceholder.typicode.com/users/0'
          }
          json => true
          fallback => {
            'fallback1' => true
            'fallback2' => true
          }
          target => ''
        }
      }
    CONFIG
    end
    sample('message' => 'some text') do
      expect { subject }.to raise_error(LogStash::ConfigurationError)
    end
  end
  describe 'http client throws exception' do
    let(:config) do <<-CONFIG
      filter {
        rest {
          request => {
            url => 'invalid_url'
          }
          target => 'rest'
        }
      }
    CONFIG
    end
    sample('message' => 'some text') do
      expect(subject).to_not include('rest')
      expect(subject.get('tags')).to include('_restfailure')
    end
  end
end
