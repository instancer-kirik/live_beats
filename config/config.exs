# This file is responsible for configuring your application
# and its dependencies with the aid of the Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
import Config

config :live_beats,
  ecto_repos: [LiveBeats.Repo]

# Configure Ecto to use binary_id by default
config :live_beats, LiveBeats.Repo,
  migration_primary_key: [type: :binary_id],
  migration_foreign_key: [type: :binary_id]

config :live_beats, :files, admin_usernames: []

# Configures the endpoint
config :live_beats, LiveBeatsWeb.Endpoint,
  url: [host: "localhost"],
  secret_key_base: "55naB2xjgnsDeN+kKz7xoeqx3vIPcpCkAmg+CoVR/F7iZ5MQgNE6ykiNXoFa7wcC",
  pubsub_server: LiveBeats.PubSub,
  live_view: [signing_salt: "_CLvmXLvmXpMV1yHv+J+"],
  render_errors: [
    formats: [html: LiveBeatsWeb.ErrorHTML, json: LiveBeatsWeb.ErrorJSON],
    layout: false
  ]

config :esbuild,
  version: "0.12.18",
  default: [
    args: ~w(js/app.js --bundle --outdir=../priv/static/assets),
    cd: Path.expand("../assets", __DIR__),
    env: %{"NODE_PATH" => Path.expand("../deps", __DIR__)}
  ]

# Configure tailwind (the version is required)
config :tailwind,
  version: "3.2.7",
  default: [
    args: ~w(
      --config=tailwind.config.js
      --input=css/app.css
      --output=../priv/static/assets/app.css
    ),
    cd: Path.expand("../assets", __DIR__)
  ]

# Configures Elixir's Logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"

config :live_beats,
  stream_host: System.get_env("STREAM_HOST", "localhost"),
  rtmp_port: String.to_integer(System.get_env("RTMP_PORT", "1935")),
  hls_port: String.to_integer(System.get_env("HLS_PORT", "8080")),
  stream_storage_path: System.get_env("STREAM_STORAGE_PATH", "priv/static/streams")

config :live_beats, LiveBeats.Streaming.NodeManager,
  bootstrap_nodes: [
    "/ip4/104.131.131.82/tcp/4001/p2p/QmaCpDMGvV2BGHeYERUEnRQAwe3N8SzbUtfsmvsqQLuvuJ",
    # Add more bootstrap nodes
  ],
  swarm_port: 4001,
  enable_relay: true
