class CoreMcp::Config
  attr_reader :catalog, :quota, :web_origin, :image_origins
  attr_accessor :allowed_hosts, :error_reporter

  # @rbs (catalog: CoreMcp::_CatalogFactory, quota: CoreMcp::_QuotaFactory, web_origin: ::String, image_origins: ::Array[::String]) -> void
  def initialize(catalog:, quota:, web_origin:, image_origins:)
    @catalog = catalog
    @quota = quota
    @web_origin = web_origin
    @image_origins = image_origins
    @allowed_hosts = []
    @error_reporter = ->(error, _context) { warn(error.full_message) }
  end
end
