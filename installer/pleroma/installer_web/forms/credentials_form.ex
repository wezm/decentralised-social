# Pleroma: A lightweight social networking server
# Copyright © 2017-2021 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.InstallerWeb.Forms.CredentialsForm do
  use Ecto.Schema

  import Ecto.Changeset

  require Logger

  alias Pleroma.Config
  alias Pleroma.Repo

  @repo Config.get([:installer, :repo], Pleroma.Installer.InstallerRepo)

  @primary_key false

  embedded_schema do
    field(:username, :string)
    field(:password, :string, default: "")
    field(:database, :string)
    field(:hostname, :string)
    field(:pool_size, :integer, default: 2)
    field(:rum_enabled, :boolean, default: false)
  end

  @spec changeset(map()) :: Ecto.Changeset.t()
  def changeset(attrs \\ %{}, opts \\ []) do
    %__MODULE__{}
    |> cast(attrs, [:username, :password, :database, :hostname, :rum_enabled])
    |> maybe_add_password(opts)
    |> validate_required([:username, :database, :hostname, :rum_enabled, :password])
  end

  defp maybe_add_password(%{changes: %{password: _}} = changeset, _), do: changeset

  defp maybe_add_password(changeset, opts) do
    if opts[:generate_password] do
      generated = :crypto.strong_rand_bytes(64) |> Base.encode64() |> binary_part(0, 64)
      change(changeset, password: generated)
    else
      changeset
    end
  end

  @spec save_credentials(Ecto.Changeset.t()) ::
          :ok
          | {:error, :psql_commands_execution, Path.t()}
          | {:error, Ecto.Changeset.t()}
          | {:error, term(), keyword()}
  def save_credentials(changeset) do
    with {:ok, struct} <- apply_action(changeset, :insert) do
      struct
      |> Map.from_struct()
      |> Keyword.new()
      |> check_database()
      |> maybe_create_database()
      |> write_config_file()
    end
  end

  @spec check_database_and_write_config() :: :ok | {:error, term(), keyword()}
  def check_database_and_write_config do
    :credentials
    |> Config.get()
    |> check_database()
    |> write_config_file()
  end

  defp check_database(credentials) when is_list(credentials) do
    case @repo.check_database(credentials) do
      :ok -> credentials
      error -> Tuple.append(error, credentials)
    end
  end

  defp maybe_create_database(credentials) when is_list(credentials), do: credentials

  defp maybe_create_database({:error, _, credentials}) do
    # we stop started repo in `check_database`
    @repo.stop()

    case @repo.create_database(credentials) do
      :ok ->
        @repo.stop()
        check_database(credentials)

      {:error, :create_repo} ->
        # something went wrong with repo creation,
        # we save psql file and let the user to run it manually
        Config.put(:credentials, credentials)
        psql_path = "/tmp/setup_db.psql"

        Logger.warn("Writing the postgres script to #{psql_path}.")

        psql =
          EEx.eval_file(
            "installer/templates/sample_psql.eex",
            credentials
          )

        with :ok <- File.write(psql_path, psql) do
          {:error, :create_repo, psql_path}
        end

      error ->
        error
    end
  end

  defp write_config_file(credentials) when is_list(credentials) do
    config_path = Pleroma.Application.config_path()

    config = EEx.eval_file("installer/templates/credentials.eex", credentials)

    case File.write(config_path, config) do
      :ok ->
        updated_config = Keyword.merge(Repo.config(), credentials)

        Config.put(Repo, updated_config)
        Config.put([:database, :rum_enabled], credentials[:rum_enabled])
        Config.put(:credentials, credentials)

        @repo.stop()

      error ->
        error
    end
  end

  defp write_config_file(error), do: error

  @spec migrations() :: :ok | {:error, :migrations_error}
  def migrations do
    path = Ecto.Migrator.migrations_path(Repo)

    paths =
      if Config.get([:database, :rum_enabled]) do
        [path, "priv/repo/optional_migrations/rum_indexing/"]
      else
        path
      end

    Config.get(:credentials)
    |> @repo.run_migrations(paths)
  end
end
