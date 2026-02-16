defmodule App.Chat.Message do
  use Ecto.Schema
  import Ecto.Changeset

  schema "messages" do
    field :channel, :string
    field :nick, :string
    field :content, :string
    field :message_type, :string, default: "message"
    field :edited_at, :utc_datetime
    field :deleted_at, :utc_datetime
    field :pinned, :boolean, default: false
    field :pinned_at, :utc_datetime
    belongs_to :user, App.Accounts.User
    belongs_to :pinned_by, App.Accounts.User
    has_many :reactions, App.Chat.Reaction
    timestamps()
  end

  def changeset(message, attrs) do
    message
    |> cast(attrs, [:user_id, :channel, :nick, :content, :message_type, :edited_at, :deleted_at, :pinned, :pinned_by_id, :pinned_at])
    |> validate_required([:user_id, :channel, :nick, :content])
    |> validate_inclusion(:message_type, ["message", "action", "system"])
  end
end
