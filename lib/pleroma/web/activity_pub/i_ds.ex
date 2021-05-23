# Pleroma: A lightweight social networking server
# Copyright © 2017-2021 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.ActivityPub.IDs do
  alias Ecto.UUID
  alias Pleroma.Web.Endpoint
  alias Pleroma.Web.Router.Helpers, as: Routes

  def generate_activity_id do
    generate_id("activities")
  end

  def generate_context_id do
    generate_id("contexts")
  end

  def generate_object_id do
    Routes.o_status_url(Endpoint, :object, UUID.generate())
  end

  def generate_id(type) do
    "#{Endpoint.url()}/#{type}/#{UUID.generate()}"
  end

  def as_local_public, do: Endpoint.url() <> "/#Public"
end
