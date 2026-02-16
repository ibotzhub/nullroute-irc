defmodule App.Accounts do
  @moduledoc """
  Accounts context - user management, authentication
  """
  import Ecto.Query
  alias App.Repo
  alias App.Accounts.User

  def get_user(id), do: Repo.get(User, id)
  def get_user_by_username(username), do: Repo.get_by(User, username: username)
  def list_users do
    User
    |> Repo.all()
    |> Repo.preload([])
  end

  def create_user(attrs \\ %{}) do
    %User{}
    |> User.registration_changeset(attrs)
    |> Repo.insert()
  end

  def authenticate_user(username, password, ip_address \\ nil) do
    user = get_user_by_username(username)
    
    # Check if account is locked
    cond do
      user && user.locked_until && DateTime.compare(DateTime.utc_now(), user.locked_until) != :gt ->
        {:error, :account_locked}
      
      user && user.locked_until && DateTime.compare(DateTime.utc_now(), user.locked_until) == :gt ->
        # Lock expired, reset
        update_user(user, %{locked_until: nil, failed_login_attempts: 0})
        authenticate_user(username, password, ip_address)  # Retry authentication
      
      user && Bcrypt.verify_pass(password, user.password_hash) ->
        # Successful login - reset failed attempts and update login info
        update_user(user, %{
          failed_login_attempts: 0,
          locked_until: nil,
          last_login_at: DateTime.utc_now(),
          last_login_ip: ip_address
        })
        {:ok, user}
      
      true ->
        # Failed login - increment attempts
        if user do
          attempts = (user.failed_login_attempts || 0) + 1
          locked_until = if attempts >= 5 do
            DateTime.add(DateTime.utc_now(), 15 * 60, :second)  # Lock for 15 minutes
          else
            user.locked_until
          end
          update_user(user, %{
            failed_login_attempts: attempts,
            locked_until: locked_until
          })
        end
        {:error, :invalid_credentials}
    end
  end

  def generate_unique_id do
    # Generate a 4-digit unique ID (like Discord discriminator)
    :rand.uniform(9999)
    |> Integer.to_string()
    |> String.pad_leading(4, "0")
  end

  def ensure_unique_id(user) do
    if is_nil(user.unique_id) do
      unique_id = generate_unique_id()
      # Ensure it's actually unique
      case get_user_by_unique_id(unique_id) do
        nil -> update_user(user, %{unique_id: unique_id})
        _ -> ensure_unique_id(user)  # Retry if collision
      end
    else
      {:ok, user}
    end
  end

  def get_user_by_unique_id(unique_id), do: Repo.get_by(User, unique_id: unique_id)

  def change_password(user, current_password, new_password) do
    if Bcrypt.verify_pass(current_password, user.password_hash) do
      user
      |> User.password_changeset(%{password: new_password})
      |> Repo.update()
    else
      {:error, :invalid_password}
    end
  end

  def update_user(user, attrs) do
    user
    |> User.changeset(attrs)
    |> Repo.update()
  end

  def update_user_profile(user, attrs) do
    user
    |> User.profile_changeset(attrs)
    |> Repo.update()
  end

  def get_user_by_display_name(display_name), do: Repo.get_by(User, display_name: display_name)
end
