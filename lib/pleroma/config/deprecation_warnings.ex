# Pleroma: A lightweight social networking server
# Copyright © 2017-2020 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Config.DeprecationWarnings do
  alias Pleroma.Config

  require Logger
  alias Pleroma.Config

  @type config_namespace() :: atom() | [atom()]
  @type config_map() :: {config_namespace(), config_namespace(), String.t()}

  @mrf_config_map [
    {[:instance, :rewrite_policy], [:mrf, :policies],
     "\n* `config :pleroma, :instance, rewrite_policy` is now `config :pleroma, :mrf, policies`"},
    {[:instance, :mrf_transparency], [:mrf, :transparency],
     "\n* `config :pleroma, :instance, mrf_transparency` is now `config :pleroma, :mrf, transparency`"},
    {[:instance, :mrf_transparency_exclusions], [:mrf, :transparency_exclusions],
     "\n* `config :pleroma, :instance, mrf_transparency_exclusions` is now `config :pleroma, :mrf, transparency_exclusions`"}
  ]

  def check_simple_policy_tuples do
    has_strings =
      Config.get([:mrf_simple])
      |> Enum.map(fn
        {_, []} -> {}
        {_, v} -> Enum.max(v)
      end)
      |> Enum.max()
      |> is_binary

    if has_strings do
      Logger.warn("""
      !!!DEPRECATION WARNING!!!
      Your config is using strings in the SimplePolicy configuration instead of tuples. They should work for now, but you are advised to change to the new configuration to prevent possible issues later:

      ```
      config :pleroma, :mrf_simple,
        media_removal: ["instance.tld"],
        media_nsfw: ["instance.tld"],
        federated_timeline_removal: ["instance.tld"],
        report_removal: ["instance.tld"],
        reject: ["instance.tld"],
        followers_only: ["instance.tld"],
        accept: ["instance.tld"],
        avatar_removal: ["instance.tld"],
        banner_removal: ["instance.tld"],
        reject_deletes: ["instance.tld"]
      ```

      Is now


      ```
      config :pleroma, :mrf_simple,
        media_removal: [{"instance.tld", "Reason for media removal"}],
        media_nsfw: [{"instance.tld", "Reason for media nsfw"}],
        federated_timeline_removal: [{"instance.tld", "Reason for federated timeline removal"}],
        report_removal: [{"instance.tld", "Reason for report removal"}],
        reject: [{"instance.tld", "Reason for reject"}],
        followers_only: [{"instance.tld", "Reason for followers only"}],
        accept: [{"instance.tld", "Reason for accept"}],
        avatar_removal: [{"instance.tld", "Reason for avatar removal"}],
        banner_removal: [{"instance.tld", "Reason for banner removal"}],
        reject_deletes: [{"instance.tld", "Reason for reject deletes"}]
      ```
      """)

      new_config =
        Config.get([:mrf_simple])
        |> Enum.map(fn {k, v} ->
          {k,
           Enum.map(v, fn
             {instance, reason} -> {instance, reason}
             instance -> {instance, ""}
           end)}
        end)

      Config.put([:mrf_simple], new_config)

      :error
    else
      :ok
    end
  end

  def check_hellthread_threshold do
    if Config.get([:mrf_hellthread, :threshold]) do
      Logger.warn("""
      !!!DEPRECATION WARNING!!!
      You are using the old configuration mechanism for the hellthread filter. Please check config.md.
      """)

      :error
    else
      :ok
    end
  end

  def mrf_user_allowlist do
    config = Config.get(:mrf_user_allowlist)

    if config && Enum.any?(config, fn {k, _} -> is_atom(k) end) do
      rewritten =
        Enum.reduce(Config.get(:mrf_user_allowlist), Map.new(), fn {k, v}, acc ->
          Map.put(acc, to_string(k), v)
        end)

      Config.put(:mrf_user_allowlist, rewritten)

      Logger.error("""
      !!!DEPRECATION WARNING!!!
      As of Pleroma 2.0.7, the `mrf_user_allowlist` setting changed of format.
      Pleroma 2.1 will remove support for the old format. Please change your configuration to match this:

      config :pleroma, :mrf_user_allowlist, #{inspect(rewritten, pretty: true)}
      """)

      :error
    else
      :ok
    end
  end

  def warn do
    with :ok <- check_simple_policy_tuples(),
         :ok <- check_hellthread_threshold(),
         :ok <- mrf_user_allowlist(),
         :ok <- check_old_mrf_config(),
         :ok <- check_media_proxy_whitelist_config(),
         :ok <- check_welcome_message_config(),
         :ok <- check_gun_pool_options(),
         :ok <- check_activity_expiration_config() do
      :ok
    else
      _ ->
        :error
    end
  end

  def check_welcome_message_config do
    instance_config = Pleroma.Config.get([:instance])

    use_old_config =
      Keyword.has_key?(instance_config, :welcome_user_nickname) or
        Keyword.has_key?(instance_config, :welcome_message)

    if use_old_config do
      Logger.error("""
      !!!DEPRECATION WARNING!!!
      Your config is using the old namespace for Welcome messages configuration. You need to change to the new namespace:
      \n* `config :pleroma, :instance, welcome_user_nickname` is now `config :pleroma, :welcome, :direct_message, :sender_nickname`
      \n* `config :pleroma, :instance, welcome_message` is now `config :pleroma, :welcome, :direct_message, :message`
      """)

      :error
    else
      :ok
    end
  end

  def check_old_mrf_config do
    warning_preface = """
    !!!DEPRECATION WARNING!!!
    Your config is using old namespaces for MRF configuration. They should work for now, but you are advised to change to new namespaces to prevent possible issues later:
    """

    move_namespace_and_warn(@mrf_config_map, warning_preface)
  end

  @spec move_namespace_and_warn([config_map()], String.t()) :: :ok | nil
  def move_namespace_and_warn(config_map, warning_preface) do
    warning =
      Enum.reduce(config_map, "", fn
        {old, new, err_msg}, acc ->
          old_config = Config.get(old)

          if old_config do
            Config.put(new, old_config)
            acc <> err_msg
          else
            acc
          end
      end)

    if warning == "" do
      :ok
    else
      Logger.warn(warning_preface <> warning)
      :error
    end
  end

  @spec check_media_proxy_whitelist_config() :: :ok | nil
  def check_media_proxy_whitelist_config do
    whitelist = Config.get([:media_proxy, :whitelist])

    if Enum.any?(whitelist, &(not String.starts_with?(&1, "http"))) do
      Logger.warn("""
      !!!DEPRECATION WARNING!!!
      Your config is using old format (only domain) for MediaProxy whitelist option. Setting should work for now, but you are advised to change format to scheme with port to prevent possible issues later.
      """)

      :error
    else
      :ok
    end
  end

  def check_gun_pool_options do
    pool_config = Config.get(:connections_pool)

    if timeout = pool_config[:await_up_timeout] do
      Logger.warn("""
      !!!DEPRECATION WARNING!!!
      Your config is using old setting name `await_up_timeout` instead of `connect_timeout`. Setting should work for now, but you are advised to change format to scheme with port to prevent possible issues later.
      """)

      Config.put(:connections_pool, Keyword.put_new(pool_config, :connect_timeout, timeout))
    end

    pools_configs = Config.get(:pools)

    warning_preface = """
    !!!DEPRECATION WARNING!!!
    Your config is using old setting name `timeout` instead of `recv_timeout` in pool settings. Setting should work for now, but you are advised to change format to scheme with port to prevent possible issues later.
    """

    updated_config =
      Enum.reduce(pools_configs, [], fn {pool_name, config}, acc ->
        if timeout = config[:timeout] do
          Keyword.put(acc, pool_name, Keyword.put_new(config, :recv_timeout, timeout))
        else
          acc
        end
      end)

    if updated_config != [] do
      pool_warnings =
        updated_config
        |> Keyword.keys()
        |> Enum.map(fn pool_name ->
          "\n* `:timeout` options in #{pool_name} pool is now `:recv_timeout`"
        end)

      Logger.warn(Enum.join([warning_preface | pool_warnings]))

      Config.put(:pools, updated_config)
      :error
    else
      :ok
    end
  end

  @spec check_activity_expiration_config() :: :ok | nil
  def check_activity_expiration_config do
    warning_preface = """
    !!!DEPRECATION WARNING!!!
      Your config is using old namespace for activity expiration configuration. Setting should work for now, but you are advised to change to new namespace to prevent possible issues later:
    """

    move_namespace_and_warn(
      [
        {Pleroma.ActivityExpiration, Pleroma.Workers.PurgeExpiredActivity,
         "\n* `config :pleroma, Pleroma.ActivityExpiration` is now `config :pleroma, Pleroma.Workers.PurgeExpiredActivity`"}
      ],
      warning_preface
    )
  end
end
