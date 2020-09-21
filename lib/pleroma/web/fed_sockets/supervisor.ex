# Pleroma: A lightweight social networking server
# Copyright © 2017-2020 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.FedSockets.Supervisor do
  use Supervisor
  import Cachex.Spec

  def start_link(opts) do
    Supervisor.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def init(args) do
    children = [
      build_cache(:fed_socket_rejections, args),
      {Registry, keys: :unique, name: Pleroma.Web.FedSockets.Registry},
      {DynamicSupervisor, name: Pleroma.Web.FedSockets.ClientSupervisor, strategy: :one_for_one}
    ]

    opts = [strategy: :one_for_all, name: Pleroma.Web.Streamer.Supervisor]
    Supervisor.init(children, opts)
  end

  defp build_cache(name, args) do
    opts = get_opts(name, args)

    %{
      id: String.to_atom("#{name}_cache"),
      start: {Cachex, :start_link, [name, opts]},
      type: :worker
    }
  end

  defp get_opts(:fed_socket_rejections = cache_name, args) do
    default = get_opts_or_config(args, cache_name, :default, 15_000)
    interval = get_opts_or_config(args, cache_name, :interval, 3_000)
    lazy = get_opts_or_config(args, cache_name, :lazy, false)

    [expiration: expiration(default: default, interval: interval, lazy: lazy)]
  end

  defp get_opts(name, args) do
    Keyword.get(args, name, [])
  end

  defp get_opts_or_config(args, name, key, default) do
    args
    |> Keyword.get(name, [])
    |> Keyword.get(key)
    |> case do
      nil ->
        Pleroma.Config.get([:fed_sockets, name, key], default)

      value ->
        value
    end
  end
end
