defmodule App.Chat.Messages do
  @moduledoc """
  Messages context - message storage and retrieval
  """
  import Ecto.Query
  alias App.Repo
  alias App.Chat.Message
  alias App.Chat.UserNickMapping

  def create_message(attrs \\ %{}) do
    %Message{}
    |> Message.changeset(attrs)
    |> Repo.insert()
  end

  def get_messages(channel, limit \\ 50, before_id \\ nil) do
    query = Message
    |> where([m], m.channel == ^channel and is_nil(m.deleted_at))
    |> order_by([m], desc: m.inserted_at)
    |> limit(^limit)
    |> preload([:user, :reactions, reactions: :user])

    query = if before_id do
      where(query, [m], m.id < ^before_id)
    else
      query
    end

    query
    |> Repo.all()
    |> Enum.reverse()  # Return in chronological order
  end

  def get_message(id) do
    case Repo.get(Message, id) do
      nil -> nil
      message -> Repo.preload(message, [:user, :reactions, reactions: :user])
    end
  end

  def update_message(message, attrs) do
    message
    |> Message.changeset(attrs)
    |> Repo.update()
  end

  def delete_message(message) do
    message
    |> Message.changeset(%{deleted_at: DateTime.utc_now()})
    |> Repo.update()
  end

  def pin_message(message, pinned_by_id) do
    message
    |> Message.changeset(%{
      pinned: true,
      pinned_by_id: pinned_by_id,
      pinned_at: DateTime.utc_now()
    })
    |> Repo.update()
  end

  def unpin_message(message) do
    message
    |> Message.changeset(%{
      pinned: false,
      pinned_by_id: nil,
      pinned_at: nil
    })
    |> Repo.update()
  end

  def get_pinned_messages(channel) do
    Message
    |> where([m], m.channel == ^channel and m.pinned == true and is_nil(m.deleted_at))
    |> order_by([m], desc: m.pinned_at)
    |> preload([:user, :reactions, reactions: :user])
    |> Repo.all()
  end

  def search_messages(channel, query, limit \\ 50) do
    search_term = "%#{query}%"
    Message
    |> where([m], m.channel == ^channel and is_nil(m.deleted_at))
    |> where([m], ilike(m.content, ^search_term) or ilike(m.nick, ^search_term))
    |> order_by([m], desc: m.inserted_at)
    |> limit(^limit)
    |> preload([:user, :reactions, reactions: :user])
    |> Repo.all()
  end

  def get_user_id_from_nick(nick) do
    mapping = Repo.get_by(UserNickMapping, irc_nick: nick, active: true)
    if mapping, do: mapping.user_id, else: nil
  end

  def set_user_nick(user_id, nick) do
    # Deactivate old mappings for this user
    Repo.update_all(
      from(m in UserNickMapping, where: m.user_id == ^user_id and m.active == true),
      set: [active: false]
    )

    # Create or reactivate mapping
    case Repo.get_by(UserNickMapping, irc_nick: nick) do
      nil ->
        %UserNickMapping{}
        |> UserNickMapping.changeset(%{user_id: user_id, irc_nick: nick, active: true})
        |> Repo.insert()
      existing ->
        existing
        |> UserNickMapping.changeset(%{user_id: user_id, active: true})
        |> Repo.update()
    end
  end
end
