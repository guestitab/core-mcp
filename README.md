# core-mcp

Guestit's public MCP server and MCP App for finding destinations, searching
stays, reading details and comparing dated prices. Booking continues on the
Guestit website. The gem owns catalog queries, result mapping, quotas and
translations. The host supplies its public GraphQL schema and shared cache.
The gem has no Rails, database or Redis dependency.

## Installation

```ruby
gem 'core-mcp', github: 'guestitab/core-mcp', branch: 'production', require: 'core_mcp'
```

The lockfile pins the production commit. Development happens on `staging`;
`production` carries released versions. GitHub releases include the built `.gem`.

## Hosting

Pass the Core GraphQL schema and a shared cache to the configuration.

```ruby
configuration = CoreMcp::Config.new(
  schema: CoreSchema,
  cache: Rails.cache,
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
before the gem executes a tool and spends its quota.

`CoreMcp::Catalog` executes fixed anonymous documents through `schema.execute`
and `schema.multiplex`. It reads `storedLocation`, `availableListings` and
`showListing`, maps their public data into the tool schemas, cleans HTML and
builds booking links. The schema owns public visibility, availability and price
calculation. Destination lookup uses `storedLocation(query:, id:)`, which reads
local visible locations without a provider call. A query finds one location
with homes; an id checks that the requested location is visible.

`CoreMcp::Quota` uses `cache.increment(key, amount, expires_in:)`. Counters must
be shared between host processes and expire after 60 seconds. The limits are
30 calls per caller and 300 total. Trusted OpenAI user subjects have separate
allowances; other AI platform calls without a subject count toward the total.
Direct clients use their IP address. The host supplies the trust decision for
`ai_platform`. In Guestit Core the label comes from an edge that blocks
client-supplied platform headers. An unverified client header must not bypass
the host's IP limit.

All MCP translations ship under `core_mcp` in the gem. Input and catalog
argument refusals are English only. Busy, failure and quota messages follow
the requested English or Swedish locale.

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
bundle exec ruby script/check_package.rb core-mcp-<version>.gem
```

Browser specs run in WebKit against a local MCP Apps host fixture. The
widget host and GraphQL responses are fixtures; no live provider calls are made. The package
check unpacks the built gem and loads it in a bundle containing only its runtime
dependencies.

Released under the [MIT License](LICENSE).
