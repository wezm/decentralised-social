# Pleroma: A lightweight social networking server
# Copyright © 2017-2021 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.InstallerWeb.SetupControllerTest do
  use Pleroma.InstallerWeb.ConnCase

  import ExUnit.CaptureLog
  import Mox

  alias Pleroma.Installer.FileMock
  alias Pleroma.Installer.InstallerRepoMock
  alias Pleroma.Repo

  setup :verify_on_exit!

  @token "secret_token"
  @test_config "config/test_installer.secret.exs"

  setup do: clear_config(Repo)
  setup do: clear_config([:database, :rum_enabled])
  setup do: clear_config(:credentials)
  setup do: clear_config(:config_path_in_test, @test_config)
  setup do: clear_config(:installer_token, @token)

  defp token(%{conn: conn}), do: [conn: init_test_session(conn, %{token: @token})]

  defp credentials(_) do
    config = Repo.config()

    credentials = %{
      database: "pleroma_installer",
      username: "pleroma_installer",
      password: "password",
      rum_enabled: false,
      hostname: Keyword.fetch!(config, :hostname),
      pool_size: 2
    }

    [credentials: credentials]
  end

  describe "GET /" do
    test "without token", %{conn: conn} do
      assert conn |> get("/") |> text_response(200) =~ "Token is invalid"
    end

    test "with token", %{conn: conn} do
      assert conn |> get("/?token=#{@token}") |> html_response(200) =~
               "Database settings"
    end
  end

  describe "POST `/credentials` errors" do
    setup :token
    setup :credentials

    test "invalid params", %{conn: conn} do
      assert conn
             |> post("/credentials", %{
               credentials_form: %{database: "", username: "", password: ""}
             })
             |> html_response(200) =~ "can&#39;t be blank"
    end

    test "create database error", %{conn: conn, credentials: credentials} do
      InstallerRepoMock
      |> expect(:check_database, fn _ -> {:error, nil} end)
      |> expect(:create_database, fn _ -> {:error, %DBConnection.ConnectionError{}, []} end)
      |> expect(:stop, fn -> :ok end)

      assert conn
             |> post("/credentials", %{credentials_form: credentials})
             |> html_response(200) =~
               "Error occuried: Pleroma can&#39;t connect to the database with these credentials. Please check them and try one more time."
    end

    test "error another error on another error", %{conn: conn, credentials: credentials} do
      InstallerRepoMock
      |> expect(:check_database, fn _ -> {:error, nil} end)
      |> expect(:create_database, fn _ -> {:error, :another_error, []} end)
      |> expect(:stop, fn -> :ok end)

      assert conn
             |> post("/credentials", %{credentials_form: credentials})
             |> html_response(200) =~ "Error occuried: :another_error"
    end
  end

  describe "POST /credentials" do
    setup :token
    setup :credentials

    test "saves credentials", %{conn: conn, credentials: credentials} do
      InstallerRepoMock
      |> expect(:check_database, fn _ -> :ok end)
      |> expect(:stop, fn -> :ok end)

      assert conn
             |> post("/credentials", %{
               credentials_form: credentials
             })
             |> redirected_to() =~ "/migrations"

      config = File.read!(@test_config)
      assert config =~ "password: \"#{credentials[:password]}\""

      on_exit(fn ->
        File.rm!(@test_config)
      end)
    end

    test "saves credentials with generated password", %{conn: conn, credentials: credentials} do
      InstallerRepoMock
      |> expect(:check_database, fn _ -> :ok end)
      |> expect(:stop, fn -> :ok end)

      assert conn
             |> post("/credentials", %{
               credentials_form: Map.put(credentials, :password, "")
             })
             |> redirected_to() =~ "/migrations"

      config = File.read!(@test_config)
      refute config =~ "password: \"#{credentials[:password]}\""

      on_exit(fn ->
        File.rm!(@test_config)
      end)
    end

    test "saves credentials after creating database", %{conn: conn, credentials: credentials} do
      InstallerRepoMock
      |> expect(:check_database, fn _ -> {:error, nil} end)
      |> expect(:check_database, fn _ -> :ok end)
      |> expect(:create_database, fn _ -> :ok end)
      |> expect(:stop, 3, fn -> :ok end)

      assert conn
             |> post("/credentials", %{credentials_form: credentials})
             |> redirected_to() =~ "/migrations"

      config = File.read!(@test_config)
      assert config =~ "password: \"#{credentials[:password]}\""

      on_exit(fn ->
        File.rm!(@test_config)
      end)
    end

    test "creates psql file after creation database error", %{
      conn: conn,
      credentials: credentials
    } do
      InstallerRepoMock
      |> expect(:check_database, fn _ -> {:error, nil} end)
      |> expect(:create_database, fn _ -> {:error, :create_repo} end)
      |> expect(:stop, fn -> :ok end)

      capture_log(fn ->
        assert conn
               |> post("/credentials", %{credentials_form: credentials})
               |> html_response(200) =~ "Run following command to setup PostgreSQL"
      end) =~ "Writing the postgres script to /tmp/setup_db.psql"

      psql_file_path = "/tmp/setup_db.psql"
      psql_file = File.read!(psql_file_path)

      assert psql_file =~
               "CREATE USER #{credentials[:username]} WITH ENCRYPTED PASSWORD '#{
                 credentials[:password]
               }';"

      on_exit(fn -> File.rm!(psql_file_path) end)
    end
  end

  describe "GET /recheck" do
    setup :token
    setup :credentials

    setup do: clear_config(:credentials)

    test "db connection error", %{conn: conn, credentials: credentials} do
      expect(InstallerRepoMock, :check_database, fn _ ->
        {:error, %DBConnection.ConnectionError{}}
      end)

      Pleroma.Config.put(:credentials, Keyword.new(credentials))

      assert conn |> get("/recheck") |> html_response(200) =~
               "Are you sure psql file was executed?"
    end

    test "extensions not installed error", %{conn: conn, credentials: credentials} do
      expect(InstallerRepoMock, :check_database, fn _ -> {:error, :extensions_not_installed} end)

      Pleroma.Config.put(:credentials, Keyword.new(credentials))

      assert conn |> get("/recheck") |> html_response(200) =~
               "Some required extensions were not found."
    end

    test "another error", %{conn: conn, credentials: credentials} do
      expect(InstallerRepoMock, :check_database, fn _ -> {:error, :another} end)

      Pleroma.Config.put(:credentials, Keyword.new(credentials))

      assert conn |> get("/recheck") |> html_response(200) =~
               ":another"
    end

    test "writes config file", %{conn: conn, credentials: credentials} do
      InstallerRepoMock
      |> expect(:check_database, fn _ -> :ok end)
      |> expect(:stop, fn -> :ok end)

      Pleroma.Config.put(:credentials, Keyword.new(credentials))

      assert conn |> get("/recheck") |> redirected_to() =~ "/migrations"

      config = File.read!(@test_config)
      assert config =~ "password: \"#{credentials[:password]}\""

      on_exit(fn ->
        File.rm!(@test_config)
      end)
    end
  end

  describe "GET /run_migrations" do
    setup :token

    test "with error", %{conn: conn} do
      expect(InstallerRepoMock, :run_migrations, fn _, _ -> {:error, :migrations_error} end)

      assert conn |> get("/run_migrations") |> json_response(200) ==
               "Error occuried while migrations were run."
    end

    test "success", %{conn: conn} do
      expect(InstallerRepoMock, :run_migrations, fn _, _ -> :ok end)

      assert conn |> get("/run_migrations") |> json_response(200) == "ok"
    end
  end

  describe "GET /migrations" do
    setup :token

    test "", %{conn: conn} do
      assert conn |> get("/migrations") |> html_response(200) =~
               "The database is almost ready. Migrations are running."
    end
  end

  describe "GET /config" do
    setup :token

    test "config", %{conn: conn} do
      assert conn |> get("/config") |> html_response(200) =~
               "What is the name of your instance?"
    end
  end

  describe "POST /config" do
    setup :token

    test "validation error", %{conn: conn} do
      assert conn
             |> post("/config", %{
               config_form: %{
                 instance_static_dir: "instance/static",
                 endpoint_url_port: 443,
                 endpoint_http_ip: "127.0.0.1",
                 endpoint_http_port: 4000,
                 local_uploads_dir: "uploads"
               }
             })
             |> html_response(200) =~ "can&#39;t be blank"
    end

    test "config file not found error", %{conn: conn} do
      assert conn
             |> post("/config", %{
               config_form: %{
                 instance_static_dir: "instance/static",
                 endpoint_url: "https://example.com",
                 endpoint_http_ip: "127.0.0.1",
                 endpoint_http_port: 4000,
                 local_uploads_dir: "uploads",
                 instance_name: "test",
                 instance_email: "test@example.com",
                 instance_notify_email: "test@example.com",
                 create_admin_user: false
               }
             })
             |> html_response(200) =~ "Error occuried: Something went wrong."
    end

    test "file write error", %{conn: conn} do
      expect(FileMock, :write, fn _, _, _ -> {:error, :enospc} end)
      File.touch(@test_config)

      assert conn
             |> post("/config", %{
               config_form: %{
                 instance_static_dir: "instance/static",
                 endpoint_url: "https://example.com",
                 endpoint_http_ip: "127.0.0.1",
                 endpoint_http_port: 4000,
                 local_uploads_dir: "uploads",
                 instance_name: "test",
                 instance_email: "test@example.com",
                 instance_notify_email: "test@example.com",
                 create_admin_user: false
               }
             })
             |> html_response(200) =~ "Error occuried: :enospc"

      on_exit(fn -> File.rm!(@test_config) end)
    end

    test "saving instance config", %{conn: conn} do
      expect(InstallerRepoMock, :start_repo, fn _ -> {:ok, nil} end)
      [credentials: credentials] = credentials([])
      Pleroma.Config.put(:credentials, Keyword.new(credentials))
      assert Pleroma.Config.get(:installer_token) == @token

      File.touch(@test_config)

      expect(FileMock, :write, fn _, _, _ -> :ok end)

      static_dir = Pleroma.Config.get([:instance, :static_dir])

      ExUnit.CaptureIO.capture_io(fn ->
        assert conn
               |> post("/config", %{
                 config_form: %{
                   instance_static_dir: static_dir,
                   endpoint_url: "https://example.com",
                   endpoint_http_ip: "127.0.0.1",
                   endpoint_http_port: 4000,
                   local_uploads_dir: "uploads",
                   instance_name: "test",
                   instance_email: "test@example.com",
                   instance_notify_email: "test@example.com",
                   create_admin_user: false
                 }
               })
               |> redirected_to() =~ Pleroma.Web.Endpoint.url()
      end) =~ "Writing test/instance_static/robots.txt."

      on_exit(fn ->
        File.rm!(@test_config)
        File.rm!(static_dir <> "/robots.txt")
      end)
    end
  end

  describe "integration" do
    @describetag :installer_integration
    setup :token
    setup :credentials

    setup %{credentials: credentials} do
      default = Repo.get_dynamic_repo()

      InstallerRepoMock
      |> expect(:check_database, fn credentials ->
        Pleroma.Installer.InstallerRepo.check_database(credentials)
      end)
      |> expect(:create_database, fn credentials ->
        Pleroma.Installer.InstallerRepo.create_database(credentials)
      end)
      |> expect(:run_migrations, fn credentials, paths ->
        Pleroma.Installer.InstallerRepo.run_migrations(credentials, paths)
      end)
      |> expect(:start_repo, fn credentials ->
        Pleroma.Installer.InstallerRepo.start_repo(credentials)
      end)
      |> expect(:stop, fn -> Pleroma.Installer.InstallerRepo.stop() end)

      expect(FileMock, :write, fn path, content, modes ->
        Pleroma.Installer.File.write(path, content, modes)
      end)

      on_exit(fn ->
        File.rm!(@test_config)
        Repo.put_dynamic_repo(default)
        :ok = Ecto.Adapters.Postgres.storage_down(Keyword.new(credentials))
        :ok = Ecto.Adapters.SQL.Sandbox.checkout(Repo)

        Ecto.Adapters.SQL.Sandbox.unboxed_run(Repo, fn ->
          {:ok, _} = Repo.query("DROP USER pleroma_installer;")
        end)
      end)
    end

    test "correct credentials", %{conn: conn, credentials: credentials} do
      assert conn
             |> post("/credentials", %{
               credentials_form: credentials
             })
             |> redirected_to() =~ "/migrations"

      assert File.exists?(@test_config)
      assert_credentials(credentials)

      capture_log(fn ->
        assert conn |> get("/run_migrations") |> json_response(200) == "ok"
      end) =~ "ATTENTION ATTENTION ATTENTION"

      assert Repo
             |> Ecto.Migrator.migrations([Ecto.Migrator.migrations_path(Repo)],
               dynamic_repo: Pleroma.Installer.InstallerRepo.dynamic_repo()
             )
             |> Enum.reject(fn {dir, _, _} -> dir == :up end) == []

      assert_credentials(credentials)

      Pleroma.Installer.InstallerRepo.stop()

      assert conn
             |> get("/config")
             |> html_response(200) =~
               "Do you want to deny Search Engine bots from crawling the site?"

      assert_credentials(credentials)

      assert conn
             |> post("/config", %{
               config_form: %{
                 instance_name: "name",
                 instance_email: "email@example.com",
                 instance_notify_email: "notify@example.com",
                 instance_static_dir: "instance/static/",
                 endpoint_url: "https://example.com",
                 endpoint_http_ip: "127.0.0.1",
                 endpoint_http_port: 4000,
                 local_uploads_dir: "uploads",
                 configurable_from_database: true,
                 indexable: true,
                 create_admin_user: false
               }
             })
             |> redirected_to() =~ "/"
    end

    defp assert_credentials(credentials) do
      assert Pleroma.Config.get(:credentials) ==
               credentials |> Map.put(:pool_size, 2) |> Keyword.new()
    end
  end
end
