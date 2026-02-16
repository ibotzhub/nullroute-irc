defmodule App.Chat.Reaction do
  use Ecto.Schema
  import Ecto.Changeset

  schema "reactions" do
    field :emoji, :string
    belongs_to :message, App.Chat.Message
    belongs_to :user, App.Accounts.User
    timestamps()
  end

  def changeset(reaction, attrs) do
    reaction
    |> cast(attrs, [:message_id, :user_id, :emoji])
    |> validate_required([:message_id, :user_id, :emoji])
    |> validate_length(:emoji, max: 10)
    |> unique_constraint([:message_id, :user_id, :emoji])
  end
end
