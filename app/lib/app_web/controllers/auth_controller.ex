defmodule AppWeb.AuthController do
  use AppWeb, :controller
  alias App.Accounts

  def login(conn, %{"username" => username, "password" => password}) do
    # Get IP address for security logging
    ip_address = conn.remote_ip |> Tuple.to_list() |> Enum.join(".")
    
    case Accounts.authenticate_user(username, password, ip_address) do
      {:ok, user} ->
        # Ensure user has unique_id
        Accounts.ensure_unique_id(user)
        user = Accounts.get_user(user.id)  # Reload to get unique_id
        
        conn
        |> put_session(:user_id, user.id)
        |> put_session(:login_time, DateTime.utc_now() |> DateTime.to_unix())
        |> json(%{
          user: %{
            id: user.id,
            username: user.username,
            display_name: user.display_name || user.username,
            unique_id: user.unique_id,
            is_admin: user.is_admin,
            is_master_admin: user.is_master_admin || false,
            theme: user.theme || "dark",
            avatar_url: user.avatar_url
          }
        })
      {:error, :account_locked} ->
        conn
        |> put_status(:locked)
        |> json(%{error: "Account temporarily locked due to too many failed login attempts. Please try again later."})
      {:error, _reason} ->
        # Don't reveal whether username exists or not (security best practice)
        conn
        |> put_status(:unauthorized)
        |> json(%{error: "Invalid credentials"})
    end
  end

  def register(conn, %{"username" => username, "password" => password}) do
    # Validate password strength
    if String.length(password) < 8 do
      conn
      |> put_status(:unprocessable_entity)
      |> json(%{error: "Password must be at least 8 characters long"})
    else
    # Generate unique_id
    unique_id = Accounts.generate_unique_id()
    
    case Accounts.create_user(%{
      username: username,
      password: password,
      display_name: username,  # Default to username
      unique_id: unique_id,
      is_approved: true
    }) do
      {:ok, user} ->
        conn
        |> put_session(:user_id, user.id)
        |> put_session(:login_time, DateTime.utc_now() |> DateTime.to_unix())
        |> json(%{
          user: %{
            id: user.id,
            username: user.username,
            display_name: user.display_name || user.username,
            unique_id: user.unique_id
          }
        })
      {:error, changeset} ->
        errors = Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
          Enum.reduce(opts, msg, fn {key, value}, acc ->
            String.replace(acc, "%{#{key}}", to_string(value))
          end)
        end)
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{error: "Registration failed", details: errors})
    end
    end
  end

  def logout(conn, _params) do
    conn
    |> clear_session()
    |> json(%{ok: true})
  end

  def socket_token(conn, _params) do
    user_id = get_session(conn, :user_id)
    if user_id do
      token = Phoenix.Token.sign(AppWeb.Endpoint, "user socket", user_id)
      conn
      |> put_resp_header("cache-control", "no-store, no-cache, must-revalidate")
      |> json(%{token: token})
    else
      conn
      |> put_status(:unauthorized)
      |> json(%{error: "Not authenticated"})
    end
  end

  def me(conn, _params) do
    user_id = get_session(conn, :user_id)
    if user_id do
      user = Accounts.get_user(user_id)
      if user do
        json(conn, %{
          user: %{
            id: user.id,
            username: user.username,
            display_name: user.display_name || user.username,
            unique_id: user.unique_id,
            is_admin: user.is_admin,
            is_master_admin: user.is_master_admin || false,
            theme: user.theme || "dark",
            avatar_url: user.avatar_url
          }
        })
      else
        conn
        |> put_status(:unauthorized)
        |> json(%{error: "Invalid session"})
      end
    else
      conn
      |> put_status(:unauthorized)
      |> json(%{error: "Not authenticated"})
    end
  end
end
