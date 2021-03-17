# Pleroma: A lightweight social networking server
# Copyright © 2017-2021 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Installer.File do
  @callback write(Path.t(), iodata()) :: :ok | {:error, :file.posix()}
  @callback write(Path.t(), iodata(), [atom()]) :: :ok | {:error, :file.posix()}

  defdelegate write(path, content, modes \\ []), to: File
end
