# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.ActivityPub.ObjectValidators.ListenValidator do
  use Ecto.Schema

  alias Pleroma.EctoType.ActivityPub.ObjectValidators
  alias Pleroma.Web.ActivityPub.ObjectValidators.CommonFixes
  alias Pleroma.Web.ActivityPub.ObjectValidators.CommonValidations

  import Ecto.Changeset

  @primary_key false
  @derive Jason.Encoder

  embedded_schema do
    quote do
      unquote do
        import Elixir.Pleroma.Web.ActivityPub.ObjectValidators.CommonFields
        message_fields()
      end
    end

    field(:actor, ObjectValidators.ObjectID)
    field(:published, ObjectValidators.DateTime)

    embeds_one :object, UrlObjectValidator, primary_key: false do
      field(:type, :string)

      field(:to, ObjectValidators.Recipients, default: [])
      field(:cc, ObjectValidators.Recipients, default: [])
      field(:bto, ObjectValidators.Recipients, default: [])
      field(:bcc, ObjectValidators.Recipients, default: [])

      field(:title, :string)
      field(:artist, :string)
      field(:album, :string)
      field(:length, :integer)
    end
  end

  def changeset(struct, data) do
    struct
    |> cast(data, __schema__(:fields) -- [:object])
    |> cast_embed(:object, with: &audio_changeset/2)
  end

  def audio_changeset(struct, data) do
    struct
    |> cast(data, Map.keys(struct) -- [:__struct__])
    |> validate_inclusion(:type, ["Audio"])
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
    |> validate_required([:id, :type, :object, :actor, :to, :cc, :published])
    |> CommonValidations.validate_actor_presence()
  end
end
