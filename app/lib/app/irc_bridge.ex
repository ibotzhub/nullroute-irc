defmodule App.IRCBridge do
  @moduledoc """
  Redis Pub/Sub bridge between Phoenix and Go IRC gateway
  """
  use GenServer
  require Logger

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  def init(_state) do
    {:ok, redis} = Redix.start_link(host: "localhost", port: 6379)
    {:ok, pubsub} = Redix.PubSub.start_link()
    {:ok, %{redis: redis, pubsub: pubsub, subscriptions: %{}}}
  end

  def send_command(user_id, command_type, data) do
    GenServer.cast(__MODULE__, {:send_command, user_id, command_type, data})
  end

  def subscribe_events(user_id, pid) do
    GenServer.call(__MODULE__, {:subscribe, user_id, pid})
  end

  def unsubscribe_events(user_id) do
    GenServer.call(__MODULE__, {:unsubscribe, user_id})
  end

  def handle_cast({:send_command, user_id, command_type, data}, state) do
    require Logger
    Logger.info("🟢 IRCBridge PUBLISH commands:#{user_id} type=#{command_type}")

    command = %{
      type: command_type,
      data: data,
      user_id: user_id
    }
    |> Jason.encode!()

    channel = "commands:#{user_id}"
    case Redix.command(state.redis, ["PUBLISH", channel, command]) do
      {:ok, subscribers} ->
        Logger.info("🟢 IRCBridge PUBLISH ok, #{subscribers} subscribers on #{channel}")
      {:error, err} ->
        Logger.error("🔴 IRCBridge PUBLISH failed: #{inspect(err)}")
    end
    {:noreply, state}
  end

  def handle_call({:subscribe, user_id, pid}, _from, state) do
    channel = "events:#{user_id}"
    
    # Subscribe via existing shared Redis PubSub connection
    Redix.PubSub.subscribe(state.pubsub, channel, self())
    
    subscriptions = Map.put(state.subscriptions, user_id, pid)
    {:reply, :ok, %{state | subscriptions: subscriptions}}
  end

  def handle_call({:unsubscribe, user_id}, _from, state) do
    case Map.get(state.subscriptions, user_id) do
      nil ->
        {:reply, :ok, state}
      _pid ->
        channel = "events:#{user_id}"
        Redix.PubSub.unsubscribe(state.pubsub, channel, self())
        subscriptions = Map.delete(state.subscriptions, user_id)
        {:reply, :ok, %{state | subscriptions: subscriptions}}
    end
  end

  # Redix sends 5-element tuples: {:redix_pubsub, pid, ref, type, props}
  def handle_info({:redix_pubsub, _from, _ref, :subscribed, _}, state), do: {:noreply, state}
  def handle_info({:redix_pubsub, _from, _ref, :unsubscribed, _}, state), do: {:noreply, state}

  def handle_info({:redix_pubsub, _from, _ref, :message, %{channel: channel, payload: payload}}, state) do
    # Parse user_id from channel (events:42 -> 42)
    user_id = channel
      |> String.replace("events:", "")
      |> String.to_integer()

    case Map.get(state.subscriptions, user_id) do
      nil -> :ok
      pid ->
        case Jason.decode(payload) do
          {:ok, event} -> send(pid, {:irc_event, event})
          {:error, _} -> :ok
        end
    end

    {:noreply, state}
  end
end
