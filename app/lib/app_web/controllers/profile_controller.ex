defmodule AppWeb.ProfileController do
  use AppWeb, :controller
  alias App.Accounts

  # Require authentication
  plug :require_auth

  def show(conn, %{"id" => id}) do
    user = Accounts.get_user(id)
    current_user = Accounts.get_user(get_session(conn, :user_id))
    
    if user do
      # Public profile - show username, display_name, unique_id, bio, avatar
      # But hide sensitive info unless viewing own profile
      is_own_profile = current_user && current_user.id == user.id
      
      profile_data = %{
        id: user.id,
        username: user.username,
        display_name: user.display_name || user.username,
        unique_id: user.unique_id,
        avatar_url: user.avatar_url,
        bio: user.bio,
        joined_at: user.inserted_at,
        # Only show roles if admin or viewing own profile
        roles: if(is_own_profile || (current_user && (current_user.is_admin || current_user.is_master_admin))) do
          user = App.Repo.preload(user, :roles)
          Enum.map(user.roles || [], fn r ->
            %{id: r.id, name: r.name, color: r.color}
          end)
        else
          []
        end
      }
      
      json(conn, %{profile: profile_data})
    else
      conn
      |> put_status(:not_found)
      |> json(%{error: "User not found"})
    end
  end

  def update(conn, params) do
    user_id = get_session(conn, :user_id)
    user = user_id && Accounts.get_user(user_id)
    if user do
      # Only allow updating own profile; prevent display_name conflicts
      updated_params = if params["display_name"] do
        existing = Accounts.get_user_by_display_name(params["display_name"])
        if existing && existing.id != user.id do
          nil  # Signal error
        else
          # Sanitize display name - remove special characters that could be used for impersonation
          sanitized = params["display_name"]
            |> String.trim()
            |> String.replace(~r/[^\w\s-]/, "")  # Only allow alphanumeric, spaces, hyphens
            |> String.replace(~r/\s+/, " ")  # Normalize whitespace
          Map.put(params, "display_name", sanitized)
        end
      else
        params
      end

      if is_nil(updated_params) do
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{error: "Display name already taken"})
      else
        case Accounts.update_user_profile(user, updated_params) do
          {:ok, updated_user} ->
            json(conn, %{
              profile: %{
                id: updated_user.id,
                username: updated_user.username,
                display_name: updated_user.display_name || updated_user.username,
                unique_id: updated_user.unique_id,
                avatar_url: updated_user.avatar_url,
                bio: updated_user.bio
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
            |> json(%{error: "Failed to update profile", details: errors})
        end
      end
    else
      conn
      |> put_status(:unauthorized)
      |> json(%{error: "Invalid session"})
    end
  end

  defp require_auth(conn, _opts) do
    user_id = get_session(conn, :user_id)
    if user_id do
      conn
    else
      conn
      |> put_status(:unauthorized)
      |> json(%{error: "Not authenticated"})
      |> halt()
    end
  end
end
