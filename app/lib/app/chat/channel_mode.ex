defmodule App.Chat.ChannelMode do
  use Ecto.Schema
  import Ecto.Changeset

  schema "channel_modes" do
    field :channel, :string
    field :modes, :string  # JSON array
    field :password, :string
    field :user_limit, :integer
    timestamps()
  end

  def changeset(channel_mode, attrs) do
    channel_mode
    |> cast(attrs, [:channel, :modes, :password, :user_limit])
    |> validate_required([:channel])
    |> unique_constraint(:channel)
  end

  def parse_modes(modes_string) when is_binary(modes_string) do
    case Jason.decode(modes_string) do
      {:ok, modes} when is_list(modes) -> modes
      _ -> []
    end
  end

  def parse_modes(_), do: []

  def format_modes(modes) when is_list(modes) do
    Jason.encode!(modes)
  end

  def format_modes(_), do: "[]"
end
