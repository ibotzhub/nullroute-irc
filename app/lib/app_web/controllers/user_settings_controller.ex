defmodule AppWeb.UserSettingsController do
  use AppWeb, :controller
  alias App.Accounts

  # Require authentication
  plug :require_auth

  def get_settings(conn, _params) do
    user_id = get_session(conn, :user_id)
    user = Accounts.get_user(user_id)
    if user do
      json(conn, %{
        theme: user.theme || "dark",
        auto_join_channels: user.auto_join_channels || "[]"
      })
    else
      conn
      |> put_status(:unauthorized)
      |> json(%{error: "Invalid session"})
    end
  end

  def update_settings(conn, params) do
    user_id = get_session(conn, :user_id)
    user = user_id && Accounts.get_user(user_id)
    if user do
      # Allow theme and auto_join_channels to be updated by regular users
      allowed_params = Map.take(params, ["theme", "auto_join_channels"])
      case Accounts.update_user(user, allowed_params) do
        {:ok, updated_user} ->
          json(conn, %{
            ok: true,
            theme: updated_user.theme || "dark",
            auto_join_channels: updated_user.auto_join_channels || "[]"
          })
        {:error, changeset} ->
          errors = Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
            Enum.reduce(opts, msg, fn {key, value}, acc ->
              String.replace(acc, "%{#{key}}", to_string(value))
            end)
          end)
          conn
          |> put_status(:unprocessable_entity)
          |> json(%{error: "Failed to update settings", details: errors})
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
