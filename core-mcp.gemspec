require_relative 'lib/core_mcp/version'

Gem::Specification.new do |spec|
  spec.name = 'core-mcp'
  spec.version = CoreMcp::VERSION
  spec.authors = ['Guestit']
  spec.summary = 'Public stay discovery through MCP'
  spec.description = 'Guestit MCP tools and an MCP App for searching and comparing stays, backed by the public Core GraphQL schema.'
  spec.license = 'MIT'
  spec.homepage = 'https://github.com/guestitab/core-mcp'
  spec.required_ruby_version = '>= 4.0'
  spec.metadata['allowed_push_host'] = 'https://rubygems.org'
  spec.metadata['source_code_uri'] = 'https://github.com/guestitab/core-mcp'
  spec.metadata['rubygems_mfa_required'] = 'true'

  spec.files = %w[LICENSE README.md] + Dir['lib/**/*.rb', 'sig/**/*.rbs', 'sig/**/*.yaml', 'assets/**/*', 'locales/*.yml'].select { |path| File.file?(path) }
  spec.require_paths = ['lib']

  spec.add_dependency 'base64', '~> 0.3'
  spec.add_dependency 'date', '~> 3.6'
  spec.add_dependency 'erb', '~> 6.0'
  spec.add_dependency 'i18n', '~> 1.15'
  spec.add_dependency 'json', '~> 3.1'
  spec.add_dependency 'loofah', '~> 2.25'
  spec.add_dependency 'mcp', '~> 1.7.0'
  spec.add_dependency 'nokogiri', '~> 1.19'
  spec.add_dependency 'rack', '~> 3.2'
  spec.add_dependency 'uri', '~> 1.1'
end
