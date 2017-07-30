## 0.5.3
  - freeze all instance variables
  - fix parallel processing by creating a `deep_clone` for each event
  - use `LogStash::Util.deep_clone` for object cloning
  - only dump body as json, if json is enabled in config (default)
  - delete empty target testcase, as catched by upper logstash `LogStash::ConfigurationError`
  - fix `sprintf` find and merge for more complex structures

## 0.5.2
  - Fix behavior, where a referenced field (`%{...}`) has `ruby` chars
  (i.e., consisting of `:`)
  - Field interpolation is done by assigning explicit values instead
  of converting the `sprintf` string back into a `hash`

## 0.5.0
  - Relax constraint on logstash-core-plugin-api to >= 1.60 <= 2.99
  - Require devutils >= 0 to make `bundler` update the package
  - Use Event API for LS-5
  - Implicit `sprintf`, deprecating the setting
  - `target` is now required, dropping support to write into top-level in favor of only using new Event API
    - this follows other logstash-plugins like `logstash-filter-json`
  - if the response is empty, add the restfailure tags
  - Some logging moved before code
  - Testcases adapted to new behavior with error check
