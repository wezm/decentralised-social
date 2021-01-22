defmodule Pleroma.Repo.Migrations.MoveFtsIndex do
  use Ecto.Migration

  def up do
    # Drop the old index
    drop_if_exists(
      index(:objects, ["(to_tsvector('english', data->>'content'))"],
        using: :gin,
        name: :objects_fts
      )
    )

    alter table(:activities) do
      add(:fts_content, :tsvector)
    end

    execute("CREATE FUNCTION activities_fts_update() RETURNS trigger AS $$
    declare
      content text := '';
    begin
      if new.data->>'type' = 'Create' then
        
        select objects.data->>'content'
        from objects
        into content
        where objects.data->>'id' = new.data->>'object';

        new.fts_content := to_tsvector('english', content);

      end if;

      return new;
    end
    $$ LANGUAGE plpgsql")

    create_if_not_exists(index(:activities, ["fts_content"], using: :gin, name: :activities_fts))
    execute("CREATE TRIGGER ts_vector_activities_update BEFORE INSERT ON activities
      FOR EACH ROW EXECUTE PROCEDURE activities_fts_update()
    ")
  end

  def down do
    execute("drop function if exists actitivies_fts_update()")
    execute("drop trigger if existis ts_vector_activities_update")
    drop_if_exists(index(:activities, ["fts_content"], using: :gin, name: :activities_fts))

    create_if_not_exists(
      index(:objects, ["(to_tsvector('english', data->>'content'))"],
        using: :gin,
        name: :objects_fts
      )
    )
  end
end
