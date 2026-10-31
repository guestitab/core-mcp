class CoreMcp::Config
  attr_reader :schema, :cache, :web_origin, :image_origins
  attr_accessor :allowed_hosts, :error_reporter

  # @rbs (schema: CoreMcp::_Schema, cache: CoreMcp::_Cache, web_origin: ::String, image_origins: ::Array[::String]) -> void
  def initialize(schema:, cache:, web_origin:, image_origins:)
    @schema = schema
    @cache = cache
    @web_origin = web_origin
    @image_origins = image_origins
    @allowed_hosts = []
    @error_reporter = ->(error, _context) { warn(error.full_message) }
  end
end
