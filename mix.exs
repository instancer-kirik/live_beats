defmodule LiveBeats.MixProject do
  use Mix.Project

  def project do
    [
      app: :live_beats,
      version: "0.1.1",
      elixir: "~> 1.12",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      aliases: aliases(),
      deps: deps()
    ]
  end

  # Configuration for the OTP application.
  #
  # Type `mix help compile.app` for more information.
  def application do
    [
      mod: {LiveBeats.Application, []},
      extra_applications: [:logger, :runtime_tools]
    ]
  end

  # Specifies which paths to compile per environment.
  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  # Specifies your project dependencies.
  #
  # Type `mix help deps` for examples and options.
  defp deps do
    [
      {:phoenix, "~> 1.7.12"},
      {:dns_cluster, "~> 0.1.1"},
      {:phoenix_live_view, "~> 0.20.17"},
      {:phoenix_live_dashboard, "~> 0.8.3"},
      {:phoenix_ecto, "~> 4.4"},
      {:ecto_sql, "~> 3.11"},
      {:ecto_network, "~> 1.3.0"},
      {:postgrex, ">= 0.0.0"},
      {:phoenix_html, "~> 4.0"},
      {:phoenix_live_reload, "~> 1.4", only: :dev},
      {:floki, ">= 0.30.0", only: :test},
      {:esbuild, "~> 0.8", runtime: Mix.env() == :dev},
      {:swoosh, "~> 1.14"},
      {:finch, "~> 0.18"},
      {:telemetry_metrics, "~> 1.0"},
      {:telemetry_poller, "~> 1.0"},
      {:gettext, "~> 0.23"},
      {:jason, "~> 1.4"},
      {:plug_cowboy, "~> 2.6"},
      {:mint, "~> 1.5"},
      {:heroicons, "~> 0.2.2"},
      {:bandit, "~> 1.2"},
      {:castore, "~> 1.0"},
      {:tailwind, "~> 0.2.1"},
      {:bumblebee, github: "elixir-nx/bumblebee"},
      {:exla, ">= 0.0.0"},
      {:req, "~> 0.4"},
      {:flame, "~> 0.3.0"},
      {:libp2p, "~> 0.1.0"},
      {:ipfs, "~> 0.1.0"},
      {:multiaddr, "~> 1.0"},
      {:protobuf, "~> 0.8"}
    ]
  end

  # Aliases are shortcuts or tasks specific to the current project.
  # For example, to install project dependencies and perform other setup tasks, run:
  #
  #     $ mix setup
  #
  # See the documentation for `Mix` for more info on aliases.
  defp aliases do
    [
      setup: ["deps.get", "ecto.setup"],
      "ecto.setup": ["ecto.create", "ecto.migrate", "run priv/repo/seeds.exs"],
      "ecto.reset": ["ecto.drop", "ecto.setup"],
      test: ["ecto.create --quiet", "ecto.migrate --quiet", "test"],
      "assets.deploy": [
        "tailwind default --minify",
        "esbuild default --minify",
        "phx.digest"
      ]
    ]
  end
end
