defmodule App.Chat.Reactions do
  @moduledoc """
  Reactions context
  """
  import Ecto.Query
  alias App.Repo
  alias App.Chat.Reaction

  def add_reaction(message_id, user_id, emoji) do
    %Reaction{}
    |> Reaction.changeset(%{message_id: message_id, user_id: user_id, emoji: emoji})
    |> Repo.insert()
  end

  def remove_reaction(message_id, user_id, emoji) do
    Repo.delete_all(
      from(r in Reaction, where: r.message_id == ^message_id and r.user_id == ^user_id and r.emoji == ^emoji)
    )
  end

  def get_reactions(message_id) do
    Reaction
    |> where([r], r.message_id == ^message_id)
    |> preload(:user)
    |> Repo.all()
  end
end
