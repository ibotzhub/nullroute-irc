defmodule App.Accounts.User do
  use Ecto.Schema
  import Ecto.Changeset

  schema "users" do
    field :username, :string
    field :display_name, :string
    field :password, :string, virtual: true
    field :password_hash, :string
    field :is_admin, :boolean, default: false
    field :is_master_admin, :boolean, default: false
    field :is_approved, :boolean, default: true
    field :theme, :string, default: "dark"
    field :avatar_url, :string
    field :bio, :string
    field :failed_login_attempts, :integer, default: 0
    field :locked_until, :utc_datetime
    field :last_login_at, :utc_datetime
    field :last_login_ip, :string
    field :unique_id, :string  # Prevents impersonation - shown in profile
    field :away, :boolean, default: false
    field :away_message, :string
    field :auto_join_channels, :string  # JSON array of channels
    many_to_many :roles, App.Accounts.Role, join_through: "user_roles"
    timestamps()
  end

  def changeset(user, attrs) do
    user
    |> cast(attrs, [:username, :display_name, :is_admin, :is_master_admin, :is_approved, :theme, :avatar_url, :bio, :away, :away_message, :auto_join_channels])
    |> validate_required([:username])
    |> validate_length(:display_name, max: 32)
    |> validate_length(:bio, max: 500)
    |> validate_inclusion(:theme, ["dark", "light"], message: "must be 'dark' or 'light'")
    |> unique_constraint(:username)
  end

  def profile_changeset(user, attrs) do
    user
    |> cast(attrs, [:display_name, :avatar_url, :bio])
    |> validate_length(:display_name, min: 1, max: 32)
    |> validate_length(:bio, max: 500)
  end

  def password_changeset(user, attrs) do
    user
    |> cast(attrs, [:password])
    |> validate_required([:password])
    |> validate_length(:password, min: 8)
    |> put_password_hash()
  end

  def registration_changeset(user, attrs) do
    user
    |> cast(attrs, [:username, :password, :is_admin, :is_master_admin, :is_approved, :display_name, :unique_id])
    |> validate_required([:username, :password])
    |> validate_length(:password, min: 8)
    |> unique_constraint(:username)
    |> put_password_hash()
  end

  defp put_password_hash(changeset) do
    case changeset do
      %Ecto.Changeset{valid?: true, changes: %{password: password}} ->
        put_change(changeset, :password_hash, Bcrypt.hash_pwd_salt(password))
      _ ->
        changeset
    end
  end
end
