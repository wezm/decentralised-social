# Pleroma: A lightweight social networking server
# Copyright © 2017-2021 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Migrators.MediaTableMigrator do
  use GenServer

  require Logger

  import Ecto.Query

  alias __MODULE__.State
  alias Pleroma.Config
  alias Pleroma.DataMigration
  alias Pleroma.Media
  alias Pleroma.Object
  alias Pleroma.Repo

  defdelegate state(), to: State, as: :get
  defdelegate put_stat(key, value), to: State, as: :put
  defdelegate increment_stat(key, increment), to: State, as: :increment

  defdelegate data_migration(), to: DataMigration, as: :populate_media_table

  @reg_name {:global, __MODULE__}

  def whereis, do: GenServer.whereis(@reg_name)

  def start_link(_) do
    case whereis() do
      nil ->
        GenServer.start_link(__MODULE__, nil, name: @reg_name)

      pid ->
        {:ok, pid}
    end
  end

  @impl true
  def init(_) do
    {:ok, nil, {:continue, :init_state}}
  end

  @impl true
  def handle_continue(:init_state, _state) do
    {:ok, _} = State.start_link(nil)

    update_status(:init)

    data_migration = data_migration()
    manual_migrations = Config.get([:instance, :manual_data_migrations], [])

    cond do
      Config.get(:env) == :test ->
        update_status(:noop)

      is_nil(data_migration) ->
        update_status(:halt, "Data migration does not exist.")

      data_migration.state == :manual or data_migration.name in manual_migrations ->
        update_status(:noop, "Data migration is in manual execution state.")

      data_migration.state == :complete ->
        handle_success(data_migration)

      true ->
        send(self(), :process_attachments)
    end

    {:noreply, nil}
  end

  @impl true
  def handle_info(:process_attachments, state) do
    State.clear()

    data_migration = data_migration()

    persistent_data = Map.take(data_migration.data, ["max_processed_id"])

    {:ok, data_migration} =
      DataMigration.update(data_migration, %{state: :running, data: persistent_data})

    update_status(:running)
    put_stat(:started_at, NaiveDateTime.utc_now())

    Logger.info("Starting creating `media` records for objects' attachments...")

    max_processed_id = data_migration.data["max_processed_id"] || 0

    query()
    |> where([object], object.id > ^max_processed_id)
    |> Repo.chunk_stream(100, :batches, timeout: :infinity)
    |> Stream.each(fn objects ->
      object_ids = Enum.map(objects, & &1.id)

      failed_ids =
        objects
        |> Enum.map(&process_object_attachments(&1))
        |> Enum.filter(&(elem(&1, 0) == :error))
        |> Enum.map(&elem(&1, 1))

      for failed_id <- failed_ids do
        _ =
          Repo.query(
            "INSERT INTO data_migration_failed_ids(data_migration_id, record_id) " <>
              "VALUES ($1, $2) ON CONFLICT DO NOTHING;",
            [data_migration.id, failed_id]
          )
      end

      _ =
        Repo.query(
          "DELETE FROM data_migration_failed_ids " <>
            "WHERE data_migration_id = $1 AND record_id = ANY($2)",
          [data_migration.id, object_ids -- failed_ids]
        )

      max_object_id = Enum.at(object_ids, -1)

      put_stat(:max_processed_id, max_object_id)
      increment_stat(:processed_count, length(object_ids))
      increment_stat(:failed_count, length(failed_ids))

      put_stat(
        :records_per_second,
        state()[:processed_count] /
          Enum.max([NaiveDateTime.diff(NaiveDateTime.utc_now(), state()[:started_at]), 1])
      )

      persist_stats(data_migration)

      # A quick and dirty approach to controlling the load this background migration imposes
      sleep_interval = Config.get([:populate_media_table, :sleep_interval_ms], 0)
      Process.sleep(sleep_interval)
    end)
    |> Stream.run()

    with 0 <- failures_count(data_migration.id) do
      {:ok, data_migration} = DataMigration.update_state(data_migration, :complete)

      handle_success(data_migration)
    else
      _ ->
        _ = DataMigration.update_state(data_migration, :failed)

        update_status(:failed, "Please check data_migration_failed_ids records.")
    end

    {:noreply, state}
  end

  def query do
    from(
      object in Object,
      where:
        fragment(
          "(?)->'attachment' IS NOT NULL AND \
(?)->'attachment' != ANY(ARRAY['null'::jsonb, '[]'::jsonb])",
          object.data,
          object.data
        ),
      select: %{
        id: object.id,
        attachment: fragment("(?)->'attachment'", object.data),
        actor: fragment("(?)->'actor'", object.data)
      }
    )
  end

  defp process_object_attachments(object) do
    attachments =
      if Map.has_key?(object, :attachment), do: object.attachment, else: object.data["attachment"]

    actor = if Map.has_key?(object, :actor), do: object.actor, else: object.data["actor"]

    Repo.transaction(fn ->
      with {_, true} <- {:any, Enum.any?(attachments || [], &is_nil(&1["id"]))},
           updated_attachments =
             Enum.map(attachments, fn attachment ->
               if is_nil(attachment["id"]) do
                 with {:ok, media} <-
                        Media.create_from_object_data(attachment, %{
                          actor: actor,
                          object_id: object.id
                        }) do
                   Map.put(attachment, "id", media.id)
                 else
                   {:error, e} ->
                     error =
                       "ERROR: could not process attachment of object #{object.id}: " <>
                         "#{attachment["href"]}: #{inspect(e)}"

                     Logger.error(error)
                     Repo.rollback(object.id)
                 end
               else
                 attachment
               end
             end),
           {:ok, _} <-
             Object.update_data(%Object{id: object.id}, %{"attachment" => updated_attachments}) do
        object.id
      else
        {:any, false} ->
          object.id

        {:error, e} ->
          error = "ERROR: could not update attachments of object #{object.id}: #{inspect(e)}"

          Logger.error(error)
          Repo.rollback(object.id)
      end
    end)
  end

  @doc "Approximate count for current iteration (including processed records count)"
  def count(force \\ false, timeout \\ :infinity) do
    stored_count = state()[:count]

    if stored_count && !force do
      stored_count
    else
      processed_count = state()[:processed_count] || 0
      max_processed_id = data_migration().data["max_processed_id"] || 0
      query = where(query(), [object], object.id > ^max_processed_id)

      count = Repo.aggregate(query, :count, :id, timeout: timeout) + processed_count
      put_stat(:count, count)
      count
    end
  end

  defp persist_stats(data_migration) do
    runner_state = Map.drop(state(), [:status])
    _ = DataMigration.update(data_migration, %{data: runner_state})
  end

  defp handle_success(_data_migration) do
    update_status(:complete)
  end

  def failed_objects_query do
    from(o in Object)
    |> join(:inner, [o], dmf in fragment("SELECT * FROM data_migration_failed_ids"),
      on: dmf.record_id == o.id
    )
    |> where([_o, dmf], dmf.data_migration_id == ^data_migration().id)
    |> order_by([o], asc: o.id)
  end

  def failures_count(data_migration_id \\ nil) do
    data_migration_id = data_migration_id || data_migration().id

    with {:ok, %{rows: [[count]]}} <-
           Repo.query(
             "SELECT COUNT(record_id) FROM data_migration_failed_ids WHERE data_migration_id = $1;",
             [data_migration_id]
           ) do
      count
    end
  end

  def retry_failed do
    data_migration = data_migration()

    failed_objects_query()
    |> Repo.chunk_stream(100, :one)
    |> Stream.each(fn object ->
      with {:ok, _} <- process_object_attachments(object) do
        _ =
          Repo.query(
            "DELETE FROM data_migration_failed_ids " <>
              "WHERE data_migration_id = $1 AND record_id = $2",
            [data_migration.id, object.id]
          )
      end
    end)
    |> Stream.run()
  end

  def force_continue do
    send(whereis(), :process_attachments)
  end

  def force_restart do
    {:ok, _} = DataMigration.update(data_migration(), %{state: :pending, data: %{}})
    force_continue()
  end

  def force_complete do
    {:ok, data_migration} = DataMigration.update_state(data_migration(), :complete)

    handle_success(data_migration)
  end

  defp update_status(status, message \\ nil) do
    put_stat(:status, status)
    put_stat(:message, message)
  end
end
