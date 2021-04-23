<div align="right">

GitHub build status:
[![Elixir CI](https://github.com/lboekhorst/cloud_watch/actions/workflows/elixir.yml/badge.svg)](https://github.com/lboekhorst/cloud_watch/actions/workflows/elixir.yml)
</div>

# CloudWatch

`cloud_watch` is a logger backend for Elixir that puts log events on Amazon
CloudWatch.

## Installation

Add `cloud_watch` and `aws` to your list of dependencies in `mix.exs`:

  ```elixir
  def deps do
    [{:cloud_watch, "~> 0.4.0"},
     {:aws, "~> 0.6.0"}]
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
    max_timeout: 60_000,
    metadata: [:m1, :m2],
    metadata_filter: [module: MyModule]
  ```

Multiple `CloudWatch` backends can be specified by adding tuples in the
format `{CloudWatch, :backend_name}`:

  ```elixir
  config :logger,
    utc_log: true,
    backends: [
      :console,
      {CloudWatch, :cloud_error},
      {CloudWatch, :cloud_debug}
    ]

  config :logger, cloud_error,
    level: :error
    # other options

  config :logger, cloud_debug,
    level: :debug
    # other options
  ```

The `endpoint` may be omitted from the configuration and will default to
`amazonaws.com`. The `max_buffer_size` controls when `cloud_watch` will flush
the buffer in bytes. You may specify anything up to a maximum of 1,048,576
bytes. If omitted, it will default to 10,485 bytes.

The `metadata` parameter selects which metadata should be printed with the
log message. The `metadata_filter` specifies instead metadata terms which must
be present in order to log.

### Dynamic log stream names
Some applications need more flexibility in `log_stream_name`, incl. ability to change the name dynamically (e.g. every day or every hour).\
If you configure log_stream_name as a tuple `{module, function, args}` (MFA), then the function will be invoked and its return value used as the stream name.

Similar configuration can be used for `log_group_name` as well. \
For example:
  ```elixir
  config :logger, CloudWatch,
    log_group_name: {MyDynamicNaming, :append_node_name, ["/aws/ec2/my-app-logs/"]},
    log_stream_name: {MyDynamicNaming, :get_log_stream_name_change_every_day, []}

  defmodule MyDynamicNaming do
    def append_node_name(value), do: "#{value}#{node()}"
    def get_log_stream_name_change_every_day(), do: "#{Date.utc_today()}/my-log-stream"
  end
```

## Alternative AWS client library: ExAws

Default installation instructions assume that the [AWS](https://github.com/jkakar/aws-elixir) Elixir library will be used. If you have to (or prefer to) use [ExAws](https://github.com/ex-aws/ex_aws) instead, solution is really simple:
Replace `aws` with `ex-aws` in your list of dependencies in `mix.exs`:

  ```elixir
  def deps do
    [{:cloud_watch, "~> 0.4.0"},
    {:ex_aws, "~> 2.2"}]
  end
  ```

CloudWatch switches to ExAws automagically based on its presence at compile time. Just make sure that `aws` is not added as a dependency of another application in an umbrella project.


Note that `ExAws` resolves AWS credentials through its own configuration. As a consequence, following keys in CloudWatch configuration are not used:
- `access_key_id`
- `secret_access_key`
- `region`
- `endpoint`

### ExAws requires valid AWS keys in order to work properly
This statement seems obvious, but it may be useful to understand
how the system behaves when the configuration is not right:

Logger uses a build-in supervisor that is well capable of handling most problems.
For example, network connection issues or invalid AWS keys seems to be treated well,
with meaningful messages logged to other backend (console or file).
If the error is transient, messages are sent to CloudWatch logs after recovery.

When ExAws cannot find the AWS secret key through the credential resolution process
(see ExAws documentation for details), the initial error message makes sense:
```
** (EXIT) an exception was raised:
           ** (RuntimeError) Instance Meta Error: {:error, %{reason: :connect_timeout}}

   You tried to access the AWS EC2 instance meta, but it could not be reached.
   This happens most often when trying to access it from your local computer,
   which happens when environment variables are not set correctly prompting
   ExAws to fallback to the Instance Meta.

   Please check your key config and make sure they're configured correctly
```
However, you'll experience a flood of errors and sasl reports,
as both Logger and ExAws supervisors are busy restarting children over and over.
Finding the root cause is a challenge, as the subsequent error messages are misleading:
":ehostdown", "argument error", ":badarg, {:ets, :lookup}".

Missing AWS keys is a permanent error (unless the keys can magically show up in your app),
hence should be caught early during deployment.
Our advice is to add an AWS call to the application start logic.
This can be an application specific request (especially when the application talks
to AWS for other services), or just a dummy AWS call.
Alternatively, the ExAws configuration can be tested without calling AWS, e.g.
```elixir
ExAws.Auth.validate_config(ExAws.Config.new(:logs, []))
```
