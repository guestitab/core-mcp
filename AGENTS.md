# core-mcp

The gem owns Guestit's public MCP tools, schemas and widget. The host supplies
a catalog, a quota, request metadata and allowed origins. Keep Rails, database,
Redis and Core application constants in the host.

Use `bundle exec rake` for specs and RuboCop. Browser specs use WebKit through
`bin/playwright`; run `bun install` and `bin/playwright install webkit` first.
Run `bundle exec steep check` after changing Ruby or RBS. Build with
`gem build core-mcp.gemspec` and verify assets in the built package.

Preserve tool names, JSON schemas and the `ui://guestit/stays-v1.html` resource
when extracting code. Pass the host's current date for each request. Store
request dependencies in the SDK server context, and keep configuration scoped
to the server instance.

Changes to widget templates must preserve HTML escaping of configuration and
the origin checks for navigation, images and host messages. Specs use a local
test host and make no live provider calls.
