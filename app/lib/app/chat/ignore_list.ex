defmodule App.Chat.IgnoreList do
  @moduledoc """
  Ignore list context
  """
  import Ecto.Query
  alias App.Repo
  alias App.Chat.IgnoredUser

  def add_to_ignore_list(user_id, nick, ignored_user_id \\ nil) do
    %IgnoredUser{}
    |> IgnoredUser.changeset(%{
      user_id: user_id,
      ignored_nick: nick,
      ignored_user_id: ignored_user_id
    })
    |> Repo.insert()
  end

  def remove_from_ignore_list(user_id, nick) do
    Repo.delete_all(
      from(i in IgnoredUser, where: i.user_id == ^user_id and i.ignored_nick == ^nick)
    )
  end

  def get_ignore_list(user_id) do
    Repo.all(
      from(i in IgnoredUser, where: i.user_id == ^user_id)
    )
  end

  def is_ignored?(user_id, nick) do
    Repo.exists?(
      from(i in IgnoredUser, where: i.user_id == ^user_id and i.ignored_nick == ^nick)
    )
  end
end
