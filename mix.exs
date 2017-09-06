defmodule CloudWatch.Mixfile do
  use Mix.Project

  def project do
    [app: :cloud_watch,
     version: "0.2.3",
     elixir: "~> 1.5",
     build_embedded: Mix.env == :prod,
     start_permanent: Mix.env == :prod,
     deps: deps(),
     elixirc_paths: elixirc_paths(Mix.env),
     description: "Amazon CloudWatch-logger backend for Elixir",
     package: package()]
  end

  # Configuration for the OTP application
  #
  # Type "mix help compile.app" for more information
  def application do
    [applications: [:aws, :logger]]
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
    [{:aws, "~> 0.5.0"},
     {:credo, "~> 0.4.13", only: :dev},
     {:mock, "~> 0.2.0", only: :test},
     {:ex_doc, ">= 0.0.0", only: :dev}]
  end

  defp package do
    [name: :cloud_watch,
     maintainers: ["Laurens Boekhorst"],
     licenses: ["MIT"],
     links: %{"GitHub" => "https://github.com/lboekhorst/cloud_watch"}]
  end
end
