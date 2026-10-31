# core-mcp

Guestit's public MCP server and MCP App for finding destinations, searching
stays, reading details and comparing dated prices. Booking continues on the
Guestit website. The host supplies the catalog and quotas; the gem has no
Rails, database or Redis dependency.

## Installation

```ruby
gem 'core-mcp', github: 'guestitab/core-mcp', branch: 'production', require: 'core_mcp'
```

The lockfile pins the production commit. Development happens on `staging`;
`production` carries released versions. GitHub releases include the built `.gem`.

## Hosting

Create a configuration with the catalog and quota classes implemented by the
host. They are instantiated for each tool call with `server_context:`.

```ruby
configuration = CoreMcp::Config.new(
  catalog: MyCatalog,
  quota: MyQuota,
  web_origin: 'https://guestit.se',
  image_origins: ['https://images.example.com']
)
configuration.allowed_hosts = ['api.example.com']
configuration.error_reporter = ->(error, context) { MyErrorReporter.report(error, context) }

server = CoreMcp::Server.new(configuration:)
context = {
  ip_address: request.ip,
  user_agent: request.user_agent,
  ai_platform: nil,
  today: Date.today
}
status, headers, body = server.call(request:, server_context: context)
```

`request` is a Rack-compatible request. Use the host's trusted-proxy IP and
current date in its booking time zone. Keep reloaded application classes in a
request-scoped configuration. The SDK adds tool-call `_meta` to the context
before instantiating the catalog and quota.

The catalog implements `resolve_destination(inputs)`, `search_stays(inputs)`,
`stay_details(inputs)` and `compare_stays(inputs)`. `CoreMcp::Inputs` exposes
`arguments`, `locale`, `dated?` and `stay`. Results are hashes matching the
schemas in `CoreMcp::Tools::Schemas`, with amounts in minor units, plain text
and complete website URLs. The host owns query execution, public visibility,
price calculation, availability checks and destination validation.

The quota implements `spend!(locale)`. The host owns shared counters and the
trust decision for `ai_platform`. In Guestit Core the label comes from an edge
that blocks client-supplied platform headers. An unverified client header
must not bypass the host's IP limit.

Raise `CoreMcp::Error` for an expected tool refusal or
`CoreMcp::ArgumentError` for invalid inputs. Refusals become `isError` tool
results. Unexpected exceptions reach `error_reporter`; protocol refusals do
not. The default reporter writes the exception to stderr.

## Protocol and widget

The server creates a fresh stateless Streamable HTTP transport for each
request, returns JSON and limits request bodies to 32 KiB. Host and origin
checks remain enabled. The host owns routing and HTTP rate limits.

The tools are `resolve_destination`, `search_stays`, `stay_details` and
`compare_stays`. Stay tools reference `ui://guestit/stays-v1.html`, with MIME
type `text/html;profile=mcp-app`. The packaged widget supports English and
Swedish, inline cards, fullscreen details and comparison, and model-context
updates. It permits navigation only to `web_origin` and images only from
`image_origins`.

The MCP server version remains `1.0.0`. The Ruby gem has its own version.

## Development

```sh
bundle install
bun install
bin/playwright install webkit
bundle exec rake
bundle exec rbs collection install
bundle exec steep check --no-daemon -j 2
gem build core-mcp.gemspec
```

Browser specs run in WebKit against a local MCP Apps host fixture. The
catalog and quota are test doubles; no live provider calls are made.

Released under the [MIT License](LICENSE).
