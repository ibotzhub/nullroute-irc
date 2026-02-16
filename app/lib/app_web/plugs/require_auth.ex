defmodule AppWeb.Plugs.RequireAuth do
  import Plug.Conn
  alias App.Accounts

  def init(opts), do: opts

  def call(conn, _opts) do
    user_id = get_session(conn, :user_id)
    if user_id do
      user = Accounts.get_user(user_id)
      if user do
        assign(conn, :current_user, user)
      else
        send_unauthorized(conn, "Invalid session")
      end
    else
      send_unauthorized(conn, "Authentication required")
    end
  end

  defp send_unauthorized(conn, message) do
    conn
    |> put_resp_content_type("application/json")
    |> send_resp(401, Jason.encode!(%{error: message}))
    |> halt()
  end
end
