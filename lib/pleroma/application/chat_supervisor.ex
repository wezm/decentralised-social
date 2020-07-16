# Pleroma: A lightweight social networking server
# Copyright © 2017-2021 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Application.ChatSupervisor do
  use Supervisor

  def start_link(_) do
    Supervisor.start_link(__MODULE__, :no_args)
  end

  def init(_) do
    [
      Pleroma.Web.ChatChannel.ChatChannelState,
      {Phoenix.PubSub, [name: Pleroma.PubSub, adapter: Phoenix.PubSub.PG2]}
    ]
    |> Supervisor.init(strategy: :one_for_one)
  end
end
