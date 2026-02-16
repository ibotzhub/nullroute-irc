defmodule App.Chat.IgnoredUser do
  use Ecto.Schema
  import Ecto.Changeset

  schema "ignored_users" do
    field :ignored_nick, :string
    belongs_to :user, App.Accounts.User
    belongs_to :ignored_user, App.Accounts.User
    timestamps()
  end

  def changeset(ignored_user, attrs) do
    ignored_user
    |> cast(attrs, [:user_id, :ignored_nick, :ignored_user_id])
    |> validate_required([:user_id, :ignored_nick])
    |> unique_constraint([:user_id, :ignored_nick])
  end
end
