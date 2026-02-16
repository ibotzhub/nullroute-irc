defmodule App.Accounts.Role do
  use Ecto.Schema
  import Ecto.Changeset

  schema "roles" do
    field :name, :string
    field :color, :string, default: "#7289da"
    field :permissions, :map, default: %{}
    field :priority, :integer, default: 0
    many_to_many :users, App.Accounts.User, join_through: "user_roles"

    timestamps()
  end

  def changeset(role, attrs) do
    role
    |> cast(attrs, [:name, :color, :permissions, :priority])
    |> validate_required([:name])
    |> validate_length(:name, min: 1, max: 32)
    |> validate_inclusion(:priority, 0..100)
    |> unique_constraint(:name)
  end

  # Default permissions structure
  def default_permissions do
    %{
      "channels" => %{
        "create" => false,
        "delete" => false,
        "modify" => false,
        "view" => true
      },
      "users" => %{
        "kick" => false,
        "ban" => false,
        "mute" => false,
        "view" => true
      },
      "messages" => %{
        "delete" => false,
        "pin" => false,
        "moderate" => false
      },
      "server" => %{
        "modify_settings" => false,
        "view_logs" => false
      },
      "roles" => %{
        "create" => false,
        "assign" => false,
        "modify" => false,
        "delete" => false
      }
    }
  end
end
