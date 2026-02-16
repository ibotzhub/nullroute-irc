defmodule App.Chat.UserNickMapping do
  use Ecto.Schema
  import Ecto.Changeset

  schema "user_nick_mappings" do
    field :irc_nick, :string
    field :active, :boolean, default: true
    belongs_to :user, App.Accounts.User
    timestamps()
  end

  def changeset(mapping, attrs) do
    mapping
    |> cast(attrs, [:user_id, :irc_nick, :active])
    |> validate_required([:user_id, :irc_nick])
    |> unique_constraint(:irc_nick, where: [active: true])
  end
end
