defmodule Pleroma.Media do
  use Ecto.Schema

  import Ecto.Changeset

  alias Pleroma.Media
  alias Pleroma.Repo
  alias Pleroma.User

  @derive {Jason.Encoder,
           only: [:href, :type, :media_type, :name, :blurhash, :meta, :object_id, :user_id]}

  @type t() :: %__MODULE__{}

  schema "media" do
    field(:href, :string)
    field(:type, :string)
    field(:media_type, :string)
    field(:name, :string)
    field(:blurhash, :string)
    field(:meta, :map)

    belongs_to(:object, Pleroma.Object)
    belongs_to(:user, Pleroma.User, type: FlakeId.Ecto.CompatType)

    timestamps()
  end

  def create_from_object_data(%{"url" => [url]} = data, %{user: user} = opts) do
    object_id = get_in(opts, [:object, "id"])

    %Media{}
    |> changeset(%{
      href: url["href"],
      type: url["type"],
      media_type: url["mediaType"],
      name: data["name"],
      blurhash: nil,
      meta: %{},
      user_id: user.id,
      object_id: object_id
    })
    |> Repo.insert()
  end

  def get_by_id(nil), do: nil
  def get_by_id(id), do: Repo.get(Media, id)

  @spec authorize_access(Media.t(), User.t()) :: :ok | {:error, :forbidden}
  def authorize_access(%Media{user_id: user_id}, %User{id: user_id}), do: :ok
  def authorize_access(%Media{user_id: user_id}, %User{id: user_id}), do: {:error, :forbidden}

  def update(%Media{} = media, attrs \\ %{}) do
    media
    |> changeset(attrs)
    |> Repo.update()
  end

  def from_object(%Pleroma.Object{data: data}, %{user: user}) do
    %Media{href: data["href"], user_id: user.id}
  end

  def insert(%Media{} = media) do
    media
    |> changeset()
    |> Repo.insert()
  end

  def changeset(struct, params \\ %{}) do
    struct
    |> cast(params, [:href, :type, :media_type, :name, :blurhash, :meta, :user_id, :object_id])
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
      "actor" => User.get_by_id(media.user_id).ap_id
    }
  end
end
