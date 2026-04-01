import Config

# Runtime configuration stays generic on purpose.
#
# The framework should not enumerate every concrete provider here.
# Instead, the consuming application or local runtime setup can configure
# whichever provider it wants by setting:
#
#   config :nexus, :provider,
#     adapter: SomeProviderModule,
#     config: %{...}
#
# Example:
#
#   config :nexus, :provider,
#     adapter: Nexus.Providers.Anthropic,
#     config: %{
#       api_key: System.fetch_env!("ANTHROPIC_API_KEY"),
#       model: "claude-sonnet-4-20250514",
#       max_tokens: 1024
#     }
