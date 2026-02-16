defmodule App.Application do
  @moduledoc false
  use Application

  @impl true
  def start(_type, _args) do
    children = [
      App.Repo,
      {Phoenix.PubSub, name: App.PubSub},
      AppWeb.Telemetry,
      AppWeb.Endpoint,
      App.IRCBridge
    ]

    opts = [strategy: :one_for_one, name: App.Supervisor]
    Supervisor.start_link(children, opts)
  end

  @impl true
  def config_change(changed, _new, removed) do
    AppWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
