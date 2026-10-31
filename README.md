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
builds booking links from `web_origin`, canonical listing slugs and the requested
stay. GraphQL does not need to provide a website URL. The schema owns public visibility, availability and price
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

Raise `CoreMcp::Error` for an expected tool refusal or
`CoreMcp::ArgumentError` for invalid inputs. Refusals become `isError` tool
results. Unexpected exceptions reach `error_reporter`; protocol refusals do
not. The default reporter writes the exception to stderr.

## Protocol and widget

| Tool | Use |
|---|---|
| `resolve_destination` | Turn a place name into a supported Guestit destination |
| `search_stays` | Search available stays with bounded inputs and results |
| `stay_details` | Read one stay's public details and an optional dated price |
| `compare_stays` | Compare a bounded selection of public stays |

`CoreMcp::Server` builds a fresh SDK server and stateless Streamable HTTP transport for each request. It registers
only the four catalog tools and the shared widget, and advertises the MCP Apps extension. No session or guest
identity survives between requests. The SDK validates successful tool results against their declared output schemas.

- `POST /mcp` carries one JSON-RPC message, with `Content-Type: application/json` and a JSON-capable `Accept` header.
- Legacy clients initialize normally and send their negotiated `MCP-Protocol-Version` on later requests. The pinned
  SDK also supports its modern sessionless discovery lifecycle.
- Responses use JSON. Notifications receive the SDK's empty acknowledgement.
- `GET /mcp` returns `405`, since the endpoint does not offer an SSE notification stream.
- Legacy `DELETE /mcp` returns the SDK's stateless disconnect acknowledgement, `200` with `{"success":true}`.
  Modern clients have no session to terminate and receive `405`.
- The SDK limits each request body to 32 KiB and handles JSON, protocol, method and schema errors.

The host owns routing and HTTP rate limits. It can use
`CoreMcp::Server.rate_limited_response(retry_after:)` for the JSON-RPC refusal
and HTTP headers.

The optional MCP App resource `ui://guestit/stays-v1.html` has MIME type `text/html;profile=mcp-app`. The same widget
renders search, detail and comparison results. A search renders inline as a carousel of up to ten cards with one
action each. Opening a stay or comparing stays asks the host for fullscreen when its `availableDisplayModes`
include it, and the widget returns to the cards when the host leaves fullscreen. Without fullscreen, details and
comparisons open inline with a Back button. After a detail read, a comparison or a booking link started in the
widget, it sends `ui/update-model-context`, so the model knows what the traveler looked at. Amounts and dates use
the host locale when it matches the result language, otherwise `en-GB` or `sv-SE`. Clients that do not render MCP
Apps can use the structured tool results and canonical listing links.

The widget header carries the Guestit logo. `serverInfo` carries the gem's `assets/icon.png` as a `data:` URI for hosts
that draw their own app label. The SDK leaves it out for protocol versions up to `2025-06-18`, so upload the same file
where a host's connector settings take an icon.

Tool refusals are plain sentences written for the model and shown in the widget. All MCP translations ship in the
gem under `core_mcp`, including input, catalog and quota messages. Argument refusals are English only.
The catalog's busy and failure messages follow the request locale. The widget replaces SDK schema errors with
its own request-error label.

The widget permits navigation only to `web_origin` and images only from
`image_origins`. The MCP server version remains `1.0.0`; the Ruby gem has its
own version.

## Connecting a client

For a local server on port 3001, this request negotiates the legacy protocol:

```sh
curl http://localhost:3001/mcp \
  -H 'Content-Type: application/json' \
  -H 'Accept: application/json, text/event-stream' \
  --data '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2025-11-25","capabilities":{},"clientInfo":{"name":"catalog-check","version":"1.0"}}}'
```

Then inspect the available tools:

```sh
curl http://localhost:3001/mcp \
  -H 'Content-Type: application/json' \
  -H 'Accept: application/json, text/event-stream' \
  -H 'MCP-Protocol-Version: 2025-11-25' \
  --data '{"jsonrpc":"2.0","id":2,"method":"tools/list"}'
```

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

Browser specs in `spec/features/stays_spec.rb` run in WebKit against
`spec/fixtures/mcp/host.html.erb`. The host embeds the actual widget and supplies
MCP Apps messages and tool responses. These specs check result updates, details,
comparisons, booking links with dates and guests, errors and host interactions
without Rails, a Core database or live provider calls. Core keeps request specs
for its endpoint and Ruby integration specs against its real public GraphQL schema.

The package check unpacks the built gem and loads it in a bundle containing only
its runtime dependencies.

Released under the [MIT License](LICENSE).
