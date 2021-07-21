# Pleroma: A lightweight social networking server
# Copyright © 2017-2021 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.ActivityPub.ObjectValidators.ListenValidator do
  use Ecto.Schema

  alias Pleroma.EctoType.ActivityPub.ObjectValidators
  alias Pleroma.Web.ActivityPub.ObjectValidators.CommonFixes
  alias Pleroma.Web.ActivityPub.ObjectValidators.CommonValidations

  import Ecto.Changeset

  @primary_key false

  embedded_schema do
    field(:id, ObjectValidators.ObjectID, primary_key: true)
    field(:type, :string)
    field(:published, ObjectValidators.DateTime)
    field(:object, ObjectValidators.ObjectID)
    field(:actor, ObjectValidators.ObjectID)
    field(:context, :string)
    field(:to, ObjectValidators.Recipients, default: [])
    field(:cc, ObjectValidators.Recipients, default: [])
    field(:bto, ObjectValidators.Recipients, default: [])
    field(:bcc, ObjectValidators.Recipients, default: [])
  end

  def changeset(struct, data) do
    struct
    |> cast(data, __schema__(:fields))
  end

  def cast_data(data, meta \\ []) do
    data = fix(data, meta)

    %__MODULE__{}
    |> changeset(data)
  end

  def cast_and_validate(data, meta \\ []) do
    data
    |> cast_data(meta)
    |> validate_data(meta)
  end

  defp fix(data, _meta) do
    data
    |> CommonFixes.fix_actor()
    |> CommonFixes.fix_activity_addressing()
  end

  defp validate_data(data_cng, _meta) do
    # TODO: Restrict to Audio objects

    data_cng
    |> validate_inclusion(:type, ["Listen"])
    |> validate_required([:id, :type, :object, :actor, :to, :cc])
    |> CommonValidations.validate_actor_presence()
  end
end
