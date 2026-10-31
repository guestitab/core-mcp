require 'base64'
require 'date'
require 'erb'
require 'i18n'
require 'json'
require 'loofah'
require 'mcp'
require 'nokogiri'
require 'rack'
require 'uri'

require_relative 'core_mcp/version'
require_relative 'core_mcp/error'
require_relative 'core_mcp/config'
require_relative 'core_mcp/inputs'
require_relative 'core_mcp/documents'
require_relative 'core_mcp/catalog'
require_relative 'core_mcp/catalog/price'
require_relative 'core_mcp/catalog/stay'
require_relative 'core_mcp/quota'
require_relative 'core_mcp/widget'

module CoreMcp::Tools
end

require_relative 'core_mcp/tools/schemas'
require_relative 'core_mcp/tools/base'
require_relative 'core_mcp/tools/resolve_destination'
require_relative 'core_mcp/tools/search_stays'
require_relative 'core_mcp/tools/stay_details'
require_relative 'core_mcp/tools/compare_stays'
require_relative 'core_mcp/server'

I18n.load_path.concat(Dir[File.expand_path('../locales/*.yml', File.dirname(__FILE__))])
