# Logstash REST Filter

This is a filter plugin for [Logstash](https://github.com/elasticsearch/logstash).

It is fully free and fully open source. The license is Apache 2.0, meaning you are pretty much free to use it however you want in whatever way.

## Documentation

This logstash filter provides an easy way to access RESTful Resources within logstash. It can be used to post data to a REST API or to gather data and save it in your log file.

## Usage
### 1. Installation
You can use the built-in plugin tool of Logstash to install the filter:
```
$LS_HOME/bin/plugin install logstash-filter-rest
```

Or you can build it yourself:
```
git clone https://github.com/lucashenning/logstash-filter-rest.git
bundle install
gem build logstash-filter-rest.gemspec
$LS_HOME/bin/plugin install logstash-filter-rest-0.1.0.gem
```

### 2. Filter Configuration
Add the following inside the filter section of your logstash configuration:

```sh
rest {
  url => "http://example.com"       # string (required, with field reference: "http://example.com?id=%{id}")
  json => true                      # boolean (optional, default = false)
  method => "post"                  # string (optional, default = "get")
  sprintf => true                   # boolean (optional, default = false, set this to true if you want to use field references in url, header or params
  header => {                       # hash (optional)
    "key1" => "value1"
    "key2" => "value2"
    "key3" => "%{somefield}"        # Please set sprintf to true if you want to use field references
  }
  params => {                       # hash (optional, only available for method => "post")
    "key1" => "value1"
    "key2" => "value2"
    "key3" => "%{somefield}"        # Please set sprintf to true if you want to use field references
  }
}
```
### 3. Accessing the result
If you are expecting a single output and 'json => false' you will get a logstash field called 'response' which contains the result.
If 'json => true' you will get a new logstash field for each key.

## Contributing

All contributions are welcome: ideas, patches, documentation, bug reports, complaints, and even something you drew up on a napkin.

Programming is not a required skill. Whatever you've seen about open source and maintainers or community members  saying "send patches or die" - you will not see that here.

It is more important to the community that you are able to contribute.

For more information about contributing, see the [CONTRIBUTING](https://github.com/elasticsearch/logstash/blob/master/CONTRIBUTING.md) file.
