defmodule App.Chat.ChannelOperators do
  @moduledoc """
  Channel operators context
  """
  import Ecto.Query
  alias App.Repo
  alias App.Chat.ChannelOperator

  def set_operator(channel, user_id, operator_type) do
    case Repo.get_by(ChannelOperator, channel: channel, user_id: user_id) do
      nil ->
        %ChannelOperator{}
        |> ChannelOperator.changeset(%{
          channel: channel,
          user_id: user_id,
          operator_type: operator_type
        })
        |> Repo.insert()
      existing ->
        existing
        |> ChannelOperator.changeset(%{operator_type: operator_type})
        |> Repo.update()
    end
  end

  def remove_operator(channel, user_id) do
    Repo.delete_all(
      from(o in ChannelOperator, where: o.channel == ^channel and o.user_id == ^user_id)
    )
  end

  def get_operators(channel) do
    ChannelOperator
    |> where([o], o.channel == ^channel)
    |> preload(:user)
    |> Repo.all()
  end

  def get_operator_type(channel, user_id) do
    case Repo.get_by(ChannelOperator, channel: channel, user_id: user_id) do
      nil -> nil
      op -> op.operator_type
    end
  end

  def is_op?(channel, user_id), do: get_operator_type(channel, user_id) == "op"
  def is_halfop?(channel, user_id), do: get_operator_type(channel, user_id) == "halfop"
  def is_voice?(channel, user_id), do: get_operator_type(channel, user_id) == "voice"
  def has_privilege?(channel, user_id), do: get_operator_type(channel, user_id) != nil
end
