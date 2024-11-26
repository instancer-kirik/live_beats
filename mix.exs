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

  def application do
    [
      mod: {LiveBeats.Application, []},
      extra_applications: [:logger, :runtime_tools]
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp deps do
    [
      {:phoenix, "~> 1.7.14"},
      {:dns_cluster, "~> 0.1.1"},
      {:phoenix_live_view, "~> 0.20.17"},
      {:phoenix_live_dashboard, "~> 0.8.5"},
      {:phoenix_ecto, "~> 4.5"},
      {:ecto_sql, "~> 3.11"},
      {:ecto_network, "~> 1.3.0"},
      {:postgrex, ">= 0.0.0"},
      {:phoenix_html, "~> 4.0"},
      {:phoenix_html_helpers, "~> 1.0.1"},
      {:phoenix_live_reload, "~> 1.5", only: :dev},
      {:floki, ">= 0.30.0", only: :test},
      {:esbuild, "~> 0.8", runtime: Mix.env() == :dev},
      {:swoosh, "~> 1.14"},
      {:finch, "~> 0.18"},
      {:telemetry_metrics, "~> 1.0"},
      {:telemetry_poller, "~> 1.0"},
      {:gettext, "~> 0.23"},
      {:blockchain_core, in_umbrella: true},
      {:jason, "~> 1.4"},
      {:plug_cowboy, "~> 2.7.2"},
      {:mint, "~> 1.5"},
      {:heroicons, "~> 0.5.6"},
      {:bandit, "~> 1.2"},
      {:castore, "~> 1.0", override: true},
      {:tailwind, "~> 0.2.4"},
      {:req, "~> 0.4"},
      {:flame, "~> 0.3.0"},
      {:nx, "~> 0.9.2"},
      {:bumblebee, "~> 0.6.0"},
      {:acts, in_umbrella: true},
      {:multiaddr, "~> 1.1"},
      {:protobuf, "~> 0.10"},
      {:mishka_chelekom, "~> 0.0.1", only: [:dev, :test]}
    ]
  end

  defp aliases do
    [
      setup: ["deps.get", "ecto.setup", "assets.setup", "assets.build"],
      "ecto.setup": ["ecto.create", "ecto.migrate", "run priv/repo/seeds.exs"],
      "ecto.reset": ["ecto.drop", "ecto.setup"],
      test: ["ecto.create --quiet", "ecto.migrate --quiet", "test"],
      "assets.setup": ["esbuild.install --if-missing"],
      "assets.build": ["esbuild default"],
      "assets.deploy": ["esbuild default --minify", "phx.digest"]
    ]
  end
end
