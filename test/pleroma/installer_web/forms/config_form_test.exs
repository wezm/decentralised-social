defmodule Pleroma.InstallerWeb.Forms.ConfigFormTest do
  use Pleroma.DataCase

  import ExUnit.CaptureIO
  import Mox

  alias Pleroma.Installer.FileMock
  alias Pleroma.Installer.InstallerRepoMock
  alias Pleroma.InstallerWeb.Forms.ConfigForm

  @test_config "config/test_installer.secret.exs"

  setup do: clear_config(:config_path_in_test, @test_config)
  setup :verify_on_exit!
  setup :changeset

  defp config do
    %{
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
  end

  defp changeset(_) do
    [changeset: ConfigForm.changeset(config())]
  end

  describe "changeset/1" do
    test "valid attrs", %{changeset: changeset} do
      assert match?(
               %{
                 endpoint_url: "https://example.com",
                 endpoint_url_host: "example.com",
                 endpoint_url_port: 443,
                 endpoint_url_scheme: "https",
                 instance_email: "email@example.com",
                 instance_name: "name",
                 instance_notify_email: "notify@example.com",
                 instance_static_dir: "instance/static/",
                 local_uploads_dir: "uploads",
                 endpoint_http_ip: "127.0.0.1",
                 endpoint_http_port: 4000
               },
               changeset.changes
             )

      assert changeset.valid?
    end

    test "not valid attrs" do
      changeset = ConfigForm.changeset()

      refute Keyword.take(changeset.errors, [
               :instance_name,
               :instance_email,
               :instance_notify_email,
               :instance_static_dir,
               :endpoint_url,
               :local_uploads_dir
             ]) == []

      refute changeset.valid?
    end

    test "if create_admin_user is true, validate admin user fields" do
      changeset =
        config()
        |> Map.put(:create_admin_user, true)
        |> ConfigForm.changeset()

      refute Keyword.take(changeset.errors, [
               :admin_email,
               :admin_nickname,
               :admin_password
             ]) == []

      refute changeset.valid?
    end
  end

  test "config file doesn't exists", %{changeset: changeset} do
    assert {:error, :config_file_not_found} = ConfigForm.save(changeset)
  end

  describe "save/1" do
    setup do
      File.touch!(@test_config)
      File.mkdir_p!("instance/static")

      on_exit(fn ->
        File.rm!(@test_config)
        File.rm!("instance/static/robots.txt")
      end)
    end

    test "saving config into file", %{changeset: changeset} do
      clear_config([:installer, :file], Pleroma.Installer.File)

      capture_io(fn ->
        :ok =
          changeset
          |> Ecto.Changeset.change(configurable_from_database: false)
          |> ConfigForm.save()
      end) =~ "Writing instance/static/robots.txt"

      content = File.read!(@test_config)
      assert content =~ "url: [host: \"example.com\", scheme: \"https\", port: 443]"
      assert content =~ "http: [ip: {127, 0, 0, 1}, port: 4000]"
      assert content =~ "configurable_from_database: false"

      assert content =~
               "name: \"name\",\n  email: \"email@example.com\",\n  notify_email: \"notify@example.com\""

      assert content =~ "static_dir: \"instance/static/\""
      assert content =~ "config :pleroma, Pleroma.Uploaders.Local, uploads: \"uploads\""
    end

    test "saving config into file and database", %{changeset: changeset} do
      clear_config([:installer, :file], Pleroma.Installer.File)

      expect(InstallerRepoMock, :start_repo, fn _ -> {:ok, nil} end)

      capture_io(fn ->
        :ok = ConfigForm.save(changeset)
      end) =~ "Writing instance/static/robots.txt"

      content = File.read!(@test_config)
      assert content =~ "url: [host: \"example.com\", scheme: \"https\", port: 443]"
      assert content =~ "http: [ip: {127, 0, 0, 1}, port: 4000]"
      assert content =~ "configurable_from_database: true"

      refute content =~
               "name: \"name\",\n  email: \"email@example.com\",\n  notify_email: \"notify@example.com\""

      refute content =~ "static_dir: \"instance/static/\""
      refute content =~ "config :pleroma, Pleroma.Uploaders.Local, uploads: \"uploads\""

      assert Repo.aggregate(Pleroma.Config.Version, :count, :id) == 1
      configs = Repo.all(Pleroma.ConfigDB)
      assert length(configs) == 3

      Enum.each(configs, fn
        %{group: :pleroma, key: :instance, value: value} ->
          assert value == [
                   instance_email: "email@example.com",
                   instance_name: "name",
                   instance_notify_email: "notify@example.com",
                   instance_static_dir: "instance/static/"
                 ]

        %{group: :web_push_encryption, key: :vapid_details, value: value} ->
          assert value[:subject] == "mailto:email@example.com"

        %{group: :pleroma, key: Pleroma.Uploaders.Local, value: value} ->
          assert value == [uploads: "uploads"]
      end)
    end

    test "creating admin user" do
      expect(FileMock, :write, fn _, _, _ -> :ok end)
      expect(InstallerRepoMock, :start_repo, fn _ -> {:ok, nil} end)

      capture_io(fn ->
        :ok =
          config()
          |> Map.merge(%{
            create_admin_user: true,
            admin_email: "admin@example.com",
            admin_nickname: "admin",
            admin_password: "password"
          })
          |> ConfigForm.changeset()
          |> ConfigForm.save()
      end) =~ "Writing instance/static/robots.txt"

      user = Pleroma.User.get_by_nickname("admin")

      assert user.email == "admin@example.com"
      assert user.is_admin
    end
  end
end
