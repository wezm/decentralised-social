# Pleroma: A lightweight social networking server
# Copyright © 2017-2021 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Application.EnvironmentTest do
  use Pleroma.DataCase

  import Pleroma.Factory

  alias Pleroma.Application.Environment

  setup do: clear_config(:configurable_from_database, true)

  describe "load_from_db_and_update/0" do
    test "transfer config values from db to env" do
      refute Application.get_env(:pleroma, :test_key)
      refute Application.get_env(:idna, :test_key)
      refute Application.get_env(:quack, :test_key)
      refute Application.get_env(:postgrex, :test_key)
      initial = Application.get_env(:logger, :level)

      insert(:config, key: :test_key, value: [live: 2, com: 3])
      insert(:config, group: :idna, key: :test_key, value: [live: 15, com: 35])

      insert(:config,
        group: :quack,
        key: :test_key,
        value: [key1: :test_value1, key2: :test_value2]
      )

      insert(:config, group: :logger, key: :level, value: :debug)

      Environment.load_from_db_and_update()

      assert Application.get_env(:pleroma, :test_key) == [live: 2, com: 3]
      assert Application.get_env(:idna, :test_key) == [live: 15, com: 35]
      assert Application.get_env(:quack, :test_key) == [key1: :test_value1, key2: :test_value2]
      assert Application.get_env(:logger, :level) == :debug

      on_exit(fn ->
        Application.delete_env(:pleroma, :test_key)
        Application.delete_env(:idna, :test_key)
        Application.delete_env(:quack, :test_key)
        Application.delete_env(:postgrex, :test_key)
        Application.put_env(:logger, :level, initial)
      end)
    end

    test "transfer config values for 1 group and some keys" do
      quack_env = Application.get_all_env(:quack)

      insert(:config, group: :quack, key: :level, value: :info)
      insert(:config, group: :quack, key: :meta, value: [:none])

      Environment.load_from_db_and_update()

      assert Application.get_env(:quack, :level) == :info
      assert Application.get_env(:quack, :meta) == [:none]
      default = Pleroma.Config.Holder.default_config(:quack, :webhook_url)
      assert Application.get_env(:quack, :webhook_url) == default

      on_exit(fn ->
        Application.put_all_env(quack: quack_env)
      end)
    end

    test "transfer config values with full subkey update" do
      clear_config(:emoji)
      clear_config(:assets)

      insert(:config, key: :emoji, value: [groups: [a: 1, b: 2]])
      insert(:config, key: :assets, value: [mascots: [a: 1, b: 2]])

      Environment.load_from_db_and_update()

      emoji_env = Application.get_env(:pleroma, :emoji)
      assert emoji_env[:groups] == [a: 1, b: 2]
      assets_env = Application.get_env(:pleroma, :assets)
      assert assets_env[:mascots] == [a: 1, b: 2]
    end
  end

  describe "update/2 :ex_syslogger" do
    setup do
      initial = Application.get_env(:logger, :ex_syslogger)

      config =
        insert(:config,
          group: :logger,
          key: :ex_syslogger,
          value: [
            level: :warn,
            ident: "pleroma",
            format: "$metadata[$level] $message",
            metadata: [:request_id, :key]
          ]
        )

      on_exit(fn -> Application.put_env(:logger, :ex_syslogger, initial) end)
      [config: config, initial: initial]
    end

    test "changing", %{config: config} do
      assert Environment.update([config]) == :ok

      env = Application.get_env(:logger, :ex_syslogger)
      assert env[:level] == :warn
      assert env[:metadata] == [:request_id, :key]
    end

    test "deletion", %{config: config, initial: initial} do
      assert Environment.update([config]) == :ok

      {:ok, config} = Pleroma.ConfigDB.delete(config)
      assert Environment.update([config]) == :ok

      env = Application.get_env(:logger, :ex_syslogger)

      assert env == initial
    end
  end

  describe "update/2 :console" do
    setup do
      initial = Application.get_env(:logger, :console)

      config =
        insert(:config,
          group: :logger,
          key: :console,
          value: [
            level: :info,
            format: "$time $metadata[$level]",
            metadata: [:request_id, :key]
          ]
        )

      on_exit(fn -> Application.put_env(:logger, :console, initial) end)
      [config: config, initial: initial]
    end

    test "change", %{config: config} do
      assert Environment.update([config]) == :ok
      env = Application.get_env(:logger, :console)
      assert env[:level] == :info
      assert env[:format] == "$time $metadata[$level]"
      assert env[:metadata] == [:request_id, :key]
    end

    test "deletion", %{config: config, initial: initial} do
      assert Environment.update([config]) == :ok
      {:ok, config} = Pleroma.ConfigDB.delete(config)
      assert Environment.update([config]) == :ok

      env = Application.get_env(:logger, :console)
      assert env == initial
    end
  end

  describe "update/2 :backends" do
    setup do
      initial = Application.get_all_env(:logger)

      config = insert(:config, group: :logger, key: :backends, value: [:console, :ex_syslogger])

      on_exit(fn -> Application.put_all_env(logger: initial) end)

      [config: config, initial: initial]
    end

    test "change", %{config: config} do
      assert Environment.update([config]) == :ok
      env = Application.get_all_env(:logger)
      assert env[:backends] == [:console, :ex_syslogger]
    end

    test "deletion", %{config: config, initial: initial} do
      assert Environment.update([config]) == :ok
      {:ok, config} = Pleroma.ConfigDB.delete(config)
      assert Environment.update([config])

      env = Application.get_all_env(:logger)
      assert env == initial
    end
  end

  test "update/2 logger settings" do
    initial = Application.get_all_env(:logger)

    config1 =
      insert(:config,
        group: :logger,
        key: :console,
        value: [
          level: :info,
          format: "$time $metadata[$level]",
          metadata: [:request_id, :key]
        ]
      )

    config2 =
      insert(:config,
        group: :logger,
        key: :ex_syslogger,
        value: [
          level: :warn,
          ident: "pleroma",
          format: "$metadata[$level] $message",
          metadata: [:request_id, :key]
        ]
      )

    config3 = insert(:config, group: :logger, key: :backends, value: [:console, :ex_syslogger])

    on_exit(fn -> Application.put_all_env(logger: initial) end)

    assert Environment.update([config1, config2, config3]) == :ok

    env =
      :logger
      |> Application.get_all_env()
      |> Keyword.take([:backends, :console, :ex_syslogger])

    assert env[:console] == config1.value
    assert env[:ex_syslogger] == config2.value
    assert env[:backends] == config3.value
  end

  test "update/2 for change without key :cors_plug" do
    initial = Application.get_all_env(:cors_plug)
    config1 = insert(:config, group: :cors_plug, key: :max_age, value: 300)
    config2 = insert(:config, group: :cors_plug, key: :methods, value: ["GET"])

    assert Environment.update([config1, config2]) == :ok

    env = Application.get_all_env(:cors_plug)

    assert env[:max_age] == 300
    assert env[:methods] == ["GET"]

    on_exit(fn -> Application.put_all_env(cors_plug: initial) end)
  end
end
