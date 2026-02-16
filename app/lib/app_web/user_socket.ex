defmodule AppWeb.UserSocket do
  use Phoenix.Socket

  channel "user:*", AppWeb.UserChannel

  @impl true
  def connect(params, socket, connect_info) do
    require Logger
    case get_user_id(params, connect_info) do
      {:ok, user_id} ->
        case App.Accounts.get_user(user_id) do
          nil ->
            Logger.warning("UserSocket: user_id=#{user_id} not found in DB")
            :error
          user ->
            {:ok, assign(socket, :current_user, user)}
        end
      {:error, reason} ->
        session_keys = case connect_info do
          %{user_session: s} when is_map(s) -> Map.keys(s)
          _ -> []
        end
        Logger.warning("UserSocket refused: reason=#{inspect(reason)}, has_token=#{params["token"] != nil}, session_keys=#{inspect(session_keys)}")
        :error
    end
  end

  @impl true
  def id(socket), do: "user_socket:#{socket.assigns.current_user.id}"

  defp get_user_id(params, connect_info) do
    cond do
      token = params["token"] ->
        case Phoenix.Token.verify(AppWeb.Endpoint, "user socket", token, max_age: 86400) do
          {:ok, user_id} -> {:ok, user_id}
          {:error, err} ->
            require Logger
            Logger.warning("UserSocket token verify failed: #{inspect(err)}")
            get_session_user_id(connect_info)
        end
      true ->
        get_session_user_id(connect_info)
    end
  end

  defp get_session_user_id(connect_info) do
    case connect_info do
      %{user_session: session} when is_map(session) ->
        case Map.get(session, :user_id) do
          nil -> {:error, :no_session}
          user_id -> {:ok, user_id}
        end
      _ ->
        {:error, :no_session}
    end
  end
end
