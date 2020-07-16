# Pleroma: A lightweight social networking server
# Copyright © 2017-2021 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Installer.InstallerRepo do
  require Logger

  alias Pleroma.Repo

  @dynamic_repo :installer

  @callback check_database(keyword()) :: :ok | {:error, term()}
  @callback create_database(keyword()) :: :ok | {:error, term()}
  @callback stop() :: :ok
  @callback run_migrations(keyword(), [Path.t()]) :: :ok | {:error, :migrations_error}
  @callback start_repo(keyword()) :: {:ok, pid()} | {:error, term()}

  @spec dynamic_repo() :: atom()
  def dynamic_repo, do: @dynamic_repo

  @spec check_database(keyword()) :: :ok | {:error, term()}
  def check_database(credentials) do
    credentials = Keyword.put(credentials, :name, @dynamic_repo)

    with {:ok, _} <- start_repo(credentials),
         {:ok, _} <- check_connection(),
         :ok <- check_extensions(credentials[:rum_enabled]) do
      :ok
    end
  end

  @spec create_database(keyword()) :: :ok | {:error, term()}
  def create_database(credentials) do
    credentials = Keyword.put(credentials, :name, @dynamic_repo)

    maintenance_credentials = Keyword.merge(credentials, username: "postgres", password: "")

    with :ok <- storage_up(maintenance_credentials),
         {:ok, _} <- start_repo(maintenance_credentials),
         {:ok, _} <- check_connection() do
      queries = [
        "CREATE USER #{credentials[:username]} WITH ENCRYPTED PASSWORD '#{credentials[:password]}';",
        "ALTER DATABASE #{credentials[:database]} OWNER TO #{credentials[:username]};",
        "CREATE EXTENSION IF NOT EXISTS citext;",
        "CREATE EXTENSION IF NOT EXISTS pg_trgm;",
        "CREATE EXTENSION IF NOT EXISTS \"uuid-ossp\";"
      ]

      queries =
        if credentials[:rum_enabled] do
          queries ++ ["CREATE EXTENSION IF NOT EXISTS rum;"]
        else
          queries
        end

      Enum.reduce_while(queries, :ok, fn query, acc ->
        case Repo.query(query) do
          {:ok, _} -> {:cont, acc}
          error -> {:halt, error}
        end
      end)
    end
  end

  defp storage_up(credentials) do
    with {:error, _} = error <- Ecto.Adapters.Postgres.storage_up(credentials) do
      Logger.error("Can't create repo due to error: #{inspect(error)}")
      {:error, :create_repo}
    end
  end

  @spec run_migrations(keyword(), [Path.t()]) ::
          :ok | {:error, :migrations_error} | {:error, term()}
  def run_migrations(credentials, paths) do
    case start_repo(credentials) do
      {:ok, _} ->
        if Ecto.Migrator.run(Repo, paths, :up, all: true, dynamic_repo: @dynamic_repo) != [] do
          :ok
        else
          Logger.error("Not all migrations were applied.")
          {:error, :migrations_error}
        end

      error ->
        Logger.error("Can't run migratios due to error: #{inspect(error)}")
        error
    end
  end

  @spec stop() :: :ok
  def stop do
    @dynamic_repo
    |> Process.whereis()
    |> case do
      repo when is_pid(repo) -> Supervisor.stop(repo)
      _ -> :ok
    end
  end

  @spec start_repo(keyword()) :: {:ok, pid()} | {:error, term()}
  def start_repo(credentials) when is_list(credentials) do
    credentials = Keyword.put(credentials, :name, @dynamic_repo)

    case Repo.start_link(credentials) do
      {:ok, pid} = result ->
        Repo.put_dynamic_repo(pid)
        result

      error ->
        Logger.error("Can't start repo due to error: #{inspect(error)}")
        {:error, :installer_repo_start}
    end
  end

  defp check_connection do
    with {:error, _} = error <- Repo.query("SELECT 1") do
      Logger.error("Can't connect to database due to error #{inspect(error)}")
      {:error, :query_execution}
    end
  end

  defp check_extensions(rum_enabled?) do
    default = ["citext", "pg_trgm", "uuid-ossp"]

    required = if rum_enabled?, do: ["rum" | default], else: default

    with {:ok, %{rows: extensions}} <- Repo.query("SELECT pg_available_extensions();") do
      extensions = Enum.map(extensions, fn [{name, _, _}] -> name end)

      not_installed =
        Enum.reduce(required, [], fn ext, acc ->
          if ext in extensions do
            acc
          else
            [ext | acc]
          end
        end)

      if not_installed == [] do
        :ok
      else
        Logger.error("These extensions are not installed: #{Enum.join(not_installed, ",")}")
        {:error, :extensions_not_installed}
      end
    end
  end
end
