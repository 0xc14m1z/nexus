import Config

config :nexus, :provider,
  adapter: Nexus.Providers.Fake,
  config: %{}
