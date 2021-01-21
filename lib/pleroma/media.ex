defmodule Pleroma.Media do
  use Ecto.Schema

  import Ecto.Changeset

  alias Pleroma.Media
  alias Pleroma.Repo
  alias Pleroma.User

  @derive {Jason.Encoder,
           only: [:href, :type, :media_type, :name, :blurhash, :meta, :object_id, :actor]}

  @type t() :: %__MODULE__{}

  schema "media" do
    field(:href, :string)
    field(:type, :string)
    field(:media_type, :string)
    field(:name, :string)
    field(:blurhash, :string)
    field(:meta, :map)
    field(:actor, :string)

    field(:removable, :boolean, virtual: true, default: false)

    belongs_to(:object, Pleroma.Object)

    timestamps()
  end

  def create_from_object_data(%{"url" => [url]} = data, %{actor: actor} = opts) do
    object_id = get_in(opts, [:object, "id"]) || Map.get(opts, :object_id)

    %Media{}
    |> changeset(%{
      href: url["href"],
      type: url["type"],
      media_type: url["mediaType"],
      name: data["name"],
      blurhash: nil,
      meta: %{},
      actor: actor,
      object_id: object_id
    })
    |> Repo.insert()
  end

  def get_by_id(nil), do: nil
  def get_by_id(id), do: Repo.get(Media, id)

  @spec authorize_access(Media.t(), User.t()) :: :ok | {:error, :forbidden}
  def authorize_access(%Media{actor: ap_id}, %User{ap_id: ap_id}), do: :ok

  def authorize_access(_media, %User{is_admin: is_admin?, is_moderator: is_moderator?})
      when true in [is_admin?, is_moderator?],
      do: :ok

  def authorize_access(_media, _user), do: {:error, :forbidden}

  def update(%Media{} = media, attrs \\ %{}) do
    media
    |> changeset(attrs)
    |> Repo.update()
  end

  def insert(%Media{} = media) do
    media
    |> changeset()
    |> Repo.insert()
  end

  def changeset(struct, params \\ %{}) do
    struct
    |> cast(params, [:href, :type, :media_type, :name, :blurhash, :meta, :actor, :object_id])
    |> validate_required([:href, :type, :media_type])
  end

  def to_object_form(%Media{} = media) do
    %{
      "id" => media.id,
      "url" => [
        %{
          "href" => media.href,
          "type" => media.type,
          "mediaType" => media.media_type
        }
      ],
      "name" => media.name,
      "type" => "Document",
      "blurhash" => media.blurhash,
      "mediaType" => media.media_type,
      "actor" => media.actor
    }
  end
end
