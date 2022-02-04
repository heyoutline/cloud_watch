defmodule CloudWatch.Mixfile do
  use Mix.Project

  def project do
    [
      app: :cloud_watch,
      version: "0.4.1",
      elixir: "~> 1.6",
      build_embedded: Mix.env() == :prod,
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      elixirc_paths: elixirc_paths(Mix.env()),
      description: "Amazon CloudWatch-logger backend for Elixir",
      package: package(),
      lockfile: lockfile()
    ]
  end

  # Configuration for the OTP application
  #
  # Type "mix help compile.app" for more information
  def application do
    cond do
      Code.ensure_loaded?(AWS) ->
        [extra_applications: [:logger, :aws]]

      Code.ensure_loaded?(ExAws) ->
        [extra_applications: [:logger, :ex_aws]]
    end
  end

  # This makes sure your factory and any other modules in test/support are compiled
  # when in the test environment.
  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  # Dependencies can be Hex packages:
  #
  #   {:mydep, "~> 0.3.0"}
  #
  # Or git/path repositories:
  #
  #   {:mydep, git: "https://github.com/elixir-lang/mydep.git", tag: "0.1.0"}
  #
  # Type "mix help deps" for more examples and options
  defp deps do
    [
      {:aws, "<= 0.7.0 or ~> 0.8", optional: true},
      # Include mime for ex_aws; mime 2.x requires Elixir ~> 1.10
      {:mime, "<= 1.2.0 or ~> 2.0", optional: true},
      {:ex_aws, "~> 2.2", optional: true},
      {:httpoison, ">= 0.11.1"},
      {:telemetry, "<= 0.4.3 or ~> 1.0"},
      {:credo, "~> 1.4.0", only: :dev},
      {:mock, "~> 0.3.5", only: :test},
      {:ex_doc, "~> 0.22", only: :dev, runtime: false}
    ]
  end

  defp lockfile do
    cond do
      Version.match?(System.version(), "< 1.10.0") ->
        "mix_legacy.lock"
      true ->
        "mix.lock"
    end
  end

  defp package do
    [
      name: :cloud_watch,
      maintainers: ["Josh Kuiros", "Peter Menhart"],
      licenses: ["MIT"],
      links: %{"GitHub" => "https://github.com/heyoutline/cloud_watch"}
    ]
  end
end
