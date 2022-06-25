defmodule Ret.StorageStat do
  @moduledoc """
  Defines table for StorageStat generated by Ret.StorageUsed on the interval
  Storage is captured only in TURKEY_MODE and saved in # units of 512 bytes that `du` uses by default
  """
  use Ecto.Schema
  import Ecto.Changeset
  import Ecto.Query
  alias Ret.{StorageStat, Repo}
  require NaiveDateTime

  schema "storage_stats" do
    field(:measured_at, :utc_datetime)
    field(:node_id, :binary)
    field(:present_storage_blocks, :integer)

    timestamps()
  end

  @doc false
  # TODO Could do an aggregate per day that each value factors into? Average might get tricky because you need the count of values you've put in
  def changeset(storage_stat, attrs) do
    storage_stat
    |> cast(attrs, [:node_id, :measured_at, :present_storage_blocks])
    |> validate_required([:node_id, :measured_at, :present_storage_blocks])
  end

  # Adds current storage_stat
  # storage_blocks is in # units of 512 bytes
  def save_storage_stat(storage_blocks) do
    if System.get_env("TURKEY_MODE") do
      with node_id <- Node.self() |> to_string,
           measured_at <- NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second),
           present_storage_blocks <- storage_blocks do
        %StorageStat{}
        |> changeset(%{
          node_id: node_id,
          measured_at: measured_at,
          present_storage_blocks: present_storage_blocks
        })
        |> Repo.insert()
      end
    end
  end

  def get_list_of_today_values(utc_date) do
    today_date = NaiveDateTime.to_date(utc_date)

    # TODO Will this have conflicts with different node_ids? or count twice if share same db?
    from(ss in StorageStat, where: NaiveDateTime.compare(NaiveDateTime.to_date(ss.measured_at), today_date) == :eq)
    |> Repo.all()
  end

  # TODO better verification of list of %StorageStat
  defp storage_stat_list_to_unit_list(list_storage_stats) do
    list_storage_stats
    |> Enum.map(fn ss -> ss.present_storage_blocks end)
  end

  defp get_average(unit_list) do
    count = Kernel.length(unit_list)

    sum =
      unit_list
      |> Enum.map(fn ss -> ss.present_storage_blocks end)
      |> Enum.sum()

    sum / count
  end

  defp get_max(unit_list) do
    unit_list
    |> Enum.map_reduce(unit_list, 0, fn u, acc ->
      if acc > u do
        acc
      else
        u
      end
    end)
  end

  defp get_min(unit_list) do
    first_unit = Enum.at(unit_list, 0)

    unit_list
    |> Enum.map_reduce(unit_list, first_unit, fn u, acc ->
      if acc > u do
        acc
      else
        u
      end
    end)
  end
end
