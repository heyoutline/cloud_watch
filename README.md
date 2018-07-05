# CloudWatch

`cloud_watch` is a logger backend for Elixir that puts log events on Amazon
CloudWatch.

## Installation

Add `cloud_watch` and `aws` to your list of dependencies in `mix.exs`:

  ```elixir
  def deps do
    [{:cloud_watch, "~> 0.2.7"},
    {:aws, "~> 0.5.0"}]
  end
  ```

Ensure `cloud_watch` is started before your application:

  ```elixir
  def application do
    [applications: [:cloud_watch]]
  end
  ```

## Configuration

Add the backend to `config.exs`:

  ```elixir
  config :logger,
    backends: [:console, CloudWatch],
    utc_log: true
  ```

Configure the following example to suit your needs:

  ```elixir
  config :logger, CloudWatch,
    access_key_id: "AKIAIOSFODNN7EXAMPLE",
    secret_access_key: "wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY",
    region: "eu-west-1",
    endpoint: "amazonaws.com",
    log_group_name: "api",
    log_stream_name: "production",
    max_buffer_size: 10_485,
    max_timeout: 60_000
  ```

The `endpoint` may be omitted from the configuration and will default to
`amazonaws.com`. The `max_buffer_size` controls when `cloud_watch` will flush
the buffer in bytes. You may specify anything up to a maximum of 1,048,576
bytes. If omitted, it will default to 10,485 bytes.

## Alternative AWS client library: ExAws

Default installation instructions assume that the [AWS](https://github.com/jkakar/aws-elixir) Elixir library will be used. If you have to (or prefer to) use [ExAws](https://github.com/ex-aws/ex_aws) instead, solution is really simple:
Replace `aws` with `ex-aws` in your list of dependencies in `mix.exs`:

  ```elixir
  def deps do
    [{:cloud_watch, "~> 0.2.7"},
    {:ex_aws, "~> 2.0"}]
  end
  ```

CloudWatch switches to ExAws automagically based on its presence at compile time. Just make sure that `aws` is not added as a dependency of another application in an umbrella project.


Note that `ExAws` resolves AWS credentials through its own configuration. As a consequence, following keys in CloudWatch configuration are not used:
- `access_key_id`
- `secret_access_key`
- `region`
- `endpoint`