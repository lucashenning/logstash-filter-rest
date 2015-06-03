# Logstash REST Filter

This is a filter plugin for [Logstash](https://github.com/elasticsearch/logstash).

It is fully free and fully open source. The license is Apache 2.0, meaning you are pretty much free to use it however you want in whatever way.

## Documentation

This logstash filter provides an easy way to access RESTful Resources within logstash. It can be used to post data to a REST API or to gather data and save it in your log file.

## Usage
### 1. Installation

### 2. Filter Configuration
Add the following inside the filter section of your logstash configuration:

```sh
rest {
  url => "http://icanhazip.com"     # string (required)
  json => true                      # boolean (optional, default = false)
  method => "post"                  # string (optional, default = "get")
  header => 
}
```
### 3. Accessing the result


## Contributing

All contributions are welcome: ideas, patches, documentation, bug reports, complaints, and even something you drew up on a napkin.

Programming is not a required skill. Whatever you've seen about open source and maintainers or community members  saying "send patches or die" - you will not see that here.

It is more important to the community that you are able to contribute.

For more information about contributing, see the [CONTRIBUTING](https://github.com/elasticsearch/logstash/blob/master/CONTRIBUTING.md) file.
