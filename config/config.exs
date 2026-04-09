import Config

config :nexus, :provider,
  adapter: Nexus.Providers.Fake,
  config: %{}

config :nexus, :session_store,
  adapter: Nexus.SessionStores.InMemory,
  config: %{}

config :nexus, :transcript_store,
  adapter: Nexus.TranscriptStores.InMemory,
  config: %{}

config :nexus, :system_tools, []
