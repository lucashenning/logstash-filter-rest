## 0.5.0
  - Relax constraint on logstash-core-plugin-api to >= 1.60 <= 2.99
  - Require devutils >= 0 to make `bundler` update the package
  - Use Event API for LS-5
  - Implicit `sprintf`, deprecating the setting
  - `target` is now required, dropping support to write into top-level in favor of only using new Event API
    - this follows other logstash-plugins like `logstash-filter-json`
  - Some logging moved before code
  - Testcases adapted to new behavior with error check
