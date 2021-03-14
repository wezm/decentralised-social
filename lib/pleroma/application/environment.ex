# Pleroma: A lightweight social networking server
# Copyright © 2017-2021 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Application.Environment do
  @moduledoc """
  Overwrites environment config with settings from config file or database.
  """

  require Logger

  @spec load_from_db_and_update(keyword()) :: :ok
  def load_from_db_and_update(opts \\ []) do
    Pleroma.ConfigDB.all()
    |> update(opts)
  end

  @spec update([Pleroma.ConfigDB.t()], keyword()) :: :ok
  def update(changes, opts \\ []) when is_list(changes) do
    if Pleroma.Config.get(:configurable_from_database) do
      defaults = Pleroma.Config.Holder.default_config()

      configure_logger_and_quack(changes, defaults)

      changes
      |> Enum.map(fn config ->
        {_, merged_value} = Pleroma.ConfigDB.merge_with_default(config, defaults)

        %{config | value: merged_value}
      end)
      |> Enum.each(&update_env(&1))

      cond do
        # restart only apps on pleroma start
        opts[:pleroma_start] ->
          changes
          |> Enum.filter(fn %{group: group} ->
            group not in [:logger, :quack, :pleroma, :prometheus, :postgrex]
          end)
          |> Pleroma.Application.ConfigDependentDeps.save_config_paths_for_restart()

          Pleroma.Application.ConfigDependentDeps.restart_dependencies()

        opts[:only_update] ->
          Pleroma.Application.ConfigDependentDeps.save_config_paths_for_restart(changes)

        true ->
          nil
      end
    end

    :ok
  end

  defp configure_logger_and_quack(changes, defaults) do
    {logger_changes, quack_changes} =
      changes
      |> Enum.filter(fn %{group: group} -> group in [:logger, :quack] end)
      |> Enum.split_with(fn %{group: group} -> group == :logger end)

    quack_config = to_keyword(quack_changes)

    if quack_config != [] do
      merged = Keyword.merge(defaults[:quack], quack_config)
      Logger.configure_backend(Quack.Logger, merged)
    end

    logger_config = to_keyword(logger_changes)

    if logger_config != [] do
      merged = Keyword.merge(defaults, logger_config)

      if logger_config[:backends] do
        Enum.each(Application.get_env(:logger, :backends), &Logger.remove_backend/1)

        Enum.each(merged[:backends], &Logger.add_backend/1)
      end

      if logger_config[:console] do
        console = merged[:console]
        console = put_in(console[:format], console[:format] <> "\n")

        Logger.configure_backend(:console, console)
      end

      if logger_config[:ex_syslogger] do
        Logger.configure_backend({ExSyslogger, :ex_syslogger}, merged[:ex_syslogger])
      end

      Logger.configure(merged)
    end
  end

  defp to_keyword(changes) do
    Enum.reduce(changes, [], fn
      %{key: key, value: value}, acc ->
        Keyword.put(acc, key, value)
    end)
  end

  defp update_env(%{group: group, key: key, value: nil}), do: Application.delete_env(group, key)

  defp update_env(%{group: group, key: key, value: config}) do
    Application.put_env(group, key, config)
  end
end
