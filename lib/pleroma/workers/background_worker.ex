# Pleroma: A lightweight social networking server
# Copyright © 2017-2021 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Workers.BackgroundWorker do
  alias Pleroma.User

  use Pleroma.Workers.WorkerHelper, queue: "background"

  @impl Oban.Worker

  def perform(%Job{args: %{"op" => "user_activation", "user_id" => user_id, "status" => status}}) do
    user = User.get_cached_by_id(user_id)
    User.perform(:set_activation_async, user, status)
  end

  def perform(%Job{args: %{"op" => "delete_user", "user_id" => user_id}}) do
    user = User.get_cached_by_id(user_id)
    User.perform(:delete, user)
  end

  def perform(%Job{args: %{"op" => "force_password_reset", "user_id" => user_id}}) do
    user = User.get_cached_by_id(user_id)
    User.perform(:force_password_reset, user)
  end

  def perform(%Job{args: %{"op" => op, "user_id" => user_id, "identifiers" => identifiers}})
      when op in ["blocks_import", "follow_import", "mutes_import"] do
    user = User.get_cached_by_id(user_id)
    {:ok, User.Import.perform(String.to_atom(op), user, identifiers)}
  end

  def perform(%Job{
        args: %{"op" => "move_following", "origin_id" => origin_id, "target_id" => target_id}
      }) do
    origin = User.get_cached_by_id(origin_id)
    target = User.get_cached_by_id(target_id)

    Pleroma.FollowingRelationship.move_following(origin, target)
  end

  def perform(%Job{args: %{"op" => "transaction_side_effects", "function" => encoded_function}}) do
    function =
      encoded_function
      |> Base.decode64!()
      |> :erlang.binary_to_term()

    maybe_execute_function_with_worker_info(function, true)
    :ok
  end

  @doc "Executes a function right away if not running in transaction. Otherwise enqueues it to be executed by BackgroundWorker after transaction commit. Intended for side effects that can not be rolled back. If the function has an arity of 1, the first argument will be a boolean indicating whether it is run by BackgroundWorker or not."
  @spec execute_or_enqueue_if_in_transaction((() -> any()) | (boolean() -> any())) ::
          {:ok, {:enqueued, Oban.Job.t()}}
          | {:error, {:enqueue, Oban.job_changeset()}}
          | {:error, {:enqueue, term()}}
          | {:ok, {:executed, term()}}
  def execute_or_enqueue_if_in_transaction(function) do
    if Pleroma.Repo.in_transaction?() and
         !Pleroma.Config.get([__MODULE__, :ignore_transaction_check], false) do
      encoded_function =
        function
        |> :erlang.term_to_binary()
        |> Base.encode64()

      case enqueue("transaction_side_effects", %{"function" => encoded_function}) do
        {:ok, job} -> {:ok, {:enqueued, job}}
        {:error, e} -> {:error, {:enqueue, e}}
      end
    else
      {:ok, {:executed, maybe_execute_function_with_worker_info(function, false)}}
    end
  end

  defp maybe_execute_function_with_worker_info(function, executed_by_worker) do
    if :erlang.fun_info(function)[:arity] == 1 do
      function.(executed_by_worker)
    else
      function.()
    end
  end
end
