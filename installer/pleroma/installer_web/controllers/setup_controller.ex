# Pleroma: A lightweight social networking server
# Copyright © 2017-2021 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.InstallerWeb.SetupController do
  use Pleroma.InstallerWeb, :controller

  alias Pleroma.Config
  alias Pleroma.InstallerWeb.Forms.ConfigForm
  alias Pleroma.InstallerWeb.Forms.CredentialsForm

  plug(:authenticate)

  def index(conn, _) do
    env = Config.get(:env)

    render(conn, "index.html",
      credentials:
        CredentialsForm.changeset(%{
          username: "pleroma",
          password: "",
          database: "pleroma_#{env}",
          hostname: "localhost"
        }),
      error: nil
    )
  end

  def save_credentials(conn, params) do
    changeset = CredentialsForm.changeset(params["credentials_form"], generate_password: true)

    case CredentialsForm.save_credentials(changeset) do
      :ok ->
        redirect(conn, to: Routes.setup_path(conn, :migrations))

      {:error, %Ecto.Changeset{} = changeset} ->
        render(conn, "index.html",
          credentials: changeset,
          error: nil
        )

      {:error, %DBConnection.ConnectionError{}, _} ->
        render(conn, "index.html",
          credentials: changeset,
          error:
            "Pleroma can't connect to the database with these credentials. Please check them and try one more time."
        )

      {:error, :create_repo, psql_path} ->
        render(conn, "run_psql.html", psql_path: psql_path, error: nil)

      {:error, error, _} ->
        render(conn, "index.html",
          credentials: changeset,
          error: inspect(error)
        )
    end
  end

  def recheck(conn, _) do
    case CredentialsForm.check_database_and_write_config() do
      :ok ->
        redirect(conn, to: Routes.setup_path(conn, :migrations))

      {:error, %DBConnection.ConnectionError{}, _} ->
        render(conn, "run_psql.html",
          error:
            "Pleroma can't connect to the database with these credentials. Please check them and try one more time."
        )

      {:error, :extensions_not_installed, _} ->
        render(conn, "run_psql.html", error: "Some required extensions were not found.")

      {:error, error, _} ->
        render(conn, "run_psql.html", error: inspect(error))
    end
  end

  def migrations(conn, _) do
    render(conn, "migrations.html")
  end

  def run_migrations(conn, _) do
    response =
      case CredentialsForm.migrations() do
        :ok -> "ok"
        _ -> "Error occuried while migrations were run."
      end

    json(conn, response)
  end

  def config(conn, _) do
    render(conn, "config.html",
      config:
        ConfigForm.changeset(%{
          instance_static_dir: "instance/static",
          endpoint_url_port: 443,
          endpoint_http_ip: "127.0.0.1",
          endpoint_http_port: 4000,
          local_uploads_dir: "uploads"
        }),
      error: nil
    )
  end

  def save_config(conn, params) do
    changeset = ConfigForm.changeset(params["config_form"])

    case ConfigForm.save(changeset) do
      :ok ->
        Config.delete(:installer_token)

        if Config.get(:env) != :test do
          if endpoint = Process.whereis(Pleroma.Web.Endpoint) do
            Supervisor.stop(endpoint)
          end

          Pleroma.Application.stop_installer_and_start_pleroma()
        end

        redirect(conn, external: Pleroma.Web.Endpoint.url())

      {:error, %Ecto.Changeset{} = changeset} ->
        render(conn, "config.html", config: changeset, error: "Some values have incorrect values.")

      {:error, :config_file_not_found} ->
        render(conn, "config.html", config: changeset, error: "Something went wrong.")

      {:error, error} ->
        render(conn, "config.html", config: changeset, error: inspect(error))
    end
  end

  defp authenticate(conn, _) do
    token = Config.get(:installer_token)

    cond do
      token && get_session(conn, :token) == token ->
        conn

      token && conn.query_params["token"] == token ->
        put_session(conn, :token, token)

      true ->
        conn
        |> text("Token is invalid")
        |> halt()
    end
  end
end
