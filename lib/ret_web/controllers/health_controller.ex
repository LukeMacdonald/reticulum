defmodule RetWeb.HealthController do
  use RetWeb, :controller
  import Ecto.Query

  def index(conn, _params) do
    # Check database
    if module_config(:check_repo) do
      from(h in Ret.Hub, limit: 0) |> Ret.Repo.all()
    end

    # Check page cache
    true = Cachex.get(:page_chunks, {:hubs, "index.html"}) |> elem(1) |> Enum.count() > 0
    true = Cachex.get(:page_chunks, {:hubs, "hub.html"}) |> elem(1) |> Enum.count() > 0
    true = Cachex.get(:page_chunks, {:spoke, "index.html"}) |> elem(1) |> Enum.count() > 0

    # Check room routing
    true = Ret.RoomAssigner.get_available_host("") != nil

    # check storage
    if System.get_env("TURKEY_MODE") do
      path=Application.get_env(:ret, Storage)[:storage_path]
      case File.ls("#{path}/") do
        {:ok, _} -> {send_resp(conn, 200, "ok")}
        {_, ex} -> {send_resp(conn, 500, ex)}
      end
    end
  end

  defp module_config(key) do
    Application.get_env(:ret, __MODULE__)[key]
  end
end
