defmodule Nomure.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  def start(_type, _args) do
    # List all child processes to be supervised
    children = [
      # Starts a worker by calling: Nomure.Worker.start_link(arg)
      # {Nomure.Worker, arg},
      {Registry, keys: :unique, name: Registry.GraphNodeNames}
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Nomure.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
