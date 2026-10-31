require 'bundler'
require 'rbconfig'
require 'rubygems/package'
require 'tmpdir'

package = Gem::Package.new(ARGV.fetch(0))
bundle_path = Bundler.settings[:path]
check = <<~RUBY
  require 'core_mcp'
  abort 'Rails loaded' if defined?(Rails)
  I18n.t('core_mcp.catalog.busy', locale: :en, raise: true)
  I18n.t('core_mcp.quota.caller', locale: :sv, raise: true)
  puts 'Runtime-only package and translations load without Rails'
RUBY

Dir.mktmpdir('core-mcp-runtime') do |directory|
  package_root = File.join(directory, 'package')
  package.extract_files(package_root)
  File.write(File.join(package_root, 'core-mcp.gemspec'), package.spec.to_ruby)
  gemfile = File.join(directory, 'Gemfile')
  contents = <<~GEMFILE
    source 'https://rubygems.org'

    gem 'core-mcp', path: #{package_root.inspect}
  GEMFILE
  File.write(gemfile, contents)
  environment = {
    'BUNDLE_GEMFILE' => gemfile,
    'BUNDLE_PATH' => bundle_path
  }
  install = [RbConfig.ruby, '-S', 'bundle', 'install', '--local']
  verify = [RbConfig.ruby, '-S', 'bundle', 'exec', RbConfig.ruby, '-e', check]

  Bundler.with_unbundled_env do
    abort 'Runtime bundle failed' unless system(environment, *install)
    abort 'Runtime load failed' unless system(environment, *verify)
  end
end
