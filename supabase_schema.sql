


SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;


CREATE EXTENSION IF NOT EXISTS "pg_cron" WITH SCHEMA "pg_catalog";






CREATE EXTENSION IF NOT EXISTS "pg_net" WITH SCHEMA "extensions";






COMMENT ON SCHEMA "public" IS 'standard public schema';



CREATE EXTENSION IF NOT EXISTS "pg_stat_statements" WITH SCHEMA "extensions";






CREATE EXTENSION IF NOT EXISTS "pgcrypto" WITH SCHEMA "extensions";






CREATE EXTENSION IF NOT EXISTS "supabase_vault" WITH SCHEMA "vault";






CREATE EXTENSION IF NOT EXISTS "uuid-ossp" WITH SCHEMA "extensions";






CREATE OR REPLACE FUNCTION "public"."add_feature_suggestion_update"("p_feature_id" "uuid", "p_body" "text") RETURNS "uuid"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_body text := trim(coalesce(p_body, ''));
  v_id uuid;
begin
  if not public.is_chiplux_developer() then
    raise exception 'Developer access required.';
  end if;

  if char_length(v_body) < 1 or char_length(v_body) > 2000 then
    raise exception 'Developer update must be 1 to 2000 characters.';
  end if;

  if not exists (
    select 1
    from public.feature_suggestions f
    where f.id = p_feature_id
      and f.status <> 'pending'
  ) then
    raise exception 'Publish this feature suggestion before adding an update.';
  end if;

  insert into public.feature_suggestion_comments(
    feature_id,
    user_id,
    body
  )
  values (
    p_feature_id,
    auth.uid(),
    v_body
  )
  returning id into v_id;

  update public.feature_suggestions
  set updated_at = now()
  where id = p_feature_id;

  return v_id;
end;
$$;


ALTER FUNCTION "public"."add_feature_suggestion_update"("p_feature_id" "uuid", "p_body" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."broadcast_chiplux_update"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
begin

  insert into public.notifications (
    recipient_user_id,
    type,
    title,
    body,
    chiplux_update_id,
    is_read,
    created_at
  )

  select
    p.id,
    'chiplux_update',
    new.title,
    new.body,
    new.id,
    false,
    now()

  from public.profiles p

  where
    coalesce(
      p.notify_chiplux_updates,
      true
    ) = true

  on conflict do nothing;


  return new;

end;
$$;


ALTER FUNCTION "public"."broadcast_chiplux_update"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."can_access_media_comments"("p_media_type" "text", "p_tmdb_id" bigint, "p_season_number" integer DEFAULT NULL::integer, "p_episode_number" integer DEFAULT NULL::integer) RETURNS boolean
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
  select
    auth.uid() is not null
    and
    (
      -- =========================================
      -- MOVIE
      -- =========================================
      (
        p_media_type = 'movie'
        and
        (
          exists (
            select 1
            from public.community_activity ca
            where ca.user_id = auth.uid()
              and ca.activity_type = 'movie_watched'
              and ca.media_type = 'movie'
              and ca.tmdb_id = p_tmdb_id
          )

          or

          exists (
            select 1
            from public.library_items li
            where li.user_id = auth.uid()
              and li.media_type = 'movie'
              and li.tmdb_id = p_tmdb_id
              and li.status = 'completed'
          )
        )
      )

      or

      -- =========================================
      -- TV SHOW
      -- =========================================
      (
        p_media_type = 'tv'
        and
        (
          exists (
            select 1
            from public.community_activity ca
            where ca.user_id = auth.uid()
              and ca.activity_type = 'tv_watched'
              and ca.media_type = 'tv'
              and ca.tmdb_id = p_tmdb_id
          )

          or

          exists (
            select 1
            from public.library_items li
            where li.user_id = auth.uid()
              and li.media_type = 'tv'
              and li.tmdb_id = p_tmdb_id
              and li.status = 'completed'
          )
        )
      )

      or

      -- =========================================
      -- EPISODE
      -- =========================================
      (
        p_media_type = 'episode'
        and
        p_season_number is not null
        and
        p_episode_number is not null
        and
        (
          exists (
            select 1
            from public.community_activity ca
            where ca.user_id = auth.uid()
              and ca.activity_type = 'episode_watched'
              and ca.media_type = 'tv'
              and ca.tmdb_id = p_tmdb_id
              and ca.season_number = p_season_number
              and ca.episode_number = p_episode_number
          )

          or

          exists (
            select 1
            from public.watched_episodes we
            where we.user_id = auth.uid()
              and we.show_id = p_tmdb_id
              and we.season_number = p_season_number
              and we.episode_number = p_episode_number
          )
        )
      )
    );
$$;


ALTER FUNCTION "public"."can_access_media_comments"("p_media_type" "text", "p_tmdb_id" bigint, "p_season_number" integer, "p_episode_number" integer) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."can_follow_user"("p_target_user_id" "uuid") RETURNS boolean
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
  select public.can_user_follow(auth.uid(), p_target_user_id);
$$;


ALTER FUNCTION "public"."can_follow_user"("p_target_user_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."can_user_follow"("p_follower_user_id" "uuid", "p_target_user_id" "uuid") RETURNS boolean
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_policy text;
begin
  if p_follower_user_id is null or p_target_user_id is null then
    return false;
  end if;

  if p_follower_user_id = p_target_user_id then
    return false;
  end if;

  if public.is_blocked_between(p_follower_user_id, p_target_user_id) then
    return false;
  end if;

  select privacy_follow_permission
  into v_policy
  from public.profiles
  where id = p_target_user_id;

  if v_policy is null then
    return false;
  end if;

  if v_policy = 'everyone' then
    return true;
  end if;

  if v_policy = 'people_i_follow' then
    return exists (
      select 1
      from public.follows f
      where f.follower_id = p_target_user_id
        and f.following_id = p_follower_user_id
    );
  end if;

  return false;
end;
$$;


ALTER FUNCTION "public"."can_user_follow"("p_follower_user_id" "uuid", "p_target_user_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."can_view_profile_details"("p_target_user_id" "uuid") RETURNS boolean
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_viewer uuid := auth.uid();
  v_visibility text;
begin
  if v_viewer is null then
    return false;
  end if;

  if v_viewer = p_target_user_id then
    return true;
  end if;

  if public.is_blocked_between(v_viewer, p_target_user_id) then
    return false;
  end if;

  select privacy_profile_visibility
  into v_visibility
  from public.profiles
  where id = p_target_user_id;

  if v_visibility is null then
    return false;
  end if;

  if v_visibility = 'everyone' then
    return true;
  end if;

  if v_visibility = 'followers' then
    return exists (
      select 1
      from public.follows f
      where f.follower_id = v_viewer
        and f.following_id = p_target_user_id
    );
  end if;

  return false;
end;
$$;


ALTER FUNCTION "public"."can_view_profile_details"("p_target_user_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."can_view_public_media_list"("p_target_user_id" "uuid", "p_require_ratings" boolean DEFAULT false) RETURNS boolean
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_watch boolean;
  v_ratings boolean;
begin
  if not public.can_view_profile_details(p_target_user_id) then
    return false;
  end if;

  select
    privacy_show_watch_stats,
    privacy_show_rating_stats
  into
    v_watch,
    v_ratings
  from public.profiles
  where id = p_target_user_id;

  if not coalesce(v_watch, true) then
    return false;
  end if;

  if coalesce(p_require_ratings, false)
     and not coalesce(v_ratings, true) then
    return false;
  end if;

  return true;
end;
$$;


ALTER FUNCTION "public"."can_view_public_media_list"("p_target_user_id" "uuid", "p_require_ratings" boolean) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."check_username_availability"("p_username" "text") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $_$
declare
  base_username text;
  is_available boolean;

  suggestions text[] :=
    array[]::text[];

  candidate text;
  suffix text;

  attempt integer := 0;
begin
  base_username :=
    lower(
      trim(
        coalesce(
          p_username,
          ''
        )
      )
    );

  if base_username
      !~ '^[a-z0-9_]{3,20}$' then
    return jsonb_build_object(
      'valid',
      false,

      'available',
      false,

      'username',
      base_username,

      'message',
      'Use 3–20 letters, numbers, or underscores.',

      'suggestions',
      '[]'::jsonb
    );
  end if;

  select not exists (
    select 1
    from public.username_claims
    where username_key =
      base_username
  )
  into is_available;

  if is_available then
    return jsonb_build_object(
      'valid',
      true,

      'available',
      true,

      'username',
      base_username,

      'message',
      'Username is available.',

      'suggestions',
      '[]'::jsonb
    );
  end if;

  while
    coalesce(
      array_length(
        suggestions,
        1
      ),
      0
    ) < 3
    and attempt < 100
  loop
    attempt :=
      attempt + 1;

    suffix :=
      (
        floor(
          random() * 900
        )::integer
        + 100
      )::text;

    candidate :=
      left(
        base_username,
        greatest(
          1,
          20 - length(suffix)
        )
      )
      || suffix;

    if not exists (
      select 1
      from public.username_claims
      where username_key =
        candidate
    )
    and not (
      candidate =
      any(suggestions)
    ) then
      suggestions :=
        array_append(
          suggestions,
          candidate
        );
    end if;
  end loop;

  return jsonb_build_object(
    'valid',
    true,

    'available',
    false,

    'username',
    base_username,

    'message',
    'Username is already taken.',

    'suggestions',
    to_jsonb(suggestions)
  );
end;
$_$;


ALTER FUNCTION "public"."check_username_availability"("p_username" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."claim_signup_username"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $_$
declare
  chosen_username text;
begin
  chosen_username :=
    lower(
      trim(
        coalesce(
          new.raw_user_meta_data ->> 'username',
          ''
        )
      )
    );

  if chosen_username = '' then
    return new;
  end if;

  if chosen_username
      !~ '^[a-z0-9_]{3,20}$' then
    raise exception
      'Invalid username.';
  end if;

  insert into public.username_claims (
    user_id,
    username
  )
  values (
    new.id,
    chosen_username
  );

  return new;
end;
$_$;


ALTER FUNCTION "public"."claim_signup_username"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."cleanup_after_block"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
begin
  delete from public.follows
  where (follower_id = new.blocker_id and following_id = new.blocked_id)
     or (follower_id = new.blocked_id and following_id = new.blocker_id);

  delete from public.notifications
  where (recipient_user_id = new.blocker_id and actor_user_id = new.blocked_id)
     or (recipient_user_id = new.blocked_id and actor_user_id = new.blocker_id);

  return new;
end;
$$;


ALTER FUNCTION "public"."cleanup_after_block"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."count_music_album_comment_reports"("p_comment_id" "uuid", "p_report_type" "text") RETURNS integer
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  target_album_id text;
  result_count integer;
begin
  if auth.uid() is null then
    return 0;
  end if;

  select album_id
  into target_album_id
  from public.music_album_comments
  where id = p_comment_id;

  if target_album_id is null then
    return 0;
  end if;

  if not exists (
    select 1
    from public.music_user_data mud
    where mud.user_id = auth.uid()
      and mud.entity_type = 'album'
      and mud.entity_id = target_album_id
      and mud.is_listened = true
  ) then
    return 0;
  end if;

  select count(*)::integer
  into result_count
  from public.music_album_comment_reports
  where comment_id = p_comment_id
    and report_type = p_report_type;

  return coalesce(result_count, 0);
end;
$$;


ALTER FUNCTION "public"."count_music_album_comment_reports"("p_comment_id" "uuid", "p_report_type" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."count_visible_media_comments"("p_media_type" "text", "p_tmdb_id" integer, "p_season_number" integer DEFAULT NULL::integer, "p_episode_number" integer DEFAULT NULL::integer) RETURNS integer
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
  select count(*)::integer
  from public.media_comments mc
  where public.can_access_media_comments(
          p_media_type,
          p_tmdb_id,
          p_season_number,
          p_episode_number
        ) = true
    and mc.media_type = p_media_type
    and mc.tmdb_id = p_tmdb_id
    and (p_media_type <> 'episode' or (mc.season_number = p_season_number and mc.episode_number = p_episode_number))
    and not exists (
      select 1 from public.user_blocks ub
      where (ub.blocker_id = auth.uid() and ub.blocked_id = mc.user_id)
         or (ub.blocker_id = mc.user_id and ub.blocked_id = auth.uid())
    );
$$;


ALTER FUNCTION "public"."count_visible_media_comments"("p_media_type" "text", "p_tmdb_id" integer, "p_season_number" integer, "p_episode_number" integer) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."create_achievement_notification"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  wants_notification boolean;
begin
  -- Only achievement activity.
  if new.activity_type <> 'achievement_unlocked' then
    return new;
  end if;


  -- Need an actual achievement.
  if new.achievement_id is null then
    return new;
  end if;


  -- Check user's notification preference.
  select coalesce(
    notify_achievements,
    true
  )
  into wants_notification
  from public.profiles
  where id = new.user_id;


  if wants_notification = false then
    return new;
  end if;


  insert into public.notifications (
    recipient_user_id,

    type,

    title,
    body,

    achievement_id,
    achievement_title
  )
  values (
    new.user_id,

    'achievement',

    'Achievement unlocked',

    'You unlocked '
      || coalesce(
        new.achievement_title,
        'a new achievement'
      )
      || '!',

    new.achievement_id,
    new.achievement_title
  )
  on conflict do nothing;


  return new;
end;
$$;


ALTER FUNCTION "public"."create_achievement_notification"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."create_comment_like_milestone_notification"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  comment_owner uuid;

  comment_media_type text;
  comment_tmdb_id bigint;

  comment_season_number integer;
  comment_episode_number integer;

  like_count integer;

  wants_notification boolean;
begin
  -- -----------------------------------------
  -- Find the comment and its owner.
  -- -----------------------------------------
  select
    user_id,
    media_type,
    tmdb_id,
    season_number,
    episode_number
  into
    comment_owner,
    comment_media_type,
    comment_tmdb_id,
    comment_season_number,
    comment_episode_number
  from public.media_comments
  where id = new.comment_id
  limit 1;


  if comment_owner is null then
    return new;
  end if;


  -- -----------------------------------------
  -- Count current likes.
  -- -----------------------------------------
  select count(*)
  into like_count
  from public.comment_likes
  where comment_id = new.comment_id;


  -- Only notify at:
  -- 100, 200, 300, 400...
  if like_count < 100
     or mod(like_count, 100) <> 0 then
    return new;
  end if;


  -- -----------------------------------------
  -- Check notification preference.
  -- -----------------------------------------
  select coalesce(
    notify_comment_like_milestones,
    true
  )
  into wants_notification
  from public.profiles
  where id = comment_owner;


  if wants_notification = false then
    return new;
  end if;


  -- -----------------------------------------
  -- Create milestone notification.
  -- -----------------------------------------
  insert into public.notifications (
    recipient_user_id,
    actor_user_id,

    type,

    title,
    body,

    media_type,
    tmdb_id,

    season_number,
    episode_number,

    comment_id,

    milestone_value
  )
  values (
    comment_owner,
    new.user_id,

    'comment_like_milestone',

    'Comment milestone',

    'Your comment reached '
      || like_count
      || ' likes!',

    comment_media_type,
    comment_tmdb_id,

    comment_season_number,
    comment_episode_number,

    new.comment_id::text,

    like_count
  )
  on conflict do nothing;


  return new;
end;
$$;


ALTER FUNCTION "public"."create_comment_like_milestone_notification"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."create_comment_reply_notification"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  parent_owner uuid;
  wants_notification boolean;
  actor_name text;
begin
  -- Only replies.
  if new.parent_comment_id is null then
    return new;
  end if;

  -- Find owner of the comment being replied to.
  select user_id
  into parent_owner
  from public.media_comments
  where id::text = new.parent_comment_id::text
  limit 1;

  if parent_owner is null then
    return new;
  end if;

  -- Never notify somebody about
  -- replying to their own comment.
  if parent_owner = new.user_id then
    return new;
  end if;

  -- Check recipient's preference.
  select coalesce(
    notify_comments_replies,
    true
  )
  into wants_notification
  from public.profiles
  where id = parent_owner;

  if wants_notification = false then
    return new;
  end if;

  -- Name of the person who replied.
  select coalesce(
    nullif(display_name, ''),
    nullif(username, ''),
    'Someone'
  )
  into actor_name
  from public.profiles
  where id = new.user_id;

  insert into public.notifications (
    recipient_user_id,
    actor_user_id,
    type,
    title,
    body,
    media_type,
    tmdb_id,
    season_number,
    episode_number,
    comment_id,
    parent_comment_id
  )
  values (
    parent_owner,
    new.user_id,
    'comment_reply',
    'New reply',
    coalesce(actor_name, 'Someone')
      || ' replied to your comment.',
    new.media_type,
    new.tmdb_id,
    new.season_number,
    new.episode_number,
    new.id::text,
    new.parent_comment_id::text
  )
  on conflict do nothing;

  return new;
end;
$$;


ALTER FUNCTION "public"."create_comment_reply_notification"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."create_new_follower_notification"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  wants_notification boolean;
  actor_name text;
begin
  -- Safety: never notify for self-follow.
  if new.follower_id = new.following_id then
    return new;
  end if;

  -- Check recipient preference.
  select coalesce(
    notify_new_followers,
    true
  )
  into wants_notification
  from public.profiles
  where id = new.following_id;

  if wants_notification = false then
    return new;
  end if;

  -- Get follower name.
  select coalesce(
    nullif(display_name, ''),
    nullif(username, ''),
    'Someone'
  )
  into actor_name
  from public.profiles
  where id = new.follower_id;

  insert into public.notifications (
    recipient_user_id,
    actor_user_id,
    type,
    title,
    body
  )
  values (
    new.following_id,
    new.follower_id,
    'new_follower',
    'New follower',
    coalesce(actor_name, 'Someone')
      || ' started following you.'
  );

  return new;
end;
$$;


ALTER FUNCTION "public"."create_new_follower_notification"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."delete_my_account"() RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public', 'auth'
    AS $$
declare v_user_id uuid := auth.uid();
begin
  if v_user_id is null then raise exception 'Not authenticated'; end if;
  delete from public.comment_reports where reporter_id = v_user_id;
  delete from public.user_reports where reporter_id = v_user_id or reported_user_id = v_user_id;
  delete from public.user_blocks where blocker_id = v_user_id or blocked_id = v_user_id;
  delete from public.comment_likes where user_id = v_user_id;
  delete from public.media_comments where user_id = v_user_id;
  delete from public.notifications where recipient_user_id = v_user_id or actor_user_id = v_user_id;
  delete from public.community_activity where user_id = v_user_id;
  delete from public.follows where follower_id = v_user_id or following_id = v_user_id;
  delete from public.episode_ratings where user_id = v_user_id;
  delete from public.media_user_data where user_id = v_user_id;
  delete from public.watched_episodes where user_id = v_user_id;
  delete from public.library_items where user_id = v_user_id;
  delete from public.bug_reports where user_id = v_user_id;
  delete from public.profiles where id = v_user_id;
  delete from auth.users where id = v_user_id;
end;
$$;


ALTER FUNCTION "public"."delete_my_account"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."enforce_comment_like_privacy"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_comment_author uuid;
begin
  select user_id
  into v_comment_author
  from public.media_comments
  where id = new.comment_id;

  if v_comment_author is not null
     and new.user_id <> v_comment_author
     and public.is_blocked_between(new.user_id, v_comment_author) then
    raise exception 'You cannot interact with this user.';
  end if;

  return new;
end;
$$;


ALTER FUNCTION "public"."enforce_comment_like_privacy"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."enforce_comment_reply_privacy"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_parent_author uuid;
  v_allow_replies boolean;
begin
  if new.parent_comment_id is null then
    return new;
  end if;

  select user_id
  into v_parent_author
  from public.media_comments
  where id = new.parent_comment_id;

  if v_parent_author is null then
    return new;
  end if;

  if new.user_id <> v_parent_author
     and public.is_blocked_between(new.user_id, v_parent_author) then
    raise exception 'You cannot reply to this user.';
  end if;

  select privacy_allow_comment_replies
  into v_allow_replies
  from public.profiles
  where id = v_parent_author;

  if new.user_id <> v_parent_author
     and coalesce(v_allow_replies, true) = false then
    raise exception 'This user has disabled replies to their comments.';
  end if;

  return new;
end;
$$;


ALTER FUNCTION "public"."enforce_comment_reply_privacy"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."enforce_follow_privacy"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
begin
  if auth.uid() is not null and new.follower_id <> auth.uid() then
    raise exception 'You cannot create a follow for another user.';
  end if;

  if not public.can_user_follow(new.follower_id, new.following_id) then
    raise exception 'This user is not accepting follows from you.';
  end if;

  return new;
end;
$$;


ALTER FUNCTION "public"."enforce_follow_privacy"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_chiplux_average_rating"("p_media_type" "text", "p_tmdb_id" bigint, "p_season_number" integer DEFAULT NULL::integer, "p_episode_number" integer DEFAULT NULL::integer) RETURNS TABLE("average_rating" numeric, "rating_count" bigint)
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
begin
  if p_media_type in ('movie', 'tv') then

    return query
    select
      round(
        avg(m.rating::numeric) / 2.0,
        2
      ) as average_rating,
      count(*)::bigint as rating_count
    from public.media_user_data m
    where m.tmdb_id = p_tmdb_id
      and m.media_type = p_media_type
      and m.rating is not null;

  elsif p_media_type = 'episode' then

    if p_season_number is null
       or p_episode_number is null then
      raise exception
        'Season and episode are required';
    end if;

    return query
    select
      round(
        avg(e.rating::numeric) / 2.0,
        2
      ) as average_rating,
      count(*)::bigint as rating_count
    from public.episode_ratings e
    where e.show_id = p_tmdb_id
      and e.season_number =
          p_season_number
      and e.episode_number =
          p_episode_number
      and e.rating is not null;

  else
    raise exception
      'Invalid media type: %',
      p_media_type;
  end if;
end;
$$;


ALTER FUNCTION "public"."get_chiplux_average_rating"("p_media_type" "text", "p_tmdb_id" bigint, "p_season_number" integer, "p_episode_number" integer) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_developer_profile_id"() RETURNS "uuid"
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
  select p.id
  from public.profiles p
  where p.is_developer = true
  order by p.id
  limit 1;
$$;


ALTER FUNCTION "public"."get_developer_profile_id"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_feature_suggestion_submission_status"() RETURNS TABLE("allowed" boolean, "last_submitted_at" timestamp with time zone, "next_allowed_at" timestamp with time zone)
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_user_id uuid := auth.uid();
  v_last timestamptz;
begin
  if v_user_id is null then
    raise exception 'You must be signed in.';
  end if;

  select s.last_submitted_at
    into v_last
  from public.feature_suggestion_submission_state s
  where s.user_id = v_user_id;

  return query
  select
    v_last is null or now() >= v_last + interval '30 days',
    v_last,
    case
      when v_last is null then null
      else v_last + interval '30 days'
    end;
end;
$$;


ALTER FUNCTION "public"."get_feature_suggestion_submission_status"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_public_completed_tv_shows"("p_user_id" "uuid", "p_sort_rated" boolean) RETURNS TABLE("tmdb_id" bigint, "title" "text", "poster_path" "text", "year" "text", "added_at" bigint, "rating" integer)
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
  select
    li.tmdb_id::bigint,
    li.title::text,
    li.poster_path::text,
    li.year::text,
    li.added_at::bigint,
    mud.rating::integer as rating

  from public.library_items li

  left join public.media_user_data mud
    on mud.user_id = li.user_id
   and mud.tmdb_id = li.tmdb_id
   and mud.media_type = 'tv'

  left join lateral (
    select count(*) as rated_episode_count
    from public.episode_ratings er
    where er.user_id = li.user_id
      and er.show_id = li.tmdb_id
      and er.season_number > 0
      and er.rating is not null
  ) episode_stats on true

  where li.user_id = p_user_id
    and li.media_type = 'tv'
    and li.status = 'completed'

  order by
    case
      when p_sort_rated
       and mud.rating is not null
       and li.total_episodes > 0
       and episode_stats.rated_episode_count >= li.total_episodes
      then 1
      else 0
    end desc,

    li.added_at desc nulls last;
$$;


ALTER FUNCTION "public"."get_public_completed_tv_shows"("p_user_id" "uuid", "p_sort_rated" boolean) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_public_profile"("p_user_id" "uuid") RETURNS "jsonb"
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  p public.profiles%rowtype;
  v_can_view boolean;
  v_stats jsonb;
begin
  if auth.uid() is null then
    return null;
  end if;

  if public.is_blocked_between(auth.uid(), p_user_id) then
    return null;
  end if;

  select * into p
  from public.profiles
  where id = p_user_id;

  if not found then
    return null;
  end if;

  v_can_view := public.can_view_profile_details(p_user_id);
  v_stats := coalesce(p.public_stats::jsonb, '{}'::jsonb);

  if v_can_view then
    if not p.privacy_show_watch_stats then
      v_stats := v_stats
        - 'total_watched_minutes'
        - 'movie_watched_minutes'
        - 'episode_watched_minutes'
        - 'viewer_title'
        - 'movies_watched'
        - 'episodes_watched'
        - 'tv_shows_completed';
    end if;

    if not p.privacy_show_genre_stats then
      v_stats := v_stats - 'genre_runtime';
    end if;

    if not p.privacy_show_rating_stats then
      v_stats := v_stats
        - 'movie_ratings'
        - 'tv_ratings'
        - 'title_ratings'
        - 'critic_level'
        - 'critic_title'
        - 'critic_xp'
        - 'critic_required_xp'
        - 'total_ratings'
        - 'episode_ratings'
        - 'average_stars'
        - 'title_coverage'
        - 'episode_coverage'
        - 'rating_distribution';
    end if;

    if not p.privacy_show_profile_achievements then
      v_stats := v_stats - 'unlocked_achievement_ids';
    end if;

    if not p.privacy_show_connections then
      v_stats := v_stats
        - 'followers_count'
        - 'followers_peak_count';
    end if;
  else
    v_stats := '{}'::jsonb;
  end if;

  return jsonb_build_object(
    'id', p.id,
    'display_name', p.display_name,
    'username', p.username,
    'avatar_url', p.avatar_url,
    'is_developer', p.is_developer,
    'can_view_details', v_can_view,
    'profile_visibility', p.privacy_profile_visibility,
    'can_follow', public.can_user_follow(auth.uid(), p.id),
    'show_connections', p.privacy_show_connections and v_can_view,
    'show_profile_achievements', p.privacy_show_profile_achievements and v_can_view,
    'show_watch_stats', p.privacy_show_watch_stats and v_can_view,
    'show_genre_stats', p.privacy_show_genre_stats and v_can_view,
    'show_rating_stats', p.privacy_show_rating_stats and v_can_view,

    'banner_path', case when v_can_view then p.banner_path else null end,
    'public_stats', v_stats,
    'pinned_achievement_id',
      case
        when v_can_view and p.privacy_show_profile_achievements
        then p.pinned_achievement_id
        else null
      end,
    'display_name_frame_id', case when v_can_view then p.display_name_frame_id else null end,
    'avatar_frame_id', case when v_can_view then p.avatar_frame_id else null end,
    'profile_title_id', case when v_can_view then p.profile_title_id else null end,
    'profile_page_frame_id', case when v_can_view then p.profile_page_frame_id else null end,
    'achievement_cosmetics',
      case
        when v_can_view and p.privacy_show_profile_achievements
        then p.achievement_cosmetics
        else '{}'::jsonb
      end
  );
end;
$$;


ALTER FUNCTION "public"."get_public_profile"("p_user_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_public_watched_movies"("p_user_id" "uuid", "p_sort_rated" boolean) RETURNS TABLE("tmdb_id" bigint, "title" "text", "poster_path" "text", "year" "text", "added_at" bigint, "rating" integer)
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
  select
    li.tmdb_id::bigint,
    li.title::text,
    li.poster_path::text,
    li.year::text,
    li.added_at::bigint,
    mud.rating::integer as rating

  from public.library_items li

  left join public.media_user_data mud
    on mud.user_id = li.user_id
   and mud.tmdb_id = li.tmdb_id
   and mud.media_type = 'movie'

  where li.user_id = p_user_id
    and li.media_type = 'movie'
    and li.status = 'completed'

  order by
    case
      when p_sort_rated
       and mud.rating is not null
      then 1
      else 0
    end desc,

    li.added_at desc nulls last;
$$;


ALTER FUNCTION "public"."get_public_watched_movies"("p_user_id" "uuid", "p_sort_rated" boolean) OWNER TO "postgres";

SET default_tablespace = '';

SET default_table_access_method = "heap";


CREATE TABLE IF NOT EXISTS "public"."community_activity" (
    "id" bigint NOT NULL,
    "user_id" "uuid" NOT NULL,
    "activity_type" "text" NOT NULL,
    "media_type" "text",
    "tmdb_id" integer,
    "media_title" "text",
    "season_number" integer,
    "episode_number" integer,
    "episode_title" "text",
    "rating_stars" smallint,
    "achievement_id" "text",
    "achievement_title" "text",
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "external_id" "text",
    "parent_external_id" "text",
    "external_artist_id" "text",
    "external_artist_name" "text",
    "external_parent_title" "text",
    "external_year" "text",
    "external_genres" "text"[] DEFAULT '{}'::"text"[] NOT NULL,
    CONSTRAINT "community_activity_media_type_check" CHECK ((("media_type" IS NULL) OR ("media_type" = ANY (ARRAY['movie'::"text", 'tv'::"text", 'music_album'::"text", 'music_track'::"text"])))),
    CONSTRAINT "valid_activity_type" CHECK (("activity_type" = ANY (ARRAY['episode_watched'::"text", 'season_watched'::"text", 'movie_watched'::"text", 'tv_watched'::"text", 'started_watching'::"text", 'rated'::"text", 'plan_to_watch'::"text", 'dropped'::"text", 'favorite'::"text", 'achievement_unlocked'::"text"]))),
    CONSTRAINT "valid_rating" CHECK ((("rating_stars" IS NULL) OR (("rating_stars" >= 1) AND ("rating_stars" <= 5))))
);


ALTER TABLE "public"."community_activity" OWNER TO "postgres";


COMMENT ON COLUMN "public"."community_activity"."external_id" IS 'External non-TMDB entity ID, currently MusicBrainz album release-group or recording ID.';



COMMENT ON COLUMN "public"."community_activity"."parent_external_id" IS 'Parent external entity ID, currently the MusicBrainz release-group ID for a song.';



CREATE OR REPLACE FUNCTION "public"."get_visible_community_activity"("p_limit" integer DEFAULT 100) RETURNS SETOF "public"."community_activity"
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
  select ca.*
  from public.community_activity ca
  join public.profiles p on p.id = ca.user_id
  where auth.uid() is not null
    and ca.user_id <> auth.uid()
    and exists (
      select 1
      from public.follows f
      where f.follower_id = auth.uid()
        and f.following_id = ca.user_id
    )
    and not public.is_blocked_between(auth.uid(), ca.user_id)
    and p.privacy_show_activity = true
    and p.privacy_profile_visibility <> 'private'
    and (
      ca.activity_type = 'rated'
      and p.privacy_show_ratings_activity = true
      or ca.activity_type = 'achievement_unlocked'
      and p.privacy_show_achievements_activity = true
      or ca.activity_type not in ('rated', 'achievement_unlocked')
      and p.privacy_show_watch_activity = true
    )
  order by ca.created_at desc
  limit greatest(1, least(coalesce(p_limit, 100), 250));
$$;


ALTER FUNCTION "public"."get_visible_community_activity"("p_limit" integer) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_visible_followers"("p_user_id" "uuid") RETURNS TABLE("id" "uuid", "display_name" "text", "username" "text", "avatar_url" "text", "followed_at" timestamp with time zone)
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_allowed boolean;
begin
  select (
    auth.uid() = p_user_id
    or (
      public.can_view_profile_details(p_user_id)
      and coalesce(p.privacy_show_connections, true)
    )
  )
  into v_allowed
  from public.profiles p
  where p.id = p_user_id;

  if not coalesce(v_allowed, false) then
    return;
  end if;

  return query
  select
    p.id,
    p.display_name,
    p.username,
    p.avatar_url,
    f.created_at
  from public.follows f
  join public.profiles p on p.id = f.follower_id
  where f.following_id = p_user_id
    and not public.is_blocked_between(auth.uid(), p.id)
  order by f.created_at desc;
end;
$$;


ALTER FUNCTION "public"."get_visible_followers"("p_user_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_visible_media_comments"("p_media_type" "text", "p_tmdb_id" integer, "p_season_number" integer DEFAULT NULL::integer, "p_episode_number" integer DEFAULT NULL::integer) RETURNS SETOF "jsonb"
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
  select to_jsonb(mc) || jsonb_build_object(
    'spoiler_hidden',
    (
      select count(*) >= 3
      from public.comment_reports cr
      where cr.comment_id = mc.id::text
        and cr.report_type = 'spoiler'
        and cr.status in ('open','reviewing')
    )
  )
  from public.media_comments mc
  where public.can_access_media_comments(
          p_media_type,
          p_tmdb_id,
          p_season_number,
          p_episode_number
        ) = true
    and mc.media_type = p_media_type
    and mc.tmdb_id = p_tmdb_id
    and (p_media_type <> 'episode' or (mc.season_number = p_season_number and mc.episode_number = p_episode_number))
    and not exists (
      select 1 from public.user_blocks ub
      where (ub.blocker_id = auth.uid() and ub.blocked_id = mc.user_id)
         or (ub.blocker_id = mc.user_id and ub.blocked_id = auth.uid())
    )
  order by mc.created_at asc;
$$;


ALTER FUNCTION "public"."get_visible_media_comments"("p_media_type" "text", "p_tmdb_id" integer, "p_season_number" integer, "p_episode_number" integer) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."handle_new_user"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
begin
  insert into public.profiles (id, display_name)
  values (
    new.id,
    coalesce(
      new.raw_user_meta_data ->> 'display_name',
      split_part(new.email, '@', 1)
    )
  )
  on conflict (id) do nothing;

  return new;
end;
$$;


ALTER FUNCTION "public"."handle_new_user"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."ignore_feature_suggestion"("p_feature_id" "uuid") RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
begin
  if not public.is_chiplux_developer() then
    raise exception 'Developer access required.';
  end if;

  delete from public.feature_suggestions
  where id = p_feature_id
    and status = 'pending';

  if not found then
    raise exception 'Only pending suggestions can be ignored.';
  end if;
end;
$$;


ALTER FUNCTION "public"."ignore_feature_suggestion"("p_feature_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."is_blocked_between"("p_user_a" "uuid", "p_user_b" "uuid") RETURNS boolean
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
  select exists (
    select 1
    from public.user_blocks b
    where (b.blocker_id = p_user_a and b.blocked_id = p_user_b)
       or (b.blocker_id = p_user_b and b.blocked_id = p_user_a)
  );
$$;


ALTER FUNCTION "public"."is_blocked_between"("p_user_a" "uuid", "p_user_b" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."is_chiplux_developer"() RETURNS boolean
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
  select exists (
    select 1
    from public.profiles p
    where p.id = auth.uid()
      and p.is_developer = true
  );
$$;


ALTER FUNCTION "public"."is_chiplux_developer"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."is_current_user_developer"() RETURNS boolean
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
  select coalesce((select p.is_developer from public.profiles p where p.id = auth.uid()), false);
$$;


ALTER FUNCTION "public"."is_current_user_developer"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."protect_developer_flag"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
begin
  if auth.uid() is not null then
    if tg_op = 'INSERT' then
      new.is_developer := false;
    elsif tg_op = 'UPDATE' then
      new.is_developer := old.is_developer;
    end if;
  end if;

  return new;
end;
$$;


ALTER FUNCTION "public"."protect_developer_flag"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."record_daily_login"() RETURNS TABLE("login_days_count" integer, "last_login_date" "date")
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  today_date date := current_date;
begin
  update public.profiles
  set
    login_days_count =
      case
        when profiles.last_login_date is distinct from today_date
          then profiles.login_days_count + 1
        else profiles.login_days_count
      end,
    last_login_date = today_date
  where id = auth.uid();

  return query
  select
    p.login_days_count,
    p.last_login_date
  from public.profiles p
  where p.id = auth.uid();
end;
$$;


ALTER FUNCTION "public"."record_daily_login"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."record_public_profile_view"("viewed_user_id" "uuid") RETURNS integer
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  new_count integer;
begin
  if auth.uid() is null then
    return 0;
  end if;

  -- Looking at your own profile does not count.
  if auth.uid() = viewed_user_id then
    select public_profiles_viewed
    into new_count
    from public.profiles
    where id = auth.uid();

    return coalesce(new_count, 0);
  end if;

  update public.profiles
  set public_profiles_viewed =
      public_profiles_viewed + 1
  where id = auth.uid()
  returning public_profiles_viewed
  into new_count;

  return coalesce(new_count, 0);
end;
$$;


ALTER FUNCTION "public"."record_public_profile_view"("viewed_user_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."register_push_token"("p_token" "text", "p_platform" "text") RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_user_id uuid;
begin
  v_user_id := auth.uid();

  if v_user_id is null then
    raise exception 'Not authenticated';
  end if;

  if p_token is null or
     length(trim(p_token)) = 0 then
    raise exception 'Token is empty';
  end if;

  insert into public.push_device_tokens (
    token,
    user_id,
    platform,
    updated_at
  )
  values (
    p_token,
    v_user_id,
    p_platform,
    now()
  )

  on conflict (token)
  do update set
    user_id = excluded.user_id,
    platform = excluded.platform,
    updated_at = now();
end;
$$;


ALTER FUNCTION "public"."register_push_token"("p_token" "text", "p_platform" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."report_comment"("p_comment_id" "text", "p_report_type" "text", "p_details" "text" DEFAULT NULL::"text") RETURNS integer
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_user_id uuid := auth.uid();
  v_author_id uuid;
  v_spoiler_count integer := 0;
begin
  if v_user_id is null then raise exception 'Not authenticated'; end if;
  if p_report_type not in ('comment','spoiler') then raise exception 'Invalid report type'; end if;

  select mc.user_id into v_author_id from public.media_comments mc where mc.id::text = p_comment_id;
  if v_author_id is null then raise exception 'Comment not found'; end if;
  if v_author_id = v_user_id then raise exception 'You cannot report your own comment'; end if;

  insert into public.comment_reports (reporter_id, comment_id, report_type, details)
  values (v_user_id, p_comment_id, p_report_type, nullif(trim(p_details), ''))
  on conflict (reporter_id, comment_id, report_type) do nothing;

  if p_report_type = 'spoiler' then
    select count(*)::integer into v_spoiler_count
    from public.comment_reports cr
    where cr.comment_id = p_comment_id
      and cr.report_type = 'spoiler'
      and cr.status in ('open','reviewing');
  end if;

  return v_spoiler_count;
end;
$$;


ALTER FUNCTION "public"."report_comment"("p_comment_id" "text", "p_report_type" "text", "p_details" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."search_visible_profiles"("p_query" "text", "p_limit" integer DEFAULT 20) RETURNS TABLE("id" "uuid", "display_name" "text", "username" "text", "avatar_url" "text")
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
  select
    p.id,
    p.display_name,
    p.username,
    p.avatar_url
  from public.profiles p
  where auth.uid() is not null
    and p.id <> auth.uid()
    and p.privacy_appear_in_search = true
    and not public.is_blocked_between(auth.uid(), p.id)
    and (
      coalesce(p.display_name, '') ilike '%' || trim(coalesce(p_query, '')) || '%'
      or coalesce(p.username, '') ilike '%' || trim(coalesce(p_query, '')) || '%'
    )
  order by
    case
      when lower(coalesce(p.username, '')) = lower(trim(coalesce(p_query, ''))) then 0
      when lower(coalesce(p.display_name, '')) = lower(trim(coalesce(p_query, ''))) then 0
      when lower(coalesce(p.username, '')) like lower(trim(coalesce(p_query, ''))) || '%' then 1
      when lower(coalesce(p.display_name, '')) like lower(trim(coalesce(p_query, ''))) || '%' then 2
      else 3
    end,
    lower(coalesce(p.display_name, p.username, ''))
  limit greatest(1, least(coalesce(p_limit, 20), 50));
$$;


ALTER FUNCTION "public"."search_visible_profiles"("p_query" "text", "p_limit" integer) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."set_feature_suggestion_status"("p_feature_id" "uuid", "p_status" "text", "p_note" "text" DEFAULT NULL::"text") RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_user_id uuid;
  v_title text;
  v_old_status text;
  v_note text := trim(coalesce(p_note, ''));
  v_status_label text;
begin
  if not public.is_chiplux_developer() then
    raise exception 'Developer access required.';
  end if;

  if p_status not in ('in_progress', 'implemented', 'rejected') then
    raise exception 'Invalid feature suggestion status.';
  end if;

  select f.user_id, f.title, f.status
    into v_user_id, v_title, v_old_status
  from public.feature_suggestions f
  where f.id = p_feature_id
  for update;

  if not found then
    raise exception 'Feature suggestion not found.';
  end if;

  update public.feature_suggestions
  set
    status = p_status,
    published_at = coalesce(published_at, now()),
    status_changed_at = now(),
    implemented_at = case
      when p_status = 'implemented' then coalesce(implemented_at, now())
      else implemented_at
    end,
    updated_at = now()
  where id = p_feature_id;

  if v_note <> '' then
    insert into public.feature_suggestion_comments(
      feature_id,
      user_id,
      body
    )
    values (
      p_feature_id,
      auth.uid(),
      v_note
    );
  end if;

  if v_old_status is distinct from p_status and v_user_id is not null then
    v_status_label := case p_status
      when 'in_progress' then 'In Progress'
      when 'implemented' then 'Implemented'
      when 'rejected' then 'Rejected'
      else p_status
    end;

    insert into public.notifications (
      recipient_user_id,
      actor_user_id,
      type,
      title,
      body,
      is_read
    )
    values (
      v_user_id,
      auth.uid(),
      'feature_suggestion_status',
      'Feature suggestion update',
      '"' || v_title || '" is now ' || v_status_label || '.',
      false
    );
  end if;
end;
$$;


ALTER FUNCTION "public"."set_feature_suggestion_status"("p_feature_id" "uuid", "p_status" "text", "p_note" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."submit_feature_suggestion"("p_title" "text", "p_description" "text", "p_public_attribution" boolean DEFAULT true) RETURNS "uuid"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_user_id uuid := auth.uid();
  v_last timestamptz;
  v_id uuid;
  v_title text := trim(coalesce(p_title, ''));
  v_description text := trim(coalesce(p_description, ''));
begin
  if v_user_id is null then
    raise exception 'You must be signed in.';
  end if;

  if char_length(v_title) < 4 or char_length(v_title) > 100 then
    raise exception 'Feature title must be 4 to 100 characters.';
  end if;

  if char_length(v_description) < 20 or char_length(v_description) > 3000 then
    raise exception 'Feature description must be 20 to 3000 characters.';
  end if;

  -- Serialize submissions for this account so two simultaneous requests
  -- cannot bypass the rolling 30-day limit.
  perform pg_advisory_xact_lock(hashtext(v_user_id::text));

  select s.last_submitted_at
    into v_last
  from public.feature_suggestion_submission_state s
  where s.user_id = v_user_id
  for update;

  if v_last is not null and now() < v_last + interval '30 days' then
    raise exception 'You can submit one feature suggestion every 30 days. Your next suggestion is available on %.',
      to_char(v_last + interval '30 days', 'YYYY-MM-DD');
  end if;

  insert into public.feature_suggestions (
    user_id,
    title,
    description,
    public_attribution
  )
  values (
    v_user_id,
    v_title,
    v_description,
    coalesce(p_public_attribution, true)
  )
  returning id into v_id;

  insert into public.feature_suggestion_submission_state (
    user_id,
    last_submitted_at
  )
  values (v_user_id, now())
  on conflict (user_id)
  do update set last_submitted_at = excluded.last_submitted_at;

  return v_id;
end;
$$;


ALTER FUNCTION "public"."submit_feature_suggestion"("p_title" "text", "p_description" "text", "p_public_attribution" boolean) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."suppress_blocked_notification"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
begin
  if new.actor_user_id is not null
     and public.is_blocked_between(new.actor_user_id, new.recipient_user_id) then
    return null;
  end if;

  return new;
end;
$$;


ALTER FUNCTION "public"."suppress_blocked_notification"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."sync_profile_username_claim"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $_$
begin
  if new.username is null
     or trim(new.username) = '' then

    delete from public.username_claims
    where user_id = new.id;

    return new;
  end if;

  if lower(trim(new.username))
      !~ '^[a-z0-9_]{3,20}$' then
    raise exception
      'Username must contain 3-20 letters, numbers, or underscores.';
  end if;

  insert into public.username_claims (
    user_id,
    username,
    updated_at
  )
  values (
    new.id,
    new.username,
    now()
  )
  on conflict (user_id)
  do update set
    username = excluded.username,
    updated_at = now();

  return new;
end;
$_$;


ALTER FUNCTION "public"."sync_profile_username_claim"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."toggle_feature_suggestion_like"("p_feature_id" "uuid") RETURNS boolean
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_user_id uuid := auth.uid();
  v_exists boolean;
begin
  if v_user_id is null then
    raise exception 'You must be signed in.';
  end if;

  if not exists (
    select 1
    from public.feature_suggestions f
    where f.id = p_feature_id
      and f.status <> 'pending'
  ) then
    raise exception 'This feature suggestion is not public.';
  end if;

  select exists (
    select 1
    from public.feature_suggestion_likes l
    where l.feature_id = p_feature_id
      and l.user_id = v_user_id
  ) into v_exists;

  if v_exists then
    delete from public.feature_suggestion_likes
    where feature_id = p_feature_id
      and user_id = v_user_id;

    return false;
  end if;

  insert into public.feature_suggestion_likes(feature_id, user_id)
  values (p_feature_id, v_user_id)
  on conflict do nothing;

  return true;
end;
$$;


ALTER FUNCTION "public"."toggle_feature_suggestion_like"("p_feature_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."unregister_push_token"("p_token" "text") RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
begin
  delete from public.push_device_tokens
  where
    token = p_token
    and user_id = auth.uid();
end;
$$;


ALTER FUNCTION "public"."unregister_push_token"("p_token" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."validate_follow_developer_achievement"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
begin
  -- Developer accounts can never earn this achievement.
  if old.is_developer = true then
    new.followed_developer_achievement := false;
    return new;
  end if;

  -- Once earned, keep it permanently.
  if old.followed_developer_achievement = true then
    new.followed_developer_achievement := true;
    return new;
  end if;

  -- Trying to unlock it.
  if new.followed_developer_achievement = true then
    if not exists (
      select 1
      from public.follows f
      join public.profiles developer_profile
        on developer_profile.id = f.following_id
      where f.follower_id = old.id
        and developer_profile.is_developer = true
    ) then
      new.followed_developer_achievement := false;
    end if;
  end if;

  return new;
end;
$$;


ALTER FUNCTION "public"."validate_follow_developer_achievement"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."validate_music_album_comment_parent"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    SET "search_path" TO 'public'
    AS $$
declare
  parent_album_id text;
begin
  if new.parent_comment_id is null then
    return new;
  end if;

  select album_id
  into parent_album_id
  from public.music_album_comments
  where id = new.parent_comment_id;

  if parent_album_id is null or parent_album_id <> new.album_id then
    raise exception 'Reply parent must belong to the same album.';
  end if;

  return new;
end;
$$;


ALTER FUNCTION "public"."validate_music_album_comment_parent"() OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."bug_reports" (
    "id" bigint NOT NULL,
    "user_id" "uuid",
    "description" "text" NOT NULL,
    "status" "text" DEFAULT 'open'::"text" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "bug_reports_description_check" CHECK ((("char_length"(TRIM(BOTH FROM "description")) >= 10) AND ("char_length"(TRIM(BOTH FROM "description")) <= 5000))),
    CONSTRAINT "bug_reports_status_check" CHECK (("status" = ANY (ARRAY['open'::"text", 'reviewing'::"text", 'resolved'::"text", 'dismissed'::"text"])))
);


ALTER TABLE "public"."bug_reports" OWNER TO "postgres";


ALTER TABLE "public"."bug_reports" ALTER COLUMN "id" ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME "public"."bug_reports_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);



CREATE TABLE IF NOT EXISTS "public"."chiplux_updates" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "title" "text" NOT NULL,
    "body" "text" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "public"."chiplux_updates" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."comment_attachments" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "comment_id" "uuid" NOT NULL,
    "user_id" "uuid" NOT NULL,
    "storage_path" "text",
    "attachment_type" "text" NOT NULL,
    "sort_order" integer DEFAULT 0 NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "provider" "text",
    "provider_media_id" "text",
    CONSTRAINT "comment_attachments_attachment_type_check" CHECK (("attachment_type" = ANY (ARRAY['image'::"text", 'gif'::"text"])))
);


ALTER TABLE "public"."comment_attachments" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."comment_likes" (
    "comment_id" "uuid" NOT NULL,
    "user_id" "uuid" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "public"."comment_likes" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."comment_reports" (
    "id" bigint NOT NULL,
    "reporter_id" "uuid" NOT NULL,
    "comment_id" "text" NOT NULL,
    "report_type" "text" NOT NULL,
    "details" "text",
    "status" "text" DEFAULT 'open'::"text" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "comment_reports_report_type_check" CHECK (("report_type" = ANY (ARRAY['comment'::"text", 'spoiler'::"text"]))),
    CONSTRAINT "comment_reports_status_check" CHECK (("status" = ANY (ARRAY['open'::"text", 'reviewing'::"text", 'resolved'::"text", 'dismissed'::"text"])))
);


ALTER TABLE "public"."comment_reports" OWNER TO "postgres";


ALTER TABLE "public"."comment_reports" ALTER COLUMN "id" ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME "public"."comment_reports_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);



ALTER TABLE "public"."community_activity" ALTER COLUMN "id" ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME "public"."community_activity_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);



CREATE TABLE IF NOT EXISTS "public"."daily_birthday_spotlights" (
    "spotlight_date" "date" NOT NULL,
    "tmdb_id" bigint NOT NULL,
    "name" "text" NOT NULL,
    "birth_year" integer,
    "age" integer,
    "profile_path" "text",
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "public"."daily_birthday_spotlights" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."daily_in_memoriam_spotlights" (
    "spotlight_date" "date" NOT NULL,
    "tmdb_id" bigint NOT NULL,
    "name" "text" NOT NULL,
    "birth_year" integer,
    "death_year" integer,
    "age_at_death" integer,
    "profile_path" "text",
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "public"."daily_in_memoriam_spotlights" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."episode_ratings" (
    "user_id" "uuid" NOT NULL,
    "show_id" bigint NOT NULL,
    "season_number" integer NOT NULL,
    "episode_number" integer NOT NULL,
    "rating" integer NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "episode_ratings_rating_check" CHECK ((("rating" >= 1) AND ("rating" <= 10)))
);


ALTER TABLE "public"."episode_ratings" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."feature_suggestion_comments" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "feature_id" "uuid" NOT NULL,
    "user_id" "uuid",
    "body" "text" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "feature_suggestion_comments_body_length" CHECK ((("char_length"(TRIM(BOTH FROM "body")) >= 1) AND ("char_length"(TRIM(BOTH FROM "body")) <= 2000)))
);


ALTER TABLE "public"."feature_suggestion_comments" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."feature_suggestion_likes" (
    "feature_id" "uuid" NOT NULL,
    "user_id" "uuid" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "public"."feature_suggestion_likes" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."feature_suggestion_submission_state" (
    "user_id" "uuid" NOT NULL,
    "last_submitted_at" timestamp with time zone NOT NULL
);


ALTER TABLE "public"."feature_suggestion_submission_state" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."feature_suggestions" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "user_id" "uuid",
    "title" "text" NOT NULL,
    "description" "text" NOT NULL,
    "status" "text" DEFAULT 'pending'::"text" NOT NULL,
    "public_attribution" boolean DEFAULT true NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "published_at" timestamp with time zone,
    "status_changed_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "implemented_at" timestamp with time zone,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "feature_suggestions_description_length" CHECK ((("char_length"(TRIM(BOTH FROM "description")) >= 20) AND ("char_length"(TRIM(BOTH FROM "description")) <= 3000))),
    CONSTRAINT "feature_suggestions_status_check" CHECK (("status" = ANY (ARRAY['pending'::"text", 'in_progress'::"text", 'implemented'::"text", 'rejected'::"text"]))),
    CONSTRAINT "feature_suggestions_title_length" CHECK ((("char_length"(TRIM(BOTH FROM "title")) >= 4) AND ("char_length"(TRIM(BOTH FROM "title")) <= 100)))
);


ALTER TABLE "public"."feature_suggestions" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."follows" (
    "follower_id" "uuid" NOT NULL,
    "following_id" "uuid" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "cannot_follow_yourself" CHECK (("follower_id" <> "following_id"))
);


ALTER TABLE "public"."follows" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."library_items" (
    "user_id" "uuid" NOT NULL,
    "tmdb_id" bigint NOT NULL,
    "media_type" "text" NOT NULL,
    "title" "text" NOT NULL,
    "poster_path" "text",
    "year" "text",
    "status" "text" NOT NULL,
    "total_episodes" integer DEFAULT 0 NOT NULL,
    "added_at" bigint NOT NULL,
    "runtime_minutes" integer DEFAULT 0 NOT NULL,
    "genre_ids" "jsonb" DEFAULT '[]'::"jsonb" NOT NULL
);


ALTER TABLE "public"."library_items" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."media_comments" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "user_id" "uuid" NOT NULL,
    "media_type" "text" NOT NULL,
    "tmdb_id" bigint NOT NULL,
    "season_number" integer,
    "episode_number" integer,
    "parent_comment_id" "uuid",
    "body" "text" DEFAULT ''::"text" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "edited_at" timestamp with time zone,
    "deleted_at" timestamp with time zone,
    CONSTRAINT "media_comments_body_length" CHECK (("char_length"("body") <= 4000)),
    CONSTRAINT "media_comments_media_type_check" CHECK (("media_type" = ANY (ARRAY['movie'::"text", 'tv'::"text", 'episode'::"text"]))),
    CONSTRAINT "media_comments_target" CHECK (((("media_type" = ANY (ARRAY['movie'::"text", 'tv'::"text"])) AND ("season_number" IS NULL) AND ("episode_number" IS NULL)) OR (("media_type" = 'episode'::"text") AND ("season_number" IS NOT NULL) AND ("episode_number" IS NOT NULL))))
);


ALTER TABLE "public"."media_comments" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."media_user_data" (
    "user_id" "uuid" NOT NULL,
    "tmdb_id" bigint NOT NULL,
    "media_type" "text" NOT NULL,
    "is_favorite" boolean DEFAULT false NOT NULL,
    "rating" integer,
    "review" "text",
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "media_user_data_rating_check" CHECK ((("rating" IS NULL) OR (("rating" >= 1) AND ("rating" <= 10))))
);


ALTER TABLE "public"."media_user_data" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."music_album_comment_likes" (
    "comment_id" "uuid" NOT NULL,
    "user_id" "uuid" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "public"."music_album_comment_likes" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."music_album_comment_reports" (
    "id" bigint NOT NULL,
    "comment_id" "uuid" NOT NULL,
    "reporter_id" "uuid" NOT NULL,
    "report_type" "text" NOT NULL,
    "details" "text",
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "status" "text" DEFAULT 'open'::"text" NOT NULL,
    CONSTRAINT "music_album_comment_reports_status_check" CHECK (("status" = ANY (ARRAY['open'::"text", 'reviewing'::"text", 'resolved'::"text", 'dismissed'::"text"])))
);


ALTER TABLE "public"."music_album_comment_reports" OWNER TO "postgres";


ALTER TABLE "public"."music_album_comment_reports" ALTER COLUMN "id" ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME "public"."music_album_comment_reports_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);



CREATE TABLE IF NOT EXISTS "public"."music_album_comments" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "user_id" "uuid" NOT NULL,
    "album_id" "text" NOT NULL,
    "album_title" "text" DEFAULT ''::"text" NOT NULL,
    "artist_name" "text" DEFAULT ''::"text" NOT NULL,
    "cover_url" "text",
    "parent_comment_id" "uuid",
    "body" "text" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "edited_at" timestamp with time zone,
    CONSTRAINT "music_album_comments_body_check" CHECK ((("char_length"("body") >= 1) AND ("char_length"("body") <= 4000)))
);


ALTER TABLE "public"."music_album_comments" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."music_user_data" (
    "user_id" "uuid" NOT NULL,
    "entity_type" "text" NOT NULL,
    "entity_id" "text" NOT NULL,
    "artist_id" "text" NOT NULL,
    "artist_name" "text" NOT NULL,
    "album_id" "text",
    "album_title" "text",
    "title" "text" NOT NULL,
    "release_year" "text" DEFAULT ''::"text" NOT NULL,
    "cover_url" "text",
    "duration_ms" integer DEFAULT 0 NOT NULL,
    "track_number" "text",
    "disc_number" integer,
    "is_listened" boolean DEFAULT false NOT NULL,
    "is_favorite" boolean DEFAULT false NOT NULL,
    "rating" smallint,
    "listened_at" timestamp with time zone,
    "rated_at" timestamp with time zone,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "genre_names" "text"[] DEFAULT '{}'::"text"[] NOT NULL,
    "library_status" "text",
    CONSTRAINT "music_user_data_album_rating_requires_listened_check" CHECK ((("entity_type" <> 'album'::"text") OR ("rating" IS NULL) OR ("is_listened" = true))),
    CONSTRAINT "music_user_data_duration_ms_check" CHECK (("duration_ms" >= 0)),
    CONSTRAINT "music_user_data_entity_type_check" CHECK (("entity_type" = ANY (ARRAY['album'::"text", 'track'::"text"]))),
    CONSTRAINT "music_user_data_library_status_check" CHECK ((("library_status" IS NULL) OR (("entity_type" = 'album'::"text") AND ("library_status" = ANY (ARRAY['plan'::"text", 'dropped'::"text"]))))),
    CONSTRAINT "music_user_data_listened_album_has_no_library_status_check" CHECK ((("entity_type" <> 'album'::"text") OR ("is_listened" = false) OR ("library_status" IS NULL))),
    CONSTRAINT "music_user_data_rating_check" CHECK ((("rating" IS NULL) OR ("rating" = ANY (ARRAY[2, 4, 6, 8, 10]))))
);


ALTER TABLE "public"."music_user_data" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."new_episode_notification_state" (
    "user_id" "uuid" NOT NULL,
    "tmdb_id" bigint NOT NULL,
    "season_number" integer NOT NULL,
    "episode_number" integer NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "public"."new_episode_notification_state" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."notifications" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "recipient_user_id" "uuid" NOT NULL,
    "actor_user_id" "uuid",
    "type" "text" NOT NULL,
    "title" "text" NOT NULL,
    "body" "text" NOT NULL,
    "media_type" "text",
    "tmdb_id" bigint,
    "season_number" integer,
    "episode_number" integer,
    "comment_id" "text",
    "parent_comment_id" "text",
    "is_read" boolean DEFAULT false NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "milestone_value" integer,
    "achievement_id" "text",
    "achievement_title" "text",
    "chiplux_update_id" "uuid"
);


ALTER TABLE "public"."notifications" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."profiles" (
    "id" "uuid" NOT NULL,
    "display_name" "text",
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "username" "text",
    "avatar_url" "text",
    "bio" "text",
    "banner_tmdb_id" bigint,
    "banner_media_type" "text",
    "banner_path" "text",
    "public_stats" "jsonb" DEFAULT '{}'::"jsonb" NOT NULL,
    "pinned_achievement_id" "text",
    "username_key" "text" GENERATED ALWAYS AS (
CASE
    WHEN ("username" IS NULL) THEN NULL::"text"
    ELSE "lower"("btrim"("username"))
END) STORED,
    "display_name_frame_id" "text",
    "avatar_frame_id" "text",
    "login_days_count" integer DEFAULT 0 NOT NULL,
    "last_login_date" "date",
    "public_profiles_viewed" integer DEFAULT 0 NOT NULL,
    "achievement_cosmetics" "jsonb" DEFAULT '{}'::"jsonb" NOT NULL,
    "profile_title" "text",
    "profile_title_id" "text",
    "notify_new_episodes" boolean DEFAULT true NOT NULL,
    "notify_release_reminders" boolean DEFAULT true NOT NULL,
    "notify_comments_replies" boolean DEFAULT true NOT NULL,
    "notify_comment_like_milestones" boolean DEFAULT true NOT NULL,
    "notify_new_followers" boolean DEFAULT true NOT NULL,
    "notify_achievements" boolean DEFAULT true NOT NULL,
    "notify_chiplux_updates" boolean DEFAULT true NOT NULL,
    "is_developer" boolean DEFAULT false NOT NULL,
    "profile_page_frame_id" "text",
    "followed_developer_achievement" boolean DEFAULT false NOT NULL,
    "privacy_profile_visibility" "text" DEFAULT 'everyone'::"text" NOT NULL,
    "privacy_appear_in_search" boolean DEFAULT true NOT NULL,
    "privacy_show_activity" boolean DEFAULT true NOT NULL,
    "privacy_show_watch_activity" boolean DEFAULT true NOT NULL,
    "privacy_show_ratings_activity" boolean DEFAULT true NOT NULL,
    "privacy_show_achievements_activity" boolean DEFAULT true NOT NULL,
    "privacy_show_watch_stats" boolean DEFAULT true NOT NULL,
    "privacy_show_genre_stats" boolean DEFAULT true NOT NULL,
    "privacy_show_rating_stats" boolean DEFAULT true NOT NULL,
    "privacy_show_profile_achievements" boolean DEFAULT true NOT NULL,
    "privacy_show_connections" boolean DEFAULT true NOT NULL,
    "privacy_follow_permission" "text" DEFAULT 'everyone'::"text" NOT NULL,
    "privacy_allow_comment_replies" boolean DEFAULT true NOT NULL,
    "privacy_feature_suggestion_attribution" boolean DEFAULT true NOT NULL,
    CONSTRAINT "profiles_developer_title_guard" CHECK ((("profile_title_id" IS DISTINCT FROM 'developer'::"text") OR ("is_developer" = true))),
    CONSTRAINT "profiles_display_name_frame_id_check" CHECK ((("display_name_frame_id" IS NULL) OR ("display_name_frame_id" = ANY (ARRAY['login_7'::"text", 'login_14'::"text", 'login_30'::"text", 'login_90'::"text", 'login_180'::"text", 'login_360'::"text"])))),
    CONSTRAINT "profiles_privacy_follow_permission_check" CHECK (("privacy_follow_permission" = ANY (ARRAY['everyone'::"text", 'people_i_follow'::"text", 'nobody'::"text"]))),
    CONSTRAINT "profiles_privacy_profile_visibility_check" CHECK (("privacy_profile_visibility" = ANY (ARRAY['everyone'::"text", 'followers'::"text", 'private'::"text"]))),
    CONSTRAINT "profiles_profile_page_frame_id_check" CHECK ((("profile_page_frame_id" IS NULL) OR (("profile_page_frame_id" = 'developer'::"text") AND ("is_developer" = true)) OR (("profile_page_frame_id" = 'follow_developer_tier3'::"text") AND (("is_developer" = true) OR ("followed_developer_achievement" = true)))))
);


ALTER TABLE "public"."profiles" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."push_device_tokens" (
    "token" "text" NOT NULL,
    "user_id" "uuid" NOT NULL,
    "platform" "text" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "public"."push_device_tokens" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."release_notification_state" (
    "user_id" "uuid" NOT NULL,
    "tmdb_id" bigint NOT NULL,
    "media_type" "text" NOT NULL,
    "release_date" "date",
    "notified" boolean DEFAULT false NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "release_notification_state_media_type_check" CHECK (("media_type" = ANY (ARRAY['movie'::"text", 'tv'::"text"])))
);


ALTER TABLE "public"."release_notification_state" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."user_blocks" (
    "blocker_id" "uuid" NOT NULL,
    "blocked_id" "uuid" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "user_blocks_no_self_block" CHECK (("blocker_id" <> "blocked_id"))
);


ALTER TABLE "public"."user_blocks" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."user_reports" (
    "id" bigint NOT NULL,
    "reporter_id" "uuid" NOT NULL,
    "reported_user_id" "uuid" NOT NULL,
    "reason" "text" NOT NULL,
    "details" "text",
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "status" "text" DEFAULT 'open'::"text" NOT NULL,
    CONSTRAINT "user_reports_no_self_report" CHECK (("reporter_id" <> "reported_user_id")),
    CONSTRAINT "user_reports_reason_not_blank" CHECK (("length"(TRIM(BOTH FROM "reason")) > 0)),
    CONSTRAINT "user_reports_status_check" CHECK (("status" = ANY (ARRAY['open'::"text", 'reviewing'::"text", 'resolved'::"text", 'dismissed'::"text"])))
);


ALTER TABLE "public"."user_reports" OWNER TO "postgres";


ALTER TABLE "public"."user_reports" ALTER COLUMN "id" ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME "public"."user_reports_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);



CREATE TABLE IF NOT EXISTS "public"."username_claims" (
    "user_id" "uuid" NOT NULL,
    "username" "text" NOT NULL,
    "username_key" "text" GENERATED ALWAYS AS ("lower"(TRIM(BOTH FROM "username"))) STORED,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "public"."username_claims" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."watched_episodes" (
    "user_id" "uuid" NOT NULL,
    "show_id" bigint NOT NULL,
    "season_number" integer NOT NULL,
    "episode_number" integer NOT NULL,
    "runtime_minutes" integer DEFAULT 0 NOT NULL
);


ALTER TABLE "public"."watched_episodes" OWNER TO "postgres";


ALTER TABLE ONLY "public"."bug_reports"
    ADD CONSTRAINT "bug_reports_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."chiplux_updates"
    ADD CONSTRAINT "chiplux_updates_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."comment_attachments"
    ADD CONSTRAINT "comment_attachments_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."comment_likes"
    ADD CONSTRAINT "comment_likes_pkey" PRIMARY KEY ("comment_id", "user_id");



ALTER TABLE ONLY "public"."comment_reports"
    ADD CONSTRAINT "comment_reports_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."comment_reports"
    ADD CONSTRAINT "comment_reports_reporter_id_comment_id_report_type_key" UNIQUE ("reporter_id", "comment_id", "report_type");



ALTER TABLE ONLY "public"."community_activity"
    ADD CONSTRAINT "community_activity_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."daily_birthday_spotlights"
    ADD CONSTRAINT "daily_birthday_spotlights_pkey" PRIMARY KEY ("spotlight_date");



ALTER TABLE ONLY "public"."daily_in_memoriam_spotlights"
    ADD CONSTRAINT "daily_in_memoriam_spotlights_pkey" PRIMARY KEY ("spotlight_date");



ALTER TABLE ONLY "public"."episode_ratings"
    ADD CONSTRAINT "episode_ratings_pkey" PRIMARY KEY ("user_id", "show_id", "season_number", "episode_number");



ALTER TABLE ONLY "public"."feature_suggestion_comments"
    ADD CONSTRAINT "feature_suggestion_comments_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."feature_suggestion_likes"
    ADD CONSTRAINT "feature_suggestion_likes_pkey" PRIMARY KEY ("feature_id", "user_id");



ALTER TABLE ONLY "public"."feature_suggestion_submission_state"
    ADD CONSTRAINT "feature_suggestion_submission_state_pkey" PRIMARY KEY ("user_id");



ALTER TABLE ONLY "public"."feature_suggestions"
    ADD CONSTRAINT "feature_suggestions_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."follows"
    ADD CONSTRAINT "follows_pkey" PRIMARY KEY ("follower_id", "following_id");



ALTER TABLE ONLY "public"."library_items"
    ADD CONSTRAINT "library_items_pkey" PRIMARY KEY ("user_id", "tmdb_id", "media_type");



ALTER TABLE ONLY "public"."media_comments"
    ADD CONSTRAINT "media_comments_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."media_user_data"
    ADD CONSTRAINT "media_user_data_pkey" PRIMARY KEY ("user_id", "tmdb_id", "media_type");



ALTER TABLE ONLY "public"."music_album_comment_likes"
    ADD CONSTRAINT "music_album_comment_likes_pkey" PRIMARY KEY ("comment_id", "user_id");



ALTER TABLE ONLY "public"."music_album_comment_reports"
    ADD CONSTRAINT "music_album_comment_reports_comment_id_reporter_id_report_t_key" UNIQUE ("comment_id", "reporter_id", "report_type");



ALTER TABLE ONLY "public"."music_album_comment_reports"
    ADD CONSTRAINT "music_album_comment_reports_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."music_album_comments"
    ADD CONSTRAINT "music_album_comments_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."music_user_data"
    ADD CONSTRAINT "music_user_data_pkey" PRIMARY KEY ("user_id", "entity_type", "entity_id");



ALTER TABLE ONLY "public"."new_episode_notification_state"
    ADD CONSTRAINT "new_episode_notification_state_pkey" PRIMARY KEY ("user_id", "tmdb_id");



ALTER TABLE ONLY "public"."notifications"
    ADD CONSTRAINT "notifications_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."profiles"
    ADD CONSTRAINT "profiles_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."push_device_tokens"
    ADD CONSTRAINT "push_device_tokens_pkey" PRIMARY KEY ("token");



ALTER TABLE ONLY "public"."release_notification_state"
    ADD CONSTRAINT "release_notification_state_pkey" PRIMARY KEY ("user_id", "tmdb_id", "media_type");



ALTER TABLE ONLY "public"."user_blocks"
    ADD CONSTRAINT "user_blocks_pkey" PRIMARY KEY ("blocker_id", "blocked_id");



ALTER TABLE ONLY "public"."user_reports"
    ADD CONSTRAINT "user_reports_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."username_claims"
    ADD CONSTRAINT "username_claims_pkey" PRIMARY KEY ("user_id");



ALTER TABLE ONLY "public"."watched_episodes"
    ADD CONSTRAINT "watched_episodes_pkey" PRIMARY KEY ("user_id", "show_id", "season_number", "episode_number");



CREATE INDEX "comment_attachments_comment_idx" ON "public"."comment_attachments" USING "btree" ("comment_id");



CREATE INDEX "comment_likes_comment_idx" ON "public"."comment_likes" USING "btree" ("comment_id");



CREATE INDEX "community_activity_created_idx" ON "public"."community_activity" USING "btree" ("created_at" DESC);



CREATE INDEX "community_activity_music_external_idx" ON "public"."community_activity" USING "btree" ("media_type", "external_id");



CREATE INDEX "community_activity_music_parent_idx" ON "public"."community_activity" USING "btree" ("media_type", "parent_external_id");



CREATE INDEX "community_activity_user_created_idx" ON "public"."community_activity" USING "btree" ("user_id", "created_at" DESC);



CREATE INDEX "feature_suggestion_comments_feature_idx" ON "public"."feature_suggestion_comments" USING "btree" ("feature_id", "created_at");



CREATE INDEX "feature_suggestion_likes_feature_idx" ON "public"."feature_suggestion_likes" USING "btree" ("feature_id", "created_at" DESC);



CREATE INDEX "feature_suggestion_likes_user_idx" ON "public"."feature_suggestion_likes" USING "btree" ("user_id", "created_at" DESC);



CREATE INDEX "feature_suggestions_public_idx" ON "public"."feature_suggestions" USING "btree" ("published_at" DESC) WHERE ("status" <> 'pending'::"text");



CREATE INDEX "feature_suggestions_status_changed_idx" ON "public"."feature_suggestions" USING "btree" ("status", "status_changed_at" DESC);



CREATE INDEX "feature_suggestions_user_created_idx" ON "public"."feature_suggestions" USING "btree" ("user_id", "created_at" DESC);



CREATE INDEX "follows_follower_id_idx" ON "public"."follows" USING "btree" ("follower_id");



CREATE INDEX "follows_following_id_idx" ON "public"."follows" USING "btree" ("following_id");



CREATE INDEX "media_comments_parent_idx" ON "public"."media_comments" USING "btree" ("parent_comment_id", "created_at");



CREATE INDEX "media_comments_thread_idx" ON "public"."media_comments" USING "btree" ("media_type", "tmdb_id", "season_number", "episode_number", "created_at" DESC);



CREATE INDEX "music_album_comment_likes_user_idx" ON "public"."music_album_comment_likes" USING "btree" ("user_id");



CREATE INDEX "music_album_comment_reports_comment_idx" ON "public"."music_album_comment_reports" USING "btree" ("comment_id", "report_type");



CREATE INDEX "music_album_comments_album_idx" ON "public"."music_album_comments" USING "btree" ("album_id", "created_at" DESC);



CREATE INDEX "music_album_comments_parent_idx" ON "public"."music_album_comments" USING "btree" ("parent_comment_id");



CREATE INDEX "music_album_comments_user_idx" ON "public"."music_album_comments" USING "btree" ("user_id", "created_at" DESC);



CREATE INDEX "music_user_data_album_idx" ON "public"."music_user_data" USING "btree" ("user_id", "album_id");



CREATE INDEX "music_user_data_user_entity_state_idx" ON "public"."music_user_data" USING "btree" ("user_id", "entity_type", "is_listened", "is_favorite");



CREATE INDEX "music_user_data_user_favorite_idx" ON "public"."music_user_data" USING "btree" ("user_id", "entity_type", "is_favorite");



CREATE INDEX "music_user_data_user_library_status_idx" ON "public"."music_user_data" USING "btree" ("user_id", "entity_type", "library_status");



CREATE INDEX "music_user_data_user_listened_idx" ON "public"."music_user_data" USING "btree" ("user_id", "entity_type", "is_listened");



CREATE INDEX "music_user_data_user_rating_idx" ON "public"."music_user_data" USING "btree" ("user_id", "entity_type", "rating");



CREATE INDEX "notifications_recipient_created_idx" ON "public"."notifications" USING "btree" ("recipient_user_id", "created_at" DESC);



CREATE INDEX "notifications_recipient_unread_idx" ON "public"."notifications" USING "btree" ("recipient_user_id", "is_read");



CREATE UNIQUE INDEX "notifications_unique_achievement_idx" ON "public"."notifications" USING "btree" ("recipient_user_id", "achievement_id") WHERE (("type" = 'achievement'::"text") AND ("achievement_id" IS NOT NULL));



CREATE UNIQUE INDEX "notifications_unique_chiplux_update_idx" ON "public"."notifications" USING "btree" ("recipient_user_id", "chiplux_update_id") WHERE (("type" = 'chiplux_update'::"text") AND ("chiplux_update_id" IS NOT NULL));



CREATE UNIQUE INDEX "notifications_unique_like_milestone_idx" ON "public"."notifications" USING "btree" ("comment_id", "recipient_user_id", "milestone_value") WHERE (("type" = 'comment_like_milestone'::"text") AND ("comment_id" IS NOT NULL) AND ("milestone_value" IS NOT NULL));



CREATE UNIQUE INDEX "notifications_unique_new_episode_idx" ON "public"."notifications" USING "btree" ("recipient_user_id", "tmdb_id", "season_number", "episode_number") WHERE ("type" = 'new_episode'::"text");



CREATE UNIQUE INDEX "notifications_unique_release_idx" ON "public"."notifications" USING "btree" ("recipient_user_id", "tmdb_id", "media_type") WHERE ("type" = 'release'::"text");



CREATE UNIQUE INDEX "notifications_unique_reply_idx" ON "public"."notifications" USING "btree" ("comment_id", "recipient_user_id") WHERE (("type" = 'comment_reply'::"text") AND ("comment_id" IS NOT NULL));



CREATE UNIQUE INDEX "profiles_username_key_unique" ON "public"."profiles" USING "btree" ("username_key") WHERE (("username_key" IS NOT NULL) AND ("username_key" <> ''::"text"));



CREATE UNIQUE INDEX "profiles_username_unique" ON "public"."profiles" USING "btree" ("lower"("username")) WHERE ("username" IS NOT NULL);



CREATE INDEX "push_device_tokens_user_id_idx" ON "public"."push_device_tokens" USING "btree" ("user_id");



CREATE INDEX "user_blocks_blocked_id_idx" ON "public"."user_blocks" USING "btree" ("blocked_id");



CREATE INDEX "user_reports_reported_user_idx" ON "public"."user_reports" USING "btree" ("reported_user_id");



CREATE UNIQUE INDEX "username_claims_username_key_unique" ON "public"."username_claims" USING "btree" ("username_key");



CREATE OR REPLACE TRIGGER "cleanup_after_block_trigger" AFTER INSERT ON "public"."user_blocks" FOR EACH ROW EXECUTE FUNCTION "public"."cleanup_after_block"();



CREATE OR REPLACE TRIGGER "create_achievement_notification_trigger" AFTER INSERT ON "public"."community_activity" FOR EACH ROW EXECUTE FUNCTION "public"."create_achievement_notification"();



CREATE OR REPLACE TRIGGER "create_comment_like_milestone_notification_trigger" AFTER INSERT ON "public"."comment_likes" FOR EACH ROW EXECUTE FUNCTION "public"."create_comment_like_milestone_notification"();



CREATE OR REPLACE TRIGGER "create_comment_reply_notification_trigger" AFTER INSERT ON "public"."media_comments" FOR EACH ROW WHEN (("new"."parent_comment_id" IS NOT NULL)) EXECUTE FUNCTION "public"."create_comment_reply_notification"();



CREATE OR REPLACE TRIGGER "create_new_follower_notification_trigger" AFTER INSERT ON "public"."follows" FOR EACH ROW EXECUTE FUNCTION "public"."create_new_follower_notification"();



CREATE OR REPLACE TRIGGER "enforce_comment_like_privacy_trigger" BEFORE INSERT ON "public"."comment_likes" FOR EACH ROW EXECUTE FUNCTION "public"."enforce_comment_like_privacy"();



CREATE OR REPLACE TRIGGER "enforce_comment_reply_privacy_trigger" BEFORE INSERT ON "public"."media_comments" FOR EACH ROW EXECUTE FUNCTION "public"."enforce_comment_reply_privacy"();



CREATE OR REPLACE TRIGGER "enforce_follow_privacy_trigger" BEFORE INSERT ON "public"."follows" FOR EACH ROW EXECUTE FUNCTION "public"."enforce_follow_privacy"();



CREATE OR REPLACE TRIGGER "protect_developer_flag" BEFORE INSERT OR UPDATE ON "public"."profiles" FOR EACH ROW EXECUTE FUNCTION "public"."protect_developer_flag"();



CREATE OR REPLACE TRIGGER "send-chiplux-push" AFTER INSERT ON "public"."notifications" FOR EACH ROW EXECUTE FUNCTION "supabase_functions"."http_request"('https://xjzjpfgxrvolghromjon.supabase.co/functions/v1/send-push-notification', 'POST', '{"x-push-secret":"9ef4e3d099f428f93ea3e7a60146eba79baaa42e798994334038d1ff666","Content-Type":"application/json"}', '{}', '5000');



CREATE OR REPLACE TRIGGER "suppress_blocked_notification_trigger" BEFORE INSERT ON "public"."notifications" FOR EACH ROW EXECUTE FUNCTION "public"."suppress_blocked_notification"();



CREATE OR REPLACE TRIGGER "sync_profile_username_claim_trigger" AFTER INSERT OR UPDATE OF "username" ON "public"."profiles" FOR EACH ROW EXECUTE FUNCTION "public"."sync_profile_username_claim"();



CREATE OR REPLACE TRIGGER "trigger_broadcast_chiplux_update" AFTER INSERT ON "public"."chiplux_updates" FOR EACH ROW EXECUTE FUNCTION "public"."broadcast_chiplux_update"();



CREATE OR REPLACE TRIGGER "validate_follow_developer_achievement" BEFORE UPDATE ON "public"."profiles" FOR EACH ROW EXECUTE FUNCTION "public"."validate_follow_developer_achievement"();



CREATE OR REPLACE TRIGGER "validate_music_album_comment_parent_trigger" BEFORE INSERT OR UPDATE OF "parent_comment_id", "album_id" ON "public"."music_album_comments" FOR EACH ROW EXECUTE FUNCTION "public"."validate_music_album_comment_parent"();



ALTER TABLE ONLY "public"."bug_reports"
    ADD CONSTRAINT "bug_reports_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."comment_attachments"
    ADD CONSTRAINT "comment_attachments_comment_id_fkey" FOREIGN KEY ("comment_id") REFERENCES "public"."media_comments"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."comment_attachments"
    ADD CONSTRAINT "comment_attachments_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "public"."profiles"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."comment_likes"
    ADD CONSTRAINT "comment_likes_comment_id_fkey" FOREIGN KEY ("comment_id") REFERENCES "public"."media_comments"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."comment_likes"
    ADD CONSTRAINT "comment_likes_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "public"."profiles"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."comment_reports"
    ADD CONSTRAINT "comment_reports_reporter_id_fkey" FOREIGN KEY ("reporter_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."community_activity"
    ADD CONSTRAINT "community_activity_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."episode_ratings"
    ADD CONSTRAINT "episode_ratings_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."feature_suggestion_comments"
    ADD CONSTRAINT "feature_suggestion_comments_feature_id_fkey" FOREIGN KEY ("feature_id") REFERENCES "public"."feature_suggestions"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."feature_suggestion_comments"
    ADD CONSTRAINT "feature_suggestion_comments_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "public"."profiles"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."feature_suggestion_likes"
    ADD CONSTRAINT "feature_suggestion_likes_feature_id_fkey" FOREIGN KEY ("feature_id") REFERENCES "public"."feature_suggestions"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."feature_suggestion_likes"
    ADD CONSTRAINT "feature_suggestion_likes_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "public"."profiles"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."feature_suggestion_submission_state"
    ADD CONSTRAINT "feature_suggestion_submission_state_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "public"."profiles"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."feature_suggestions"
    ADD CONSTRAINT "feature_suggestions_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "public"."profiles"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."follows"
    ADD CONSTRAINT "follows_follower_id_fkey" FOREIGN KEY ("follower_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."follows"
    ADD CONSTRAINT "follows_following_id_fkey" FOREIGN KEY ("following_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."library_items"
    ADD CONSTRAINT "library_items_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."media_comments"
    ADD CONSTRAINT "media_comments_parent_comment_id_fkey" FOREIGN KEY ("parent_comment_id") REFERENCES "public"."media_comments"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."media_comments"
    ADD CONSTRAINT "media_comments_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "public"."profiles"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."media_user_data"
    ADD CONSTRAINT "media_user_data_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."music_album_comment_likes"
    ADD CONSTRAINT "music_album_comment_likes_comment_id_fkey" FOREIGN KEY ("comment_id") REFERENCES "public"."music_album_comments"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."music_album_comment_likes"
    ADD CONSTRAINT "music_album_comment_likes_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."music_album_comment_reports"
    ADD CONSTRAINT "music_album_comment_reports_comment_id_fkey" FOREIGN KEY ("comment_id") REFERENCES "public"."music_album_comments"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."music_album_comment_reports"
    ADD CONSTRAINT "music_album_comment_reports_reporter_id_fkey" FOREIGN KEY ("reporter_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."music_album_comments"
    ADD CONSTRAINT "music_album_comments_parent_comment_id_fkey" FOREIGN KEY ("parent_comment_id") REFERENCES "public"."music_album_comments"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."music_album_comments"
    ADD CONSTRAINT "music_album_comments_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."music_user_data"
    ADD CONSTRAINT "music_user_data_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."new_episode_notification_state"
    ADD CONSTRAINT "new_episode_notification_state_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "public"."profiles"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."notifications"
    ADD CONSTRAINT "notifications_actor_user_id_fkey" FOREIGN KEY ("actor_user_id") REFERENCES "public"."profiles"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."notifications"
    ADD CONSTRAINT "notifications_recipient_user_id_fkey" FOREIGN KEY ("recipient_user_id") REFERENCES "public"."profiles"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."profiles"
    ADD CONSTRAINT "profiles_id_fkey" FOREIGN KEY ("id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."push_device_tokens"
    ADD CONSTRAINT "push_device_tokens_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."release_notification_state"
    ADD CONSTRAINT "release_notification_state_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "public"."profiles"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."user_blocks"
    ADD CONSTRAINT "user_blocks_blocked_id_fkey" FOREIGN KEY ("blocked_id") REFERENCES "public"."profiles"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."user_blocks"
    ADD CONSTRAINT "user_blocks_blocker_id_fkey" FOREIGN KEY ("blocker_id") REFERENCES "public"."profiles"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."user_reports"
    ADD CONSTRAINT "user_reports_reported_user_id_fkey" FOREIGN KEY ("reported_user_id") REFERENCES "public"."profiles"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."user_reports"
    ADD CONSTRAINT "user_reports_reporter_id_fkey" FOREIGN KEY ("reporter_id") REFERENCES "public"."profiles"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."username_claims"
    ADD CONSTRAINT "username_claims_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."watched_episodes"
    ADD CONSTRAINT "watched_episodes_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



CREATE POLICY "Authenticated users can read birthday spotlights" ON "public"."daily_birthday_spotlights" FOR SELECT TO "authenticated" USING (true);



CREATE POLICY "Authenticated users can read in memoriam spotlights" ON "public"."daily_in_memoriam_spotlights" FOR SELECT TO "authenticated" USING (true);



CREATE POLICY "Authenticated users can read profiles" ON "public"."profiles" FOR SELECT TO "authenticated" USING (true);



CREATE POLICY "Authenticated users can view follows" ON "public"."follows" FOR SELECT TO "authenticated" USING (true);



CREATE POLICY "Create own attachments" ON "public"."comment_attachments" FOR INSERT TO "authenticated" WITH CHECK ((("user_id" = "auth"."uid"()) AND (EXISTS ( SELECT 1
   FROM "public"."media_comments" "c"
  WHERE (("c"."id" = "comment_attachments"."comment_id") AND ("c"."user_id" = "auth"."uid"()))))));



CREATE POLICY "Create unlocked comments" ON "public"."media_comments" FOR INSERT TO "authenticated" WITH CHECK ((("user_id" = "auth"."uid"()) AND "public"."can_access_media_comments"("media_type", "tmdb_id", "season_number", "episode_number")));



CREATE POLICY "Delete own attachments" ON "public"."comment_attachments" FOR DELETE TO "authenticated" USING (("user_id" = "auth"."uid"()));



CREATE POLICY "Delete own comments" ON "public"."media_comments" FOR DELETE TO "authenticated" USING (("user_id" = "auth"."uid"()));



CREATE POLICY "Edit own comments" ON "public"."media_comments" FOR UPDATE TO "authenticated" USING (("user_id" = "auth"."uid"())) WITH CHECK (("user_id" = "auth"."uid"()));



CREATE POLICY "Like unlocked comments" ON "public"."comment_likes" FOR INSERT TO "authenticated" WITH CHECK ((("user_id" = "auth"."uid"()) AND (EXISTS ( SELECT 1
   FROM "public"."media_comments" "c"
  WHERE (("c"."id" = "comment_likes"."comment_id") AND "public"."can_access_media_comments"("c"."media_type", "c"."tmdb_id", "c"."season_number", "c"."episode_number"))))));



CREATE POLICY "Read comment likes" ON "public"."comment_likes" FOR SELECT TO "authenticated" USING ((EXISTS ( SELECT 1
   FROM "public"."media_comments" "c"
  WHERE (("c"."id" = "comment_likes"."comment_id") AND "public"."can_access_media_comments"("c"."media_type", "c"."tmdb_id", "c"."season_number", "c"."episode_number")))));



CREATE POLICY "Read unlocked attachments" ON "public"."comment_attachments" FOR SELECT TO "authenticated" USING ((EXISTS ( SELECT 1
   FROM "public"."media_comments" "c"
  WHERE (("c"."id" = "comment_attachments"."comment_id") AND "public"."can_access_media_comments"("c"."media_type", "c"."tmdb_id", "c"."season_number", "c"."episode_number")))));



CREATE POLICY "Read unlocked comments" ON "public"."media_comments" FOR SELECT TO "authenticated" USING ("public"."can_access_media_comments"("media_type", "tmdb_id", "season_number", "episode_number"));



CREATE POLICY "Remove own likes" ON "public"."comment_likes" FOR DELETE TO "authenticated" USING (("user_id" = "auth"."uid"()));



CREATE POLICY "Users can create their own activity" ON "public"."community_activity" FOR INSERT TO "authenticated" WITH CHECK (("user_id" = "auth"."uid"()));



CREATE POLICY "Users can delete own episode ratings" ON "public"."episode_ratings" FOR DELETE USING (("auth"."uid"() = "user_id"));



CREATE POLICY "Users can delete own media data" ON "public"."media_user_data" FOR DELETE TO "authenticated" USING (("auth"."uid"() = "user_id"));



CREATE POLICY "Users can delete own notifications" ON "public"."notifications" FOR DELETE TO "authenticated" USING (("auth"."uid"() = "recipient_user_id"));



CREATE POLICY "Users can delete own watched episodes" ON "public"."watched_episodes" FOR DELETE TO "authenticated" USING (("auth"."uid"() = "user_id"));



CREATE POLICY "Users can delete their own activity" ON "public"."community_activity" FOR DELETE TO "authenticated" USING (("user_id" = "auth"."uid"()));



CREATE POLICY "Users can follow from their own account" ON "public"."follows" FOR INSERT TO "authenticated" WITH CHECK (("follower_id" = "auth"."uid"()));



CREATE POLICY "Users can insert own episode ratings" ON "public"."episode_ratings" FOR INSERT WITH CHECK (("auth"."uid"() = "user_id"));



CREATE POLICY "Users can insert own media data" ON "public"."media_user_data" FOR INSERT TO "authenticated" WITH CHECK (("auth"."uid"() = "user_id"));



CREATE POLICY "Users can insert own watched episodes" ON "public"."watched_episodes" FOR INSERT TO "authenticated" WITH CHECK (("auth"."uid"() = "user_id"));



CREATE POLICY "Users can read own episode ratings" ON "public"."episode_ratings" FOR SELECT USING (("auth"."uid"() = "user_id"));



CREATE POLICY "Users can read own media data" ON "public"."media_user_data" FOR SELECT TO "authenticated" USING (("auth"."uid"() = "user_id"));



CREATE POLICY "Users can unfollow from their own account" ON "public"."follows" FOR DELETE TO "authenticated" USING (("follower_id" = "auth"."uid"()));



CREATE POLICY "Users can update own episode ratings" ON "public"."episode_ratings" FOR UPDATE USING (("auth"."uid"() = "user_id")) WITH CHECK (("auth"."uid"() = "user_id"));



CREATE POLICY "Users can update own media data" ON "public"."media_user_data" FOR UPDATE TO "authenticated" USING (("auth"."uid"() = "user_id")) WITH CHECK (("auth"."uid"() = "user_id"));



CREATE POLICY "Users can update own notifications" ON "public"."notifications" FOR UPDATE TO "authenticated" USING (("auth"."uid"() = "recipient_user_id")) WITH CHECK (("auth"."uid"() = "recipient_user_id"));



CREATE POLICY "Users can update own watched episodes" ON "public"."watched_episodes" FOR UPDATE TO "authenticated" USING (("auth"."uid"() = "user_id")) WITH CHECK (("auth"."uid"() = "user_id"));



CREATE POLICY "Users can view own notifications" ON "public"."notifications" FOR SELECT TO "authenticated" USING (("auth"."uid"() = "recipient_user_id"));



CREATE POLICY "Users can view own watched episodes" ON "public"."watched_episodes" FOR SELECT TO "authenticated" USING (("auth"."uid"() = "user_id"));



CREATE POLICY "Users can view their own and followed activity" ON "public"."community_activity" FOR SELECT TO "authenticated" USING ((("user_id" = "auth"."uid"()) OR (EXISTS ( SELECT 1
   FROM "public"."follows"
  WHERE (("follows"."follower_id" = "auth"."uid"()) AND ("follows"."following_id" = "community_activity"."user_id"))))));



CREATE POLICY "Users delete own episodes" ON "public"."watched_episodes" FOR DELETE USING (("auth"."uid"() = "user_id"));



CREATE POLICY "Users delete own library" ON "public"."library_items" FOR DELETE USING (("auth"."uid"() = "user_id"));



CREATE POLICY "Users insert own episodes" ON "public"."watched_episodes" FOR INSERT WITH CHECK (("auth"."uid"() = "user_id"));



CREATE POLICY "Users insert own library" ON "public"."library_items" FOR INSERT WITH CHECK (("auth"."uid"() = "user_id"));



CREATE POLICY "Users insert own profile" ON "public"."profiles" FOR INSERT WITH CHECK (("auth"."uid"() = "id"));



CREATE POLICY "Users read own episodes" ON "public"."watched_episodes" FOR SELECT USING (("auth"."uid"() = "user_id"));



CREATE POLICY "Users read own library" ON "public"."library_items" FOR SELECT USING (("auth"."uid"() = "user_id"));



CREATE POLICY "Users update own library" ON "public"."library_items" FOR UPDATE USING (("auth"."uid"() = "user_id"));



CREATE POLICY "Users update own profile" ON "public"."profiles" FOR UPDATE USING (("auth"."uid"() = "id"));



ALTER TABLE "public"."bug_reports" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "bug_reports_admin_update" ON "public"."bug_reports" FOR UPDATE TO "authenticated" USING ("public"."is_current_user_developer"()) WITH CHECK ("public"."is_current_user_developer"());



CREATE POLICY "bug_reports_insert_own" ON "public"."bug_reports" FOR INSERT TO "authenticated" WITH CHECK (("user_id" = "auth"."uid"()));



CREATE POLICY "bug_reports_read_own_or_developer" ON "public"."bug_reports" FOR SELECT TO "authenticated" USING ((("user_id" = "auth"."uid"()) OR "public"."is_current_user_developer"()));



ALTER TABLE "public"."chiplux_updates" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."comment_attachments" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."comment_likes" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "comment_likes_hide_blocked_users" ON "public"."comment_likes" AS RESTRICTIVE FOR SELECT TO "authenticated" USING (("public"."is_current_user_developer"() OR (NOT (EXISTS ( SELECT 1
   FROM "public"."user_blocks" "ub"
  WHERE ((("ub"."blocker_id" = "auth"."uid"()) AND ("ub"."blocked_id" = "comment_likes"."user_id")) OR (("ub"."blocker_id" = "comment_likes"."user_id") AND ("ub"."blocked_id" = "auth"."uid"()))))))));



ALTER TABLE "public"."comment_reports" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "comment_reports_admin_delete" ON "public"."comment_reports" FOR DELETE TO "authenticated" USING ("public"."is_current_user_developer"());



CREATE POLICY "comment_reports_admin_update" ON "public"."comment_reports" FOR UPDATE TO "authenticated" USING ("public"."is_current_user_developer"()) WITH CHECK ("public"."is_current_user_developer"());



CREATE POLICY "comment_reports_insert_own" ON "public"."comment_reports" FOR INSERT TO "authenticated" WITH CHECK (("reporter_id" = "auth"."uid"()));



CREATE POLICY "comment_reports_read_own_or_developer" ON "public"."comment_reports" FOR SELECT TO "authenticated" USING ((("reporter_id" = "auth"."uid"()) OR "public"."is_current_user_developer"()));



ALTER TABLE "public"."community_activity" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."daily_birthday_spotlights" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."daily_in_memoriam_spotlights" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."episode_ratings" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."feature_suggestion_comments" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "feature_suggestion_comments_select" ON "public"."feature_suggestion_comments" FOR SELECT TO "authenticated" USING (((EXISTS ( SELECT 1
   FROM "public"."feature_suggestions" "f"
  WHERE (("f"."id" = "feature_suggestion_comments"."feature_id") AND ("f"."status" <> 'pending'::"text")))) OR "public"."is_chiplux_developer"()));



ALTER TABLE "public"."feature_suggestion_likes" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "feature_suggestion_likes_select" ON "public"."feature_suggestion_likes" FOR SELECT TO "authenticated" USING (((EXISTS ( SELECT 1
   FROM "public"."feature_suggestions" "f"
  WHERE (("f"."id" = "feature_suggestion_likes"."feature_id") AND ("f"."status" <> 'pending'::"text")))) OR "public"."is_chiplux_developer"()));



ALTER TABLE "public"."feature_suggestion_submission_state" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "feature_suggestion_submission_state_select" ON "public"."feature_suggestion_submission_state" FOR SELECT TO "authenticated" USING ((("user_id" = "auth"."uid"()) OR "public"."is_chiplux_developer"()));



ALTER TABLE "public"."feature_suggestions" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "feature_suggestions_select" ON "public"."feature_suggestions" FOR SELECT TO "authenticated" USING ((("status" <> 'pending'::"text") OR ("user_id" = "auth"."uid"()) OR "public"."is_chiplux_developer"()));



ALTER TABLE "public"."follows" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."library_items" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."media_comments" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "media_comments_developer_delete" ON "public"."media_comments" FOR DELETE TO "authenticated" USING ("public"."is_current_user_developer"());



CREATE POLICY "media_comments_hide_blocked_users" ON "public"."media_comments" AS RESTRICTIVE FOR SELECT TO "authenticated" USING (("public"."is_current_user_developer"() OR (NOT (EXISTS ( SELECT 1
   FROM "public"."user_blocks" "ub"
  WHERE ((("ub"."blocker_id" = "auth"."uid"()) AND ("ub"."blocked_id" = "media_comments"."user_id")) OR (("ub"."blocker_id" = "media_comments"."user_id") AND ("ub"."blocked_id" = "auth"."uid"()))))))));



ALTER TABLE "public"."media_user_data" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."music_album_comment_likes" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "music_album_comment_likes_delete_own" ON "public"."music_album_comment_likes" FOR DELETE TO "authenticated" USING (("auth"."uid"() = "user_id"));



CREATE POLICY "music_album_comment_likes_insert_own" ON "public"."music_album_comment_likes" FOR INSERT TO "authenticated" WITH CHECK ((("auth"."uid"() = "user_id") AND (EXISTS ( SELECT 1
   FROM ("public"."music_album_comments" "mac"
     JOIN "public"."music_user_data" "mud" ON ((("mud"."user_id" = "auth"."uid"()) AND ("mud"."entity_type" = 'album'::"text") AND ("mud"."entity_id" = "mac"."album_id") AND ("mud"."is_listened" = true))))
  WHERE ("mac"."id" = "music_album_comment_likes"."comment_id")))));



CREATE POLICY "music_album_comment_likes_select_listened" ON "public"."music_album_comment_likes" FOR SELECT TO "authenticated" USING ((EXISTS ( SELECT 1
   FROM ("public"."music_album_comments" "mac"
     JOIN "public"."music_user_data" "mud" ON ((("mud"."user_id" = "auth"."uid"()) AND ("mud"."entity_type" = 'album'::"text") AND ("mud"."entity_id" = "mac"."album_id") AND ("mud"."is_listened" = true))))
  WHERE ("mac"."id" = "music_album_comment_likes"."comment_id"))));



ALTER TABLE "public"."music_album_comment_reports" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "music_album_comment_reports_insert_own" ON "public"."music_album_comment_reports" FOR INSERT TO "authenticated" WITH CHECK ((("auth"."uid"() = "reporter_id") AND (EXISTS ( SELECT 1
   FROM ("public"."music_album_comments" "mac"
     JOIN "public"."music_user_data" "mud" ON ((("mud"."user_id" = "auth"."uid"()) AND ("mud"."entity_type" = 'album'::"text") AND ("mud"."entity_id" = "mac"."album_id") AND ("mud"."is_listened" = true))))
  WHERE ("mac"."id" = "music_album_comment_reports"."comment_id")))));



CREATE POLICY "music_album_comment_reports_select_developer" ON "public"."music_album_comment_reports" FOR SELECT TO "authenticated" USING ((EXISTS ( SELECT 1
   FROM "public"."profiles" "p"
  WHERE (("p"."id" = "auth"."uid"()) AND ("p"."is_developer" = true)))));



CREATE POLICY "music_album_comment_reports_select_own" ON "public"."music_album_comment_reports" FOR SELECT TO "authenticated" USING (("auth"."uid"() = "reporter_id"));



CREATE POLICY "music_album_comment_reports_update_developer" ON "public"."music_album_comment_reports" FOR UPDATE TO "authenticated" USING ((EXISTS ( SELECT 1
   FROM "public"."profiles" "p"
  WHERE (("p"."id" = "auth"."uid"()) AND ("p"."is_developer" = true))))) WITH CHECK ((EXISTS ( SELECT 1
   FROM "public"."profiles" "p"
  WHERE (("p"."id" = "auth"."uid"()) AND ("p"."is_developer" = true)))));



CREATE POLICY "music_album_comment_reports_update_own" ON "public"."music_album_comment_reports" FOR UPDATE TO "authenticated" USING (("auth"."uid"() = "reporter_id")) WITH CHECK (("auth"."uid"() = "reporter_id"));



ALTER TABLE "public"."music_album_comments" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "music_album_comments_delete_developer" ON "public"."music_album_comments" FOR DELETE TO "authenticated" USING ((EXISTS ( SELECT 1
   FROM "public"."profiles" "p"
  WHERE (("p"."id" = "auth"."uid"()) AND ("p"."is_developer" = true)))));



CREATE POLICY "music_album_comments_delete_own" ON "public"."music_album_comments" FOR DELETE TO "authenticated" USING (("auth"."uid"() = "user_id"));



CREATE POLICY "music_album_comments_insert_listened" ON "public"."music_album_comments" FOR INSERT TO "authenticated" WITH CHECK ((("auth"."uid"() = "user_id") AND (EXISTS ( SELECT 1
   FROM "public"."music_user_data" "mud"
  WHERE (("mud"."user_id" = "auth"."uid"()) AND ("mud"."entity_type" = 'album'::"text") AND ("mud"."entity_id" = "music_album_comments"."album_id") AND ("mud"."is_listened" = true))))));



CREATE POLICY "music_album_comments_select_developer" ON "public"."music_album_comments" FOR SELECT TO "authenticated" USING ((EXISTS ( SELECT 1
   FROM "public"."profiles" "p"
  WHERE (("p"."id" = "auth"."uid"()) AND ("p"."is_developer" = true)))));



CREATE POLICY "music_album_comments_select_listened" ON "public"."music_album_comments" FOR SELECT TO "authenticated" USING ((EXISTS ( SELECT 1
   FROM "public"."music_user_data" "mud"
  WHERE (("mud"."user_id" = "auth"."uid"()) AND ("mud"."entity_type" = 'album'::"text") AND ("mud"."entity_id" = "music_album_comments"."album_id") AND ("mud"."is_listened" = true)))));



CREATE POLICY "music_album_comments_update_own" ON "public"."music_album_comments" FOR UPDATE TO "authenticated" USING (("auth"."uid"() = "user_id")) WITH CHECK ((("auth"."uid"() = "user_id") AND (EXISTS ( SELECT 1
   FROM "public"."music_user_data" "mud"
  WHERE (("mud"."user_id" = "auth"."uid"()) AND ("mud"."entity_type" = 'album'::"text") AND ("mud"."entity_id" = "music_album_comments"."album_id") AND ("mud"."is_listened" = true))))));



ALTER TABLE "public"."music_user_data" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "music_user_data_delete_own" ON "public"."music_user_data" FOR DELETE TO "authenticated" USING (("auth"."uid"() = "user_id"));



CREATE POLICY "music_user_data_insert_own" ON "public"."music_user_data" FOR INSERT TO "authenticated" WITH CHECK (("auth"."uid"() = "user_id"));



CREATE POLICY "music_user_data_select_own" ON "public"."music_user_data" FOR SELECT TO "authenticated" USING (("auth"."uid"() = "user_id"));



CREATE POLICY "music_user_data_update_own" ON "public"."music_user_data" FOR UPDATE TO "authenticated" USING (("auth"."uid"() = "user_id")) WITH CHECK (("auth"."uid"() = "user_id"));



ALTER TABLE "public"."new_episode_notification_state" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."notifications" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."profiles" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."push_device_tokens" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."release_notification_state" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."user_blocks" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "user_blocks_delete_own" ON "public"."user_blocks" FOR DELETE TO "authenticated" USING (("blocker_id" = "auth"."uid"()));



CREATE POLICY "user_blocks_insert_own" ON "public"."user_blocks" FOR INSERT TO "authenticated" WITH CHECK (("blocker_id" = "auth"."uid"()));



CREATE POLICY "user_blocks_select_own" ON "public"."user_blocks" FOR SELECT TO "authenticated" USING (("blocker_id" = "auth"."uid"()));



ALTER TABLE "public"."user_reports" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "user_reports_developer_read" ON "public"."user_reports" FOR SELECT TO "authenticated" USING ((("reporter_id" = "auth"."uid"()) OR "public"."is_current_user_developer"()));



CREATE POLICY "user_reports_developer_update" ON "public"."user_reports" FOR UPDATE TO "authenticated" USING ("public"."is_current_user_developer"()) WITH CHECK ("public"."is_current_user_developer"());



CREATE POLICY "user_reports_insert_own" ON "public"."user_reports" FOR INSERT TO "authenticated" WITH CHECK (("reporter_id" = "auth"."uid"()));



CREATE POLICY "user_reports_select_own" ON "public"."user_reports" FOR SELECT TO "authenticated" USING (("reporter_id" = "auth"."uid"()));



ALTER TABLE "public"."username_claims" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."watched_episodes" ENABLE ROW LEVEL SECURITY;




ALTER PUBLICATION "supabase_realtime" OWNER TO "postgres";






ALTER PUBLICATION "supabase_realtime" ADD TABLE ONLY "public"."comment_attachments";



ALTER PUBLICATION "supabase_realtime" ADD TABLE ONLY "public"."comment_likes";



ALTER PUBLICATION "supabase_realtime" ADD TABLE ONLY "public"."community_activity";



ALTER PUBLICATION "supabase_realtime" ADD TABLE ONLY "public"."feature_suggestion_comments";



ALTER PUBLICATION "supabase_realtime" ADD TABLE ONLY "public"."feature_suggestion_likes";



ALTER PUBLICATION "supabase_realtime" ADD TABLE ONLY "public"."feature_suggestions";



ALTER PUBLICATION "supabase_realtime" ADD TABLE ONLY "public"."follows";



ALTER PUBLICATION "supabase_realtime" ADD TABLE ONLY "public"."media_comments";



ALTER PUBLICATION "supabase_realtime" ADD TABLE ONLY "public"."music_album_comment_likes";



ALTER PUBLICATION "supabase_realtime" ADD TABLE ONLY "public"."music_album_comments";



ALTER PUBLICATION "supabase_realtime" ADD TABLE ONLY "public"."notifications";









GRANT USAGE ON SCHEMA "public" TO "postgres";
GRANT USAGE ON SCHEMA "public" TO "anon";
GRANT USAGE ON SCHEMA "public" TO "authenticated";
GRANT USAGE ON SCHEMA "public" TO "service_role";











































































































































































REVOKE ALL ON FUNCTION "public"."add_feature_suggestion_update"("p_feature_id" "uuid", "p_body" "text") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."add_feature_suggestion_update"("p_feature_id" "uuid", "p_body" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."add_feature_suggestion_update"("p_feature_id" "uuid", "p_body" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."add_feature_suggestion_update"("p_feature_id" "uuid", "p_body" "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."broadcast_chiplux_update"() TO "anon";
GRANT ALL ON FUNCTION "public"."broadcast_chiplux_update"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."broadcast_chiplux_update"() TO "service_role";



GRANT ALL ON FUNCTION "public"."can_access_media_comments"("p_media_type" "text", "p_tmdb_id" bigint, "p_season_number" integer, "p_episode_number" integer) TO "anon";
GRANT ALL ON FUNCTION "public"."can_access_media_comments"("p_media_type" "text", "p_tmdb_id" bigint, "p_season_number" integer, "p_episode_number" integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."can_access_media_comments"("p_media_type" "text", "p_tmdb_id" bigint, "p_season_number" integer, "p_episode_number" integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."can_follow_user"("p_target_user_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."can_follow_user"("p_target_user_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."can_follow_user"("p_target_user_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."can_user_follow"("p_follower_user_id" "uuid", "p_target_user_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."can_user_follow"("p_follower_user_id" "uuid", "p_target_user_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."can_user_follow"("p_follower_user_id" "uuid", "p_target_user_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."can_view_profile_details"("p_target_user_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."can_view_profile_details"("p_target_user_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."can_view_profile_details"("p_target_user_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."can_view_public_media_list"("p_target_user_id" "uuid", "p_require_ratings" boolean) TO "anon";
GRANT ALL ON FUNCTION "public"."can_view_public_media_list"("p_target_user_id" "uuid", "p_require_ratings" boolean) TO "authenticated";
GRANT ALL ON FUNCTION "public"."can_view_public_media_list"("p_target_user_id" "uuid", "p_require_ratings" boolean) TO "service_role";



GRANT ALL ON FUNCTION "public"."check_username_availability"("p_username" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."check_username_availability"("p_username" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."check_username_availability"("p_username" "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."claim_signup_username"() TO "anon";
GRANT ALL ON FUNCTION "public"."claim_signup_username"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."claim_signup_username"() TO "service_role";



GRANT ALL ON FUNCTION "public"."cleanup_after_block"() TO "anon";
GRANT ALL ON FUNCTION "public"."cleanup_after_block"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."cleanup_after_block"() TO "service_role";



REVOKE ALL ON FUNCTION "public"."count_music_album_comment_reports"("p_comment_id" "uuid", "p_report_type" "text") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."count_music_album_comment_reports"("p_comment_id" "uuid", "p_report_type" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."count_music_album_comment_reports"("p_comment_id" "uuid", "p_report_type" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."count_music_album_comment_reports"("p_comment_id" "uuid", "p_report_type" "text") TO "service_role";



REVOKE ALL ON FUNCTION "public"."count_visible_media_comments"("p_media_type" "text", "p_tmdb_id" integer, "p_season_number" integer, "p_episode_number" integer) FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."count_visible_media_comments"("p_media_type" "text", "p_tmdb_id" integer, "p_season_number" integer, "p_episode_number" integer) TO "anon";
GRANT ALL ON FUNCTION "public"."count_visible_media_comments"("p_media_type" "text", "p_tmdb_id" integer, "p_season_number" integer, "p_episode_number" integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."count_visible_media_comments"("p_media_type" "text", "p_tmdb_id" integer, "p_season_number" integer, "p_episode_number" integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."create_achievement_notification"() TO "anon";
GRANT ALL ON FUNCTION "public"."create_achievement_notification"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."create_achievement_notification"() TO "service_role";



GRANT ALL ON FUNCTION "public"."create_comment_like_milestone_notification"() TO "anon";
GRANT ALL ON FUNCTION "public"."create_comment_like_milestone_notification"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."create_comment_like_milestone_notification"() TO "service_role";



GRANT ALL ON FUNCTION "public"."create_comment_reply_notification"() TO "anon";
GRANT ALL ON FUNCTION "public"."create_comment_reply_notification"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."create_comment_reply_notification"() TO "service_role";



GRANT ALL ON FUNCTION "public"."create_new_follower_notification"() TO "anon";
GRANT ALL ON FUNCTION "public"."create_new_follower_notification"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."create_new_follower_notification"() TO "service_role";



REVOKE ALL ON FUNCTION "public"."delete_my_account"() FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."delete_my_account"() TO "anon";
GRANT ALL ON FUNCTION "public"."delete_my_account"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."delete_my_account"() TO "service_role";



GRANT ALL ON FUNCTION "public"."enforce_comment_like_privacy"() TO "anon";
GRANT ALL ON FUNCTION "public"."enforce_comment_like_privacy"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."enforce_comment_like_privacy"() TO "service_role";



GRANT ALL ON FUNCTION "public"."enforce_comment_reply_privacy"() TO "anon";
GRANT ALL ON FUNCTION "public"."enforce_comment_reply_privacy"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."enforce_comment_reply_privacy"() TO "service_role";



GRANT ALL ON FUNCTION "public"."enforce_follow_privacy"() TO "anon";
GRANT ALL ON FUNCTION "public"."enforce_follow_privacy"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."enforce_follow_privacy"() TO "service_role";



REVOKE ALL ON FUNCTION "public"."get_chiplux_average_rating"("p_media_type" "text", "p_tmdb_id" bigint, "p_season_number" integer, "p_episode_number" integer) FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."get_chiplux_average_rating"("p_media_type" "text", "p_tmdb_id" bigint, "p_season_number" integer, "p_episode_number" integer) TO "anon";
GRANT ALL ON FUNCTION "public"."get_chiplux_average_rating"("p_media_type" "text", "p_tmdb_id" bigint, "p_season_number" integer, "p_episode_number" integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_chiplux_average_rating"("p_media_type" "text", "p_tmdb_id" bigint, "p_season_number" integer, "p_episode_number" integer) TO "service_role";



REVOKE ALL ON FUNCTION "public"."get_developer_profile_id"() FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."get_developer_profile_id"() TO "anon";
GRANT ALL ON FUNCTION "public"."get_developer_profile_id"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_developer_profile_id"() TO "service_role";



REVOKE ALL ON FUNCTION "public"."get_feature_suggestion_submission_status"() FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."get_feature_suggestion_submission_status"() TO "anon";
GRANT ALL ON FUNCTION "public"."get_feature_suggestion_submission_status"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_feature_suggestion_submission_status"() TO "service_role";



REVOKE ALL ON FUNCTION "public"."get_public_completed_tv_shows"("p_user_id" "uuid", "p_sort_rated" boolean) FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."get_public_completed_tv_shows"("p_user_id" "uuid", "p_sort_rated" boolean) TO "anon";
GRANT ALL ON FUNCTION "public"."get_public_completed_tv_shows"("p_user_id" "uuid", "p_sort_rated" boolean) TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_public_completed_tv_shows"("p_user_id" "uuid", "p_sort_rated" boolean) TO "service_role";



GRANT ALL ON FUNCTION "public"."get_public_profile"("p_user_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."get_public_profile"("p_user_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_public_profile"("p_user_id" "uuid") TO "service_role";



REVOKE ALL ON FUNCTION "public"."get_public_watched_movies"("p_user_id" "uuid", "p_sort_rated" boolean) FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."get_public_watched_movies"("p_user_id" "uuid", "p_sort_rated" boolean) TO "anon";
GRANT ALL ON FUNCTION "public"."get_public_watched_movies"("p_user_id" "uuid", "p_sort_rated" boolean) TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_public_watched_movies"("p_user_id" "uuid", "p_sort_rated" boolean) TO "service_role";



GRANT ALL ON TABLE "public"."community_activity" TO "anon";
GRANT ALL ON TABLE "public"."community_activity" TO "authenticated";
GRANT ALL ON TABLE "public"."community_activity" TO "service_role";



GRANT ALL ON FUNCTION "public"."get_visible_community_activity"("p_limit" integer) TO "anon";
GRANT ALL ON FUNCTION "public"."get_visible_community_activity"("p_limit" integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_visible_community_activity"("p_limit" integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."get_visible_followers"("p_user_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."get_visible_followers"("p_user_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_visible_followers"("p_user_id" "uuid") TO "service_role";



REVOKE ALL ON FUNCTION "public"."get_visible_media_comments"("p_media_type" "text", "p_tmdb_id" integer, "p_season_number" integer, "p_episode_number" integer) FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."get_visible_media_comments"("p_media_type" "text", "p_tmdb_id" integer, "p_season_number" integer, "p_episode_number" integer) TO "anon";
GRANT ALL ON FUNCTION "public"."get_visible_media_comments"("p_media_type" "text", "p_tmdb_id" integer, "p_season_number" integer, "p_episode_number" integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_visible_media_comments"("p_media_type" "text", "p_tmdb_id" integer, "p_season_number" integer, "p_episode_number" integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."handle_new_user"() TO "anon";
GRANT ALL ON FUNCTION "public"."handle_new_user"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."handle_new_user"() TO "service_role";



REVOKE ALL ON FUNCTION "public"."ignore_feature_suggestion"("p_feature_id" "uuid") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."ignore_feature_suggestion"("p_feature_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."ignore_feature_suggestion"("p_feature_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."ignore_feature_suggestion"("p_feature_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."is_blocked_between"("p_user_a" "uuid", "p_user_b" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."is_blocked_between"("p_user_a" "uuid", "p_user_b" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."is_blocked_between"("p_user_a" "uuid", "p_user_b" "uuid") TO "service_role";



REVOKE ALL ON FUNCTION "public"."is_chiplux_developer"() FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."is_chiplux_developer"() TO "anon";
GRANT ALL ON FUNCTION "public"."is_chiplux_developer"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."is_chiplux_developer"() TO "service_role";



REVOKE ALL ON FUNCTION "public"."is_current_user_developer"() FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."is_current_user_developer"() TO "anon";
GRANT ALL ON FUNCTION "public"."is_current_user_developer"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."is_current_user_developer"() TO "service_role";



GRANT ALL ON FUNCTION "public"."protect_developer_flag"() TO "anon";
GRANT ALL ON FUNCTION "public"."protect_developer_flag"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."protect_developer_flag"() TO "service_role";



GRANT ALL ON FUNCTION "public"."record_daily_login"() TO "anon";
GRANT ALL ON FUNCTION "public"."record_daily_login"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."record_daily_login"() TO "service_role";



GRANT ALL ON FUNCTION "public"."record_public_profile_view"("viewed_user_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."record_public_profile_view"("viewed_user_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."record_public_profile_view"("viewed_user_id" "uuid") TO "service_role";



REVOKE ALL ON FUNCTION "public"."register_push_token"("p_token" "text", "p_platform" "text") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."register_push_token"("p_token" "text", "p_platform" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."register_push_token"("p_token" "text", "p_platform" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."register_push_token"("p_token" "text", "p_platform" "text") TO "service_role";



REVOKE ALL ON FUNCTION "public"."report_comment"("p_comment_id" "text", "p_report_type" "text", "p_details" "text") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."report_comment"("p_comment_id" "text", "p_report_type" "text", "p_details" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."report_comment"("p_comment_id" "text", "p_report_type" "text", "p_details" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."report_comment"("p_comment_id" "text", "p_report_type" "text", "p_details" "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."search_visible_profiles"("p_query" "text", "p_limit" integer) TO "anon";
GRANT ALL ON FUNCTION "public"."search_visible_profiles"("p_query" "text", "p_limit" integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."search_visible_profiles"("p_query" "text", "p_limit" integer) TO "service_role";



REVOKE ALL ON FUNCTION "public"."set_feature_suggestion_status"("p_feature_id" "uuid", "p_status" "text", "p_note" "text") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."set_feature_suggestion_status"("p_feature_id" "uuid", "p_status" "text", "p_note" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."set_feature_suggestion_status"("p_feature_id" "uuid", "p_status" "text", "p_note" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."set_feature_suggestion_status"("p_feature_id" "uuid", "p_status" "text", "p_note" "text") TO "service_role";



REVOKE ALL ON FUNCTION "public"."submit_feature_suggestion"("p_title" "text", "p_description" "text", "p_public_attribution" boolean) FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."submit_feature_suggestion"("p_title" "text", "p_description" "text", "p_public_attribution" boolean) TO "anon";
GRANT ALL ON FUNCTION "public"."submit_feature_suggestion"("p_title" "text", "p_description" "text", "p_public_attribution" boolean) TO "authenticated";
GRANT ALL ON FUNCTION "public"."submit_feature_suggestion"("p_title" "text", "p_description" "text", "p_public_attribution" boolean) TO "service_role";



GRANT ALL ON FUNCTION "public"."suppress_blocked_notification"() TO "anon";
GRANT ALL ON FUNCTION "public"."suppress_blocked_notification"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."suppress_blocked_notification"() TO "service_role";



GRANT ALL ON FUNCTION "public"."sync_profile_username_claim"() TO "anon";
GRANT ALL ON FUNCTION "public"."sync_profile_username_claim"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."sync_profile_username_claim"() TO "service_role";



REVOKE ALL ON FUNCTION "public"."toggle_feature_suggestion_like"("p_feature_id" "uuid") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."toggle_feature_suggestion_like"("p_feature_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."toggle_feature_suggestion_like"("p_feature_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."toggle_feature_suggestion_like"("p_feature_id" "uuid") TO "service_role";



REVOKE ALL ON FUNCTION "public"."unregister_push_token"("p_token" "text") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."unregister_push_token"("p_token" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."unregister_push_token"("p_token" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."unregister_push_token"("p_token" "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."validate_follow_developer_achievement"() TO "anon";
GRANT ALL ON FUNCTION "public"."validate_follow_developer_achievement"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."validate_follow_developer_achievement"() TO "service_role";



GRANT ALL ON FUNCTION "public"."validate_music_album_comment_parent"() TO "anon";
GRANT ALL ON FUNCTION "public"."validate_music_album_comment_parent"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."validate_music_album_comment_parent"() TO "service_role";
























GRANT ALL ON TABLE "public"."bug_reports" TO "anon";
GRANT ALL ON TABLE "public"."bug_reports" TO "authenticated";
GRANT ALL ON TABLE "public"."bug_reports" TO "service_role";



GRANT ALL ON SEQUENCE "public"."bug_reports_id_seq" TO "anon";
GRANT ALL ON SEQUENCE "public"."bug_reports_id_seq" TO "authenticated";
GRANT ALL ON SEQUENCE "public"."bug_reports_id_seq" TO "service_role";



GRANT ALL ON TABLE "public"."chiplux_updates" TO "anon";
GRANT ALL ON TABLE "public"."chiplux_updates" TO "authenticated";
GRANT ALL ON TABLE "public"."chiplux_updates" TO "service_role";



GRANT ALL ON TABLE "public"."comment_attachments" TO "anon";
GRANT ALL ON TABLE "public"."comment_attachments" TO "authenticated";
GRANT ALL ON TABLE "public"."comment_attachments" TO "service_role";



GRANT ALL ON TABLE "public"."comment_likes" TO "anon";
GRANT ALL ON TABLE "public"."comment_likes" TO "authenticated";
GRANT ALL ON TABLE "public"."comment_likes" TO "service_role";



GRANT ALL ON TABLE "public"."comment_reports" TO "anon";
GRANT ALL ON TABLE "public"."comment_reports" TO "authenticated";
GRANT ALL ON TABLE "public"."comment_reports" TO "service_role";



GRANT ALL ON SEQUENCE "public"."comment_reports_id_seq" TO "anon";
GRANT ALL ON SEQUENCE "public"."comment_reports_id_seq" TO "authenticated";
GRANT ALL ON SEQUENCE "public"."comment_reports_id_seq" TO "service_role";



GRANT ALL ON SEQUENCE "public"."community_activity_id_seq" TO "anon";
GRANT ALL ON SEQUENCE "public"."community_activity_id_seq" TO "authenticated";
GRANT ALL ON SEQUENCE "public"."community_activity_id_seq" TO "service_role";



GRANT ALL ON TABLE "public"."daily_birthday_spotlights" TO "anon";
GRANT ALL ON TABLE "public"."daily_birthday_spotlights" TO "authenticated";
GRANT ALL ON TABLE "public"."daily_birthday_spotlights" TO "service_role";



GRANT ALL ON TABLE "public"."daily_in_memoriam_spotlights" TO "anon";
GRANT ALL ON TABLE "public"."daily_in_memoriam_spotlights" TO "authenticated";
GRANT ALL ON TABLE "public"."daily_in_memoriam_spotlights" TO "service_role";



GRANT ALL ON TABLE "public"."episode_ratings" TO "anon";
GRANT ALL ON TABLE "public"."episode_ratings" TO "authenticated";
GRANT ALL ON TABLE "public"."episode_ratings" TO "service_role";



GRANT SELECT,REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."feature_suggestion_comments" TO "anon";
GRANT SELECT,REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."feature_suggestion_comments" TO "authenticated";
GRANT ALL ON TABLE "public"."feature_suggestion_comments" TO "service_role";



GRANT SELECT,REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."feature_suggestion_likes" TO "anon";
GRANT SELECT,REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."feature_suggestion_likes" TO "authenticated";
GRANT ALL ON TABLE "public"."feature_suggestion_likes" TO "service_role";



GRANT SELECT,REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."feature_suggestion_submission_state" TO "anon";
GRANT SELECT,REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."feature_suggestion_submission_state" TO "authenticated";
GRANT ALL ON TABLE "public"."feature_suggestion_submission_state" TO "service_role";



GRANT SELECT,REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."feature_suggestions" TO "anon";
GRANT SELECT,REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."feature_suggestions" TO "authenticated";
GRANT ALL ON TABLE "public"."feature_suggestions" TO "service_role";



GRANT ALL ON TABLE "public"."follows" TO "anon";
GRANT ALL ON TABLE "public"."follows" TO "authenticated";
GRANT ALL ON TABLE "public"."follows" TO "service_role";



GRANT ALL ON TABLE "public"."library_items" TO "anon";
GRANT ALL ON TABLE "public"."library_items" TO "authenticated";
GRANT ALL ON TABLE "public"."library_items" TO "service_role";



GRANT ALL ON TABLE "public"."media_comments" TO "anon";
GRANT ALL ON TABLE "public"."media_comments" TO "authenticated";
GRANT ALL ON TABLE "public"."media_comments" TO "service_role";



GRANT ALL ON TABLE "public"."media_user_data" TO "anon";
GRANT ALL ON TABLE "public"."media_user_data" TO "authenticated";
GRANT ALL ON TABLE "public"."media_user_data" TO "service_role";



GRANT ALL ON TABLE "public"."music_album_comment_likes" TO "anon";
GRANT ALL ON TABLE "public"."music_album_comment_likes" TO "authenticated";
GRANT ALL ON TABLE "public"."music_album_comment_likes" TO "service_role";



GRANT ALL ON TABLE "public"."music_album_comment_reports" TO "anon";
GRANT ALL ON TABLE "public"."music_album_comment_reports" TO "authenticated";
GRANT ALL ON TABLE "public"."music_album_comment_reports" TO "service_role";



GRANT ALL ON SEQUENCE "public"."music_album_comment_reports_id_seq" TO "anon";
GRANT ALL ON SEQUENCE "public"."music_album_comment_reports_id_seq" TO "authenticated";
GRANT ALL ON SEQUENCE "public"."music_album_comment_reports_id_seq" TO "service_role";



GRANT ALL ON TABLE "public"."music_album_comments" TO "anon";
GRANT ALL ON TABLE "public"."music_album_comments" TO "authenticated";
GRANT ALL ON TABLE "public"."music_album_comments" TO "service_role";



GRANT ALL ON TABLE "public"."music_user_data" TO "anon";
GRANT ALL ON TABLE "public"."music_user_data" TO "authenticated";
GRANT ALL ON TABLE "public"."music_user_data" TO "service_role";



GRANT ALL ON TABLE "public"."new_episode_notification_state" TO "anon";
GRANT ALL ON TABLE "public"."new_episode_notification_state" TO "authenticated";
GRANT ALL ON TABLE "public"."new_episode_notification_state" TO "service_role";



GRANT ALL ON TABLE "public"."notifications" TO "anon";
GRANT ALL ON TABLE "public"."notifications" TO "authenticated";
GRANT ALL ON TABLE "public"."notifications" TO "service_role";



GRANT ALL ON TABLE "public"."profiles" TO "anon";
GRANT ALL ON TABLE "public"."profiles" TO "authenticated";
GRANT ALL ON TABLE "public"."profiles" TO "service_role";



GRANT ALL ON TABLE "public"."push_device_tokens" TO "anon";
GRANT ALL ON TABLE "public"."push_device_tokens" TO "authenticated";
GRANT ALL ON TABLE "public"."push_device_tokens" TO "service_role";



GRANT ALL ON TABLE "public"."release_notification_state" TO "anon";
GRANT ALL ON TABLE "public"."release_notification_state" TO "authenticated";
GRANT ALL ON TABLE "public"."release_notification_state" TO "service_role";



GRANT ALL ON TABLE "public"."user_blocks" TO "anon";
GRANT ALL ON TABLE "public"."user_blocks" TO "authenticated";
GRANT ALL ON TABLE "public"."user_blocks" TO "service_role";



GRANT ALL ON TABLE "public"."user_reports" TO "anon";
GRANT ALL ON TABLE "public"."user_reports" TO "authenticated";
GRANT ALL ON TABLE "public"."user_reports" TO "service_role";



GRANT ALL ON SEQUENCE "public"."user_reports_id_seq" TO "anon";
GRANT ALL ON SEQUENCE "public"."user_reports_id_seq" TO "authenticated";
GRANT ALL ON SEQUENCE "public"."user_reports_id_seq" TO "service_role";



GRANT ALL ON TABLE "public"."username_claims" TO "anon";
GRANT ALL ON TABLE "public"."username_claims" TO "authenticated";
GRANT ALL ON TABLE "public"."username_claims" TO "service_role";



GRANT ALL ON TABLE "public"."watched_episodes" TO "anon";
GRANT ALL ON TABLE "public"."watched_episodes" TO "authenticated";
GRANT ALL ON TABLE "public"."watched_episodes" TO "service_role";









ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES TO "postgres";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES TO "anon";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES TO "authenticated";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES TO "service_role";






ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS TO "postgres";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS TO "anon";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS TO "authenticated";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS TO "service_role";






ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES TO "postgres";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES TO "anon";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES TO "authenticated";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES TO "service_role";































