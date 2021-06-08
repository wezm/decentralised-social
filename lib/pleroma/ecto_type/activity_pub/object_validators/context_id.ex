# Pleroma: A lightweight social networking server
# Copyright © 2017-2021 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.EctoType.ActivityPub.ObjectValidators.ContextID do
  use Ecto.Type

  alias Ecto.UUID
  alias Pleroma.Web.Endpoint

  def type, do: :string

  def cast(context) when is_binary(context), do: {:ok, context}

  def cast(_), do: :error

  def dump(data), do: {:ok, data}

  def load(data), do: {:ok, data}

  def autogenerate do
    "#{Endpoint.url()}/contexts/#{UUID.generate()}"
  end
end
