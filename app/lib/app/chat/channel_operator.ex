defmodule App.Chat.ChannelOperator do
  use Ecto.Schema
  import Ecto.Changeset

  schema "channel_operators" do
    field :channel, :string
    field :operator_type, :string  # "op", "halfop", "voice"
    belongs_to :user, App.Accounts.User
    timestamps()
  end

  def changeset(channel_operator, attrs) do
    channel_operator
    |> cast(attrs, [:channel, :user_id, :operator_type])
    |> validate_required([:channel, :user_id, :operator_type])
    |> validate_inclusion(:operator_type, ["op", "halfop", "voice"])
    |> unique_constraint([:channel, :user_id])
  end
end
