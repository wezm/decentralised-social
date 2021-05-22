defmodule Pleroma.User.Registration do
  alias Pleroma.Config
  alias Pleroma.Emails.AdminEmail
  alias Pleroma.Emails.Mailer
  alias Pleroma.Emails.UserEmail
  alias Pleroma.Repo
  alias Pleroma.User
  alias Pleroma.User.WelcomeChatMessage
  alias Pleroma.User.WelcomeEmail
  alias Pleroma.User.WelcomeMessage

  import Ecto.Changeset

  @doc "Inserts provided changeset, performs post-registration actions (confirmation email sending etc.)"
  def register(%Ecto.Changeset{} = changeset) do
    with {:ok, user} <- Repo.insert(changeset) do
      post_register_action(user)
    end
  end

  def post_register_action(%User{is_confirmed: false} = user) do
    with {:ok, _} <- maybe_send_confirmation_email(user) do
      {:ok, user}
    end
  end

  def post_register_action(%User{is_approved: false} = user) do
    with {:ok, _} <- send_user_approval_email(user),
         {:ok, _} <- send_admin_approval_emails(user) do
      {:ok, user}
    end
  end

  def post_register_action(%User{is_approved: true, is_confirmed: true} = user) do
    with {:ok, user} <- autofollow_users(user),
         {:ok, _} <- autofollowing_users(user),
         {:ok, user} <- User.set_cache(user),
         {:ok, _} <- maybe_send_registration_email(user),
         {:ok, _} <- maybe_send_welcome_email(user),
         {:ok, _} <- maybe_send_welcome_message(user),
         {:ok, _} <- maybe_send_welcome_chat_message(user) do
      {:ok, user}
    end
  end

  defp send_user_approval_email(user) do
    user
    |> UserEmail.approval_pending_email()
    |> Mailer.deliver_async()

    {:ok, :enqueued}
  end

  defp send_admin_approval_emails(user) do
    User.all_superusers()
    |> Enum.filter(fn user -> not is_nil(user.email) end)
    |> Enum.each(fn superuser ->
      superuser
      |> AdminEmail.new_unapproved_registration(user)
      |> Mailer.deliver_async()
    end)

    {:ok, :enqueued}
  end

  defp maybe_send_welcome_message(user) do
    if WelcomeMessage.enabled?() do
      WelcomeMessage.post_message(user)
      {:ok, :enqueued}
    else
      {:ok, :noop}
    end
  end

  defp maybe_send_welcome_chat_message(user) do
    if WelcomeChatMessage.enabled?() do
      WelcomeChatMessage.post_message(user)
      {:ok, :enqueued}
    else
      {:ok, :noop}
    end
  end

  defp maybe_send_welcome_email(%User{email: email} = user) when is_binary(email) do
    if WelcomeEmail.enabled?() do
      WelcomeEmail.send_email(user)
      {:ok, :enqueued}
    else
      {:ok, :noop}
    end
  end

  defp maybe_send_welcome_email(_), do: {:ok, :noop}

  @spec maybe_send_confirmation_email(User.t()) :: {:ok, :enqueued | :noop}
  def maybe_send_confirmation_email(%User{is_confirmed: false, email: email} = user)
      when is_binary(email) do
    if Config.get([:instance, :account_activation_required]) do
      send_confirmation_email(user)
      {:ok, :enqueued}
    else
      {:ok, :noop}
    end
  end

  def maybe_send_confirmation_email(_), do: {:ok, :noop}

  @spec send_confirmation_email(User.t()) :: User.t()
  def send_confirmation_email(%User{} = user) do
    user
    |> UserEmail.account_confirmation_email()
    |> Mailer.deliver_async()

    user
  end

  @spec maybe_send_registration_email(User.t()) :: {:ok, :enqueued | :noop}
  defp maybe_send_registration_email(%User{email: email} = user) when is_binary(email) do
    with false <- WelcomeEmail.enabled?(),
         false <- Config.get([:instance, :account_activation_required], false),
         false <- Config.get([:instance, :account_approval_required], false) do
      user
      |> UserEmail.successful_registration_email()
      |> Mailer.deliver_async()

      {:ok, :enqueued}
    else
      _ ->
        {:ok, :noop}
    end
  end

  defp maybe_send_registration_email(_), do: {:ok, :noop}

  def approve(users) when is_list(users) do
    Repo.transaction(fn ->
      Enum.map(users, fn user ->
        with {:ok, user} <- approve(user), do: user
      end)
    end)
  end

  def approve(%User{is_approved: false} = user) do
    with chg <- change(user, is_approved: true),
         {:ok, user} <- User.update_and_set_cache(chg) do
      post_register_action(user)
      {:ok, user}
    end
  end

  def approve(%User{} = user), do: {:ok, user}

  def confirm(users) when is_list(users) do
    Repo.transaction(fn ->
      Enum.map(users, fn user ->
        with {:ok, user} <- confirm(user), do: user
      end)
    end)
  end

  def confirm(%User{is_confirmed: false} = user) do
    with chg <- confirmation_changeset(user, set_confirmation: true),
         {:ok, user} <- User.update_and_set_cache(chg) do
      post_register_action(user)
      {:ok, user}
    end
  end

  def confirm(%User{} = user), do: {:ok, user}

  # Used to auto-register LDAP accounts which won't have a password hash stored locally
  def register_changeset_ldap(struct, params = %{password: password})
      when is_nil(password) do
    params = Map.put_new(params, :accepts_chat_messages, true)

    params =
      if Map.has_key?(params, :email) do
        Map.put_new(params, :email, params[:email])
      else
        params
      end

    struct
    |> cast(params, [
      :name,
      :nickname,
      :email,
      :accepts_chat_messages
    ])
    |> validate_required([:name, :nickname])
    |> unique_constraint(:nickname)
    |> validate_exclusion(:nickname, Config.get([User, :restricted_nicknames]))
    |> validate_format(:nickname, User.local_nickname_regex())
    |> put_ap_id()
    |> unique_constraint(:ap_id)
    |> put_following_and_follower_address()
  end

  def register_changeset(struct, params \\ %{}, opts \\ []) do
    bio_limit = Config.get([:instance, :user_bio_length], 5000)
    name_limit = Config.get([:instance, :user_name_length], 100)
    reason_limit = Config.get([:instance, :registration_reason_length], 500)
    params = Map.put_new(params, :accepts_chat_messages, true)

    confirmed? =
      if is_nil(opts[:confirmed]) do
        !Config.get([:instance, :account_activation_required])
      else
        opts[:confirmed]
      end

    approved? =
      if is_nil(opts[:approved]) do
        !Config.get([:instance, :account_approval_required])
      else
        opts[:approved]
      end

    struct
    |> confirmation_changeset(set_confirmation: confirmed?)
    |> approval_changeset(set_approval: approved?)
    |> cast(params, [
      :bio,
      :raw_bio,
      :email,
      :name,
      :nickname,
      :password,
      :password_confirmation,
      :emoji,
      :accepts_chat_messages,
      :registration_reason
    ])
    |> validate_required([:name, :nickname, :password, :password_confirmation])
    |> validate_confirmation(:password)
    |> unique_constraint(:email)
    |> validate_format(:email, User.email_regex())
    |> validate_change(:email, fn :email, email ->
      valid? =
        Config.get([User, :email_blacklist])
        |> Enum.all?(fn blacklisted_domain ->
          !String.ends_with?(email, ["@" <> blacklisted_domain, "." <> blacklisted_domain])
        end)

      if valid?, do: [], else: [email: "Invalid email"]
    end)
    |> unique_constraint(:nickname)
    |> validate_exclusion(:nickname, Config.get([User, :restricted_nicknames]))
    |> validate_format(:nickname, User.local_nickname_regex())
    |> validate_length(:bio, max: bio_limit)
    |> validate_length(:name, min: 1, max: name_limit)
    |> validate_length(:registration_reason, max: reason_limit)
    |> User.maybe_validate_required_email(opts[:external])
    |> User.put_password_hash()
    |> put_ap_id()
    |> unique_constraint(:ap_id)
    |> put_following_and_follower_address()
  end

  @spec confirmation_changeset(User.t(), keyword()) :: Changeset.t()
  def confirmation_changeset(user, set_confirmation: confirmed?) do
    params =
      if confirmed? do
        %{
          is_confirmed: true,
          confirmation_token: nil
        }
      else
        %{
          is_confirmed: false,
          confirmation_token: :crypto.strong_rand_bytes(32) |> Base.url_encode64()
        }
      end

    cast(user, params, [:is_confirmed, :confirmation_token])
  end

  @spec approval_changeset(User.t(), keyword()) :: Changeset.t()
  def approval_changeset(user, set_approval: approved?) do
    cast(user, %{is_approved: approved?}, [:is_approved])
  end

  @spec set_confirmation(User.t(), boolean()) :: {:ok, User.t()} | {:error, Changeset.t()}
  def set_confirmation(%User{} = user, bool) do
    user
    |> confirmation_changeset(set_confirmation: bool)
    |> User.update_and_set_cache()
  end

  defp put_ap_id(changeset) do
    ap_id = User.ap_id(%User{nickname: get_field(changeset, :nickname)})
    put_change(changeset, :ap_id, ap_id)
  end

  defp put_following_and_follower_address(changeset) do
    followers = User.ap_followers(%User{nickname: get_field(changeset, :nickname)})

    changeset
    |> put_change(:follower_address, followers)
  end

  defp autofollow_users(user) do
    candidates = Config.get([:instance, :autofollowed_nicknames])

    autofollowed_users =
      User.Query.build(%{nickname: candidates, local: true, is_active: true})
      |> Repo.all()

    User.follow_all(user, autofollowed_users)
  end

  defp autofollowing_users(user) do
    candidates = Config.get([:instance, :autofollowing_nicknames])

    User.Query.build(%{nickname: candidates, local: true, deactivated: false})
    |> Repo.all()
    |> Enum.each(&User.follow(&1, user, :follow_accept))

    {:ok, :success}
  end
end
