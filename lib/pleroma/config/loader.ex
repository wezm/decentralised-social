# Pleroma: A lightweight social networking server
# Copyright © 2017-2021 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Config.Loader do
  @reject_groups [
    :postgrex,
    :tesla,
    :phoenix,
    :tzdata,
    :http_signatures,
    :web_push_encryption,
    :floki,
    :pbkdf2_elixir
  ]

  @reject_keys [
    Pleroma.Repo,
    Pleroma.Web.Endpoint,
    Pleroma.InstallerWeb.Endpoint,
    :env,
    :configurable_from_database,
    :database,
    :ecto_repos,
    Pleroma.Gun,
    Pleroma.ReverseProxy.Client,
    Pleroma.Web.Auth.Authenticator
  ]

  if Code.ensure_loaded?(Config.Reader) do
    @reader Config.Reader
  else
    # support for Elixir less than 1.9
    @reader Mix.Config
  end

  @spec read!(Path.t()) :: keyword()
  def read!(path), do: @reader.read!(path)

  @spec merge(keyword(), keyword()) :: keyword()
  def merge(c1, c2), do: @reader.merge(c1, c2)

  @spec default_config() :: keyword()
  def default_config do
    config =
      "config/config.exs"
      |> read!()
      |> filter()

    logger_config = Application.get_all_env(:logger)

    merge(config, logger: logger_config)
  end

  @spec filter(keyword()) :: keyword()
  def filter(configs) do
    configs
    |> Enum.reduce([], fn
      {group, _settings}, group_acc when group in @reject_groups ->
        group_acc

      {group, settings}, group_acc ->
        filtered_settings =
          Enum.reduce(settings, [], fn
            {key, _value}, settings_acc when key in @reject_keys ->
              settings_acc

            {key, _value}, settings_acc when group == :phoenix and key == :serve_endpoint ->
              settings_acc

            {key, value}, settings_acc ->
              Keyword.put(settings_acc, key, value)
          end)

        Keyword.put(group_acc, group, filtered_settings)
    end)
  end
end
