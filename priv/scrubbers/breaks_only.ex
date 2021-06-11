defmodule Pleroma.HTML.Scrubber.BreaksOnly do
  @moduledoc """
  An HTML scrubbing policy which limits to linebreaks only.
  """

  require FastSanitize.Sanitizer.Meta
  alias FastSanitize.Sanitizer.Meta

  Meta.strip_comments()

  # linebreaks only
  Meta.allow_tag_with_these_attributes(:br, [])

  Meta.strip_everything_not_covered()
end
