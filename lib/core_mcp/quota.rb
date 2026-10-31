class CoreMcp::Quota
  OPENAI = 'openai'.freeze #: ::String
  SUBJECT = :'openai/subject' #: ::Symbol
  PER_CALLER = 30 #: ::Integer
  TOTAL = 300 #: ::Integer
  WINDOW = 60 #: ::Integer

  # @rbs (server_context: CoreMcp::server_context) -> void
  def initialize(server_context:)
    configuration = server_context[:configuration] #: CoreMcp::Config

    @server_context = server_context
    @cache = configuration.cache
  end

  # @rbs (::String locale) -> void
  def spend!(locale)
    key = caller_key

    raise CoreMcp::Error, I18n.t('core_mcp.quota.total', locale:) if over?('total', TOTAL)
    raise CoreMcp::Error, I18n.t('core_mcp.quota.caller', locale:) if key && over?(key, PER_CALLER)
  end

  private

  # @rbs () -> ::String?
  def caller_key
    platform = @server_context[:ai_platform]
    subject = @server_context[:_meta]&.[](SUBJECT)
    return "openai:#{subject}" if platform == OPENAI && subject.is_a?(::String) && !subject.strip.empty?
    return nil if platform && !platform.strip.empty?

    "ip:#{@server_context[:ip_address]}"
  end

  # @rbs (::String key, ::Integer limit) -> bool
  def over?(key, limit)
    count = @cache.increment("mcp:tool-calls:#{key}", 1, expires_in: WINDOW)
    count.to_i > limit
  end
end
