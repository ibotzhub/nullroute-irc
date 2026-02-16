defmodule AppWeb.RateLimit do
  @moduledoc """
  Rate limiting plug to prevent brute force attacks
  Uses Redis if available, fails open if Redis is unavailable
  """
  import Plug.Conn
  require Logger

  def init(opts), do: opts

  def call(conn, _opts) do
    # Only rate limit login/register endpoints
    if String.contains?(conn.request_path, "/api/auth/login") or
       String.contains?(conn.request_path, "/api/auth/register") do
      ip = conn.remote_ip |> Tuple.to_list() |> Enum.join(".")
      key = "rate_limit:#{ip}"
      
      # Rate limiting via Redis (fail open if unavailable)
      count = try do
        {:ok, redis} = Redix.start_link(host: "localhost", port: 6379)
        {:ok, cnt} = Redix.command(redis, ["INCR", key])
        if cnt == 1 do
          Redix.command(redis, ["EXPIRE", key, "900"])
        end
        GenServer.stop(redis)
        cnt
      rescue
        _ -> 0  # Fail open - allow request if Redis unavailable
      end
      
      if count > 10 do
        Logger.warn("Rate limit exceeded for IP: #{ip}")
        body = Jason.encode!(%{error: "Too many requests. Please try again later."})
        conn
        |> put_resp_content_type("application/json")
        |> send_resp(429, body)
        |> halt()
      else
        conn
      end
    else
      conn
    end
  end
end
