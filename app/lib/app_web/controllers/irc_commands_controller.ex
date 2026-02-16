defmodule AppWeb.IRCCommandsController do
  use AppWeb, :controller
  alias App.Chat.IgnoreList
  alias App.Chat.ChannelOperators
  alias App.Chat.ChannelModes
  alias App.Chat.ChannelMode
  alias App.Accounts

  plug AppWeb.Plugs.RequireAuth

  def ignore_list(conn, _params) do
    user_id = get_session(conn, :user_id)
    ignored = IgnoreList.get_ignore_list(user_id)
    json(conn, %{ignored: Enum.map(ignored, &%{nick: &1.ignored_nick, id: &1.id})})
  end

  def channel_operators(conn, %{"channel" => channel}) do
    operators = ChannelOperators.get_operators(channel)
    json(conn, %{
      operators: Enum.map(operators, fn op ->
        %{
          user_id: op.user_id,
          nick: if(op.user, do: op.user.username, else: "unknown"),
          type: op.operator_type
        }
      end)
    })
  end

  def channel_modes(conn, %{"channel" => channel}) do
    modes_obj = ChannelModes.get_modes(channel)
    modes = ChannelMode.parse_modes(modes_obj.modes || "[]")
    json(conn, %{
      modes: modes,
      password: modes_obj.password,
      user_limit: modes_obj.user_limit
    })
  end

  def who(conn, %{"nick" => nick}) do
    # This would typically come from IRC server response
    # For now, return basic info
    _user_id = get_session(conn, :user_id)
    json(conn, %{nick: nick, info: "WHO command - IRC server response needed"})
  end
end
