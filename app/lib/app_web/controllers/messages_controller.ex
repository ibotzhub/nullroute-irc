defmodule AppWeb.MessagesController do
  use AppWeb, :controller
  alias App.Chat.Messages
  alias App.Chat.Reactions
  alias App.Accounts

  plug AppWeb.Plugs.RequireAuth

  def index(conn, params) do
    channel = params["channel"]
    limit = case params["limit"] do
      nil -> 50
      l -> String.to_integer(l)
    end
    before_id = case params["before_id"] do
      nil -> nil
      b -> String.to_integer(b)
    end

    if channel do
      messages = Messages.get_messages(channel, limit, before_id)
      json(conn, %{messages: Enum.map(messages, &format_message/1)})
    else
      conn
      |> put_status(:bad_request)
      |> json(%{error: "channel is required"})
    end
  end

  def show(conn, %{"id" => id}) do
    case Messages.get_message(id) do
      nil ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "Message not found"})
      message ->
        json(conn, %{message: format_message(message)})
    end
  end

  def update(conn, %{"id" => id, "content" => content}) do
    user_id = get_session(conn, :user_id)
    message = Messages.get_message(id)

    cond do
      is_nil(message) ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "Message not found"})
      message.user_id != user_id ->
        conn
        |> put_status(:forbidden)
        |> json(%{error: "You can only edit your own messages"})
      true ->
        case Messages.update_message(message, %{content: content, edited_at: DateTime.utc_now()}) do
          {:ok, updated_message} ->
            json(conn, %{message: format_message(updated_message)})
          {:error, _changeset} ->
            conn
            |> put_status(:unprocessable_entity)
            |> json(%{error: "Failed to update message"})
        end
    end
  end

  def delete(conn, %{"id" => id}) do
    user_id = get_session(conn, :user_id)
    message = Messages.get_message(id)
    current_user = user_id && Accounts.get_user(user_id)
    current_user = current_user && App.Repo.preload(current_user, :roles)

    cond do
      is_nil(message) ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "Message not found"})
      message.user_id != user_id && !(current_user && App.Accounts.Permissions.has_permission?(current_user, "messages", "delete")) ->
        conn
        |> put_status(:forbidden)
        |> json(%{error: "Permission denied"})
      true ->
        case Messages.delete_message(message) do
          {:ok, _deleted_message} ->
            json(conn, %{ok: true})
          {:error, _changeset} ->
            conn
            |> put_status(:unprocessable_entity)
            |> json(%{error: "Failed to delete message"})
        end
    end
  end

  def pin(conn, %{"id" => id}) do
    user_id = get_session(conn, :user_id)
    message = Messages.get_message(id)
    current_user = user_id && Accounts.get_user(user_id)
    current_user = current_user && App.Repo.preload(current_user, :roles)

    cond do
      is_nil(message) ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "Message not found"})
      !current_user || !App.Accounts.Permissions.has_permission?(current_user, "messages", "pin") ->
        conn
        |> put_status(:forbidden)
        |> json(%{error: "Permission denied"})
      true ->
        case Messages.pin_message(message, user_id) do
          {:ok, pinned_message} ->
            json(conn, %{message: format_message(pinned_message)})
          {:error, _changeset} ->
            conn
            |> put_status(:unprocessable_entity)
            |> json(%{error: "Failed to pin message"})
        end
    end
  end

  def unpin(conn, %{"id" => id}) do
    user_id = get_session(conn, :user_id)
    message = Messages.get_message(id)
    current_user = user_id && Accounts.get_user(user_id)
    current_user = current_user && App.Repo.preload(current_user, :roles)

    cond do
      is_nil(message) ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "Message not found"})
      !current_user || !App.Accounts.Permissions.has_permission?(current_user, "messages", "pin") ->
        conn
        |> put_status(:forbidden)
        |> json(%{error: "Permission denied"})
      true ->
        case Messages.unpin_message(message) do
          {:ok, unpinned_message} ->
            json(conn, %{message: format_message(unpinned_message)})
          {:error, _changeset} ->
            conn
            |> put_status(:unprocessable_entity)
            |> json(%{error: "Failed to unpin message"})
        end
    end
  end

  def pinned(conn, %{"channel" => channel}) do
    messages = Messages.get_pinned_messages(channel)
    json(conn, %{messages: Enum.map(messages, &format_message/1)})
  end

  def search(conn, %{"channel" => channel, "query" => query}) do
    messages = Messages.search_messages(channel, query)
    json(conn, %{messages: Enum.map(messages, &format_message/1)})
  end

  def add_reaction(conn, %{"message_id" => message_id, "emoji" => emoji}) do
    user_id = get_session(conn, :user_id)
    case Reactions.add_reaction(message_id, user_id, emoji) do
      {:ok, reaction} ->
        json(conn, %{reaction: format_reaction(reaction)})
      {:error, _changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{error: "Failed to add reaction"})
    end
  end

  def remove_reaction(conn, %{"message_id" => message_id, "emoji" => emoji}) do
    user_id = get_session(conn, :user_id)
    Reactions.remove_reaction(message_id, user_id, emoji)
    json(conn, %{ok: true})
  end

  defp format_message(message) do
    %{
      id: message.id,
      user_id: message.user_id,
      channel: message.channel,
      nick: message.nick,
      content: message.content,
      message_type: message.message_type,
      edited_at: message.edited_at,
      pinned: message.pinned,
      pinned_at: message.pinned_at,
      inserted_at: message.inserted_at,
      reactions: Enum.map(message.reactions || [], &format_reaction/1),
      user: (if message.user, do: %{
        id: message.user.id,
        username: message.user.username,
        display_name: message.user.display_name || message.user.username,
        unique_id: message.user.unique_id,
        avatar_url: message.user.avatar_url
      }, else: nil)
    }
  end

  defp format_reaction(reaction) do
    %{
      id: reaction.id,
      emoji: reaction.emoji,
      user_id: reaction.user_id,
      user: (if reaction.user, do: %{
        id: reaction.user.id,
        username: reaction.user.username,
        display_name: reaction.user.display_name || reaction.user.username,
        unique_id: reaction.user.unique_id
      }, else: nil)
    }
  end
end
