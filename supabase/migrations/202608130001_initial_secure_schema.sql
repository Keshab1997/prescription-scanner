-- Prescription Scanner — secure initial schema
-- Developer: Keshab Studios
-- Package: com.keshabstudios.prescriptionscanner
-- Run with Supabase migrations or the SQL Editor as the project owner.

begin;

create extension if not exists pgcrypto with schema extensions;

-- ---------- Enums ----------
do $$ begin
  create type public.app_role as enum ('user', 'admin', 'super_admin');
exception when duplicate_object then null; end $$;

do $$ begin
  create type public.profile_status as enum ('active', 'blocked');
exception when duplicate_object then null; end $$;

do $$ begin
  create type public.prescription_status as enum (
    'uploaded', 'queued', 'processing', 'completed', 'needs_review', 'failed'
  );
exception when duplicate_object then null; end $$;

do $$ begin
  create type public.ai_provider_type as enum ('gemini', 'openai', 'openai_compatible');
exception when duplicate_object then null; end $$;

do $$ begin
  create type public.ai_request_status as enum ('success', 'failed');
exception when duplicate_object then null; end $$;

do $$ begin
  create type public.deletion_status as enum ('pending', 'processing', 'completed', 'rejected');
exception when duplicate_object then null; end $$;

-- ---------- Core tables ----------
create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  display_name text check (display_name is null or char_length(display_name) between 1 and 80),
  role public.app_role not null default 'user',
  status public.profile_status not null default 'active',
  daily_limit_override integer check (daily_limit_override is null or daily_limit_override between 0 and 1000),
  blocked_reason text check (blocked_reason is null or char_length(blocked_reason) <= 500),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.app_settings (
  id smallint primary key default 1 check (id = 1),
  ai_enabled boolean not null default false,
  registration_enabled boolean not null default true,
  max_total_users integer not null default 10000 check (max_total_users >= 1),
  max_image_bytes bigint not null default 10485760 check (max_image_bytes between 102400 and 52428800),
  daily_ai_requests_per_user integer not null default 3 check (daily_ai_requests_per_user between 0 and 1000),
  rewarded_bonus_limit integer not null default 2 check (rewarded_bonus_limit between 0 and 100),
  global_requests_per_minute integer not null default 60 check (global_requests_per_minute between 1 and 100000),
  image_retention_days integer not null default 0 check (image_retention_days between 0 and 365),
  admob_enabled boolean not null default false,
  maintenance_mode boolean not null default false,
  updated_by uuid references public.profiles(id) on delete set null,
  updated_at timestamptz not null default now()
);

insert into public.app_settings (id)
values (1)
on conflict (id) do nothing;

create table if not exists public.ai_provider_configs (
  id uuid primary key default gen_random_uuid(),
  provider_type public.ai_provider_type not null,
  display_name text not null check (char_length(display_name) between 1 and 80),
  base_url text,
  model text not null check (char_length(model) between 1 and 160),
  vault_secret_id uuid,
  masked_key_suffix text check (masked_key_suffix is null or char_length(masked_key_suffix) <= 8),
  enabled boolean not null default false,
  is_active boolean not null default false,
  timeout_seconds integer not null default 60 check (timeout_seconds between 5 and 180),
  max_retries integer not null default 1 check (max_retries between 0 and 3),
  created_by uuid references public.profiles(id) on delete set null,
  updated_by uuid references public.profiles(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint compatible_provider_base_url check (
    provider_type <> 'openai_compatible' or base_url is not null
  )
);

create unique index if not exists one_active_ai_provider
  on public.ai_provider_configs ((is_active))
  where is_active;

insert into public.ai_provider_configs (
  provider_type, display_name, model, enabled, is_active
)
select 'gemini', 'Gemini', 'configure-in-admin-panel', false, false
where not exists (
  select 1 from public.ai_provider_configs where provider_type = 'gemini'
);

create table if not exists public.prescriptions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  storage_path text not null unique check (char_length(storage_path) between 10 and 500),
  original_filename text check (original_filename is null or char_length(original_filename) <= 255),
  mime_type text not null check (mime_type in ('image/jpeg', 'image/png', 'image/webp')),
  size_bytes bigint not null check (size_bytes > 0),
  image_hash text check (image_hash is null or char_length(image_hash) <= 128),
  status public.prescription_status not null default 'uploaded',
  provider public.ai_provider_type,
  model text check (model is null or char_length(model) <= 160),
  structured_result jsonb check (
    structured_result is null or jsonb_typeof(structured_result) = 'object'
  ),
  overall_confidence numeric(5,4) check (
    overall_confidence is null or overall_confidence between 0 and 1
  ),
  error_code text check (error_code is null or char_length(error_code) <= 80),
  image_deleted_at timestamptz,
  deletion_requested_at timestamptz,
  created_at timestamptz not null default now(),
  processing_started_at timestamptz,
  processed_at timestamptz,
  updated_at timestamptz not null default now()
);

create index if not exists prescriptions_user_created_idx
  on public.prescriptions (user_id, created_at desc);
create index if not exists prescriptions_status_idx
  on public.prescriptions (status, created_at);
create index if not exists prescriptions_pending_delete_idx
  on public.prescriptions (deletion_requested_at)
  where deletion_requested_at is not null;

create table if not exists public.prescription_medicines (
  id uuid primary key default gen_random_uuid(),
  prescription_id uuid not null references public.prescriptions(id) on delete cascade,
  position integer not null check (position between 1 and 200),
  raw_name text not null check (char_length(raw_name) between 1 and 500),
  normalized_name text check (normalized_name is null or char_length(normalized_name) <= 500),
  strength text check (strength is null or char_length(strength) <= 160),
  dosage text check (dosage is null or char_length(dosage) <= 300),
  frequency text check (frequency is null or char_length(frequency) <= 300),
  route text check (route is null or char_length(route) <= 120),
  duration text check (duration is null or char_length(duration) <= 200),
  instructions text check (instructions is null or char_length(instructions) <= 1000),
  confidence numeric(5,4) not null check (confidence between 0 and 1),
  needs_review boolean not null default false,
  created_at timestamptz not null default now(),
  unique (prescription_id, position)
);

create index if not exists medicines_prescription_idx
  on public.prescription_medicines (prescription_id, position);

create table if not exists public.daily_usage (
  user_id uuid not null references public.profiles(id) on delete cascade,
  usage_date date not null default current_date,
  request_count integer not null default 0 check (request_count >= 0),
  rewarded_bonus_count integer not null default 0 check (rewarded_bonus_count >= 0),
  successful_count integer not null default 0 check (successful_count >= 0),
  failed_count integer not null default 0 check (failed_count >= 0),
  updated_at timestamptz not null default now(),
  primary key (user_id, usage_date)
);

create table if not exists public.ai_request_logs (
  id uuid primary key default gen_random_uuid(),
  prescription_id uuid not null references public.prescriptions(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  provider public.ai_provider_type not null,
  model text not null check (char_length(model) <= 160),
  request_status public.ai_request_status not null,
  provider_status_code integer,
  latency_ms integer check (latency_ms is null or latency_ms >= 0),
  input_tokens integer check (input_tokens is null or input_tokens >= 0),
  output_tokens integer check (output_tokens is null or output_tokens >= 0),
  estimated_cost numeric(14,6) check (estimated_cost is null or estimated_cost >= 0),
  error_code text check (error_code is null or char_length(error_code) <= 80),
  created_at timestamptz not null default now()
);

create index if not exists ai_request_logs_created_idx
  on public.ai_request_logs (created_at desc);
create index if not exists ai_request_logs_user_idx
  on public.ai_request_logs (user_id, created_at desc);

create table if not exists public.consent_records (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  consent_type text not null check (
    consent_type in ('privacy', 'ai_processing', 'ads', 'terms')
  ),
  policy_version text not null check (char_length(policy_version) between 1 and 40),
  granted boolean not null,
  locale text not null default 'en',
  created_at timestamptz not null default now()
);

create index if not exists consent_records_user_idx
  on public.consent_records (user_id, consent_type, created_at desc);

create table if not exists public.account_deletion_requests (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  status public.deletion_status not null default 'pending',
  requested_at timestamptz not null default now(),
  completed_at timestamptz,
  retained_data_reason text check (
    retained_data_reason is null or char_length(retained_data_reason) <= 1000
  ),
  updated_at timestamptz not null default now()
);

create unique index if not exists one_open_account_deletion_request
  on public.account_deletion_requests (user_id)
  where status in ('pending', 'processing');

create table if not exists public.admin_audit_logs (
  id uuid primary key default gen_random_uuid(),
  actor_admin_id uuid references public.profiles(id) on delete set null,
  action text not null check (char_length(action) between 2 and 120),
  target_type text not null check (char_length(target_type) between 2 and 80),
  target_id text check (target_id is null or char_length(target_id) <= 160),
  target_user_id uuid references public.profiles(id) on delete set null,
  safe_metadata jsonb not null default '{}'::jsonb check (
    jsonb_typeof(safe_metadata) = 'object'
  ),
  created_at timestamptz not null default now()
);

create index if not exists admin_audit_created_idx
  on public.admin_audit_logs (created_at desc);

-- ---------- Trigger helpers ----------
create or replace function public.set_updated_at()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_settings public.app_settings;
  v_user_count integer;
begin
  -- Serialize registrations so the configured total-user cap cannot be raced.
  perform pg_advisory_xact_lock(hashtextextended('prescription_scanner_registration', 0));
  select * into v_settings from public.app_settings where id = 1;
  select count(*)::integer into v_user_count from public.profiles;

  if v_settings.id is not null and (
    not v_settings.registration_enabled
    or v_user_count >= v_settings.max_total_users
  ) then
    raise exception 'REGISTRATION_DISABLED_OR_LIMIT_REACHED' using errcode = 'P0001';
  end if;

  insert into public.profiles (id, display_name)
  values (
    new.id,
    nullif(left(trim(coalesce(new.raw_user_meta_data ->> 'display_name', '')), 80), '')
  )
  on conflict (id) do nothing;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- Backfill profiles if Auth users already exist.
insert into public.profiles (id, display_name)
select
  u.id,
  nullif(left(trim(coalesce(u.raw_user_meta_data ->> 'display_name', '')), 80), '')
from auth.users u
on conflict (id) do nothing;

-- Keep updated_at reliable.
do $$
declare
  table_name text;
begin
  foreach table_name in array array[
    'profiles', 'app_settings', 'ai_provider_configs', 'prescriptions',
    'daily_usage', 'account_deletion_requests'
  ] loop
    execute format('drop trigger if exists set_%I_updated_at on public.%I', table_name, table_name);
    execute format(
      'create trigger set_%I_updated_at before update on public.%I for each row execute function public.set_updated_at()',
      table_name,
      table_name
    );
  end loop;
end $$;

-- ---------- User-safe RPCs ----------
create or replace function public.update_my_profile(p_display_name text)
returns public.profiles
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user_id uuid := auth.uid();
  v_profile public.profiles;
begin
  if v_user_id is null then
    raise exception 'AUTH_REQUIRED' using errcode = '28000';
  end if;

  if nullif(trim(p_display_name), '') is null or char_length(trim(p_display_name)) > 80 then
    raise exception 'INVALID_DISPLAY_NAME' using errcode = '22023';
  end if;

  update public.profiles
  set display_name = trim(p_display_name)
  where id = v_user_id
  returning * into v_profile;

  return v_profile;
end;
$$;

create or replace function public.get_my_quota()
returns table (
  daily_limit integer,
  used integer,
  rewarded_bonus integer,
  remaining integer,
  ai_enabled boolean,
  maintenance_mode boolean
)
language sql
security definer
stable
set search_path = public
as $$
  select
    coalesce(p.daily_limit_override, s.daily_ai_requests_per_user) as daily_limit,
    coalesce(u.request_count, 0) as used,
    coalesce(u.rewarded_bonus_count, 0) as rewarded_bonus,
    greatest(
      coalesce(p.daily_limit_override, s.daily_ai_requests_per_user)
        + coalesce(u.rewarded_bonus_count, 0)
        - coalesce(u.request_count, 0),
      0
    ) as remaining,
    s.ai_enabled,
    s.maintenance_mode
  from public.profiles p
  cross join public.app_settings s
  left join public.daily_usage u
    on u.user_id = p.id and u.usage_date = current_date
  where p.id = auth.uid() and s.id = 1;
$$;

create or replace function public.create_prescription_upload(
  p_original_filename text,
  p_mime_type text,
  p_size_bytes bigint,
  p_image_hash text default null
)
returns table (prescription_id uuid, storage_path text)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user_id uuid := auth.uid();
  v_id uuid := gen_random_uuid();
  v_ext text;
  v_settings public.app_settings;
  v_profile public.profiles;
  v_limit integer;
  v_today_count integer;
begin
  if v_user_id is null then
    raise exception 'AUTH_REQUIRED' using errcode = '28000';
  end if;

  select * into v_profile from public.profiles where id = v_user_id;
  if not found or v_profile.status <> 'active' then
    raise exception 'USER_NOT_ACTIVE' using errcode = '42501';
  end if;

  select * into v_settings from public.app_settings where id = 1;
  if v_settings.maintenance_mode then
    raise exception 'MAINTENANCE_MODE' using errcode = '55000';
  end if;
  if not v_settings.ai_enabled then
    raise exception 'AI_DISABLED' using errcode = '55000';
  end if;

  if p_mime_type not in ('image/jpeg', 'image/png', 'image/webp') then
    raise exception 'UNSUPPORTED_IMAGE_TYPE' using errcode = '22023';
  end if;
  if p_size_bytes <= 0 or p_size_bytes > v_settings.max_image_bytes then
    raise exception 'IMAGE_SIZE_LIMIT' using errcode = '22023';
  end if;

  v_ext := case p_mime_type
    when 'image/jpeg' then 'jpg'
    when 'image/png' then 'png'
    when 'image/webp' then 'webp'
  end;

  v_limit := coalesce(v_profile.daily_limit_override, v_settings.daily_ai_requests_per_user);
  select greatest(
    coalesce((select request_count from public.daily_usage where user_id = v_user_id and usage_date = current_date), 0),
    coalesce((select count(*)::integer from public.prescriptions where user_id = v_user_id and created_at >= current_date), 0)
  ) into v_today_count;

  if v_today_count >= v_limit + coalesce(
    (select rewarded_bonus_count from public.daily_usage where user_id = v_user_id and usage_date = current_date),
    0
  ) then
    raise exception 'DAILY_LIMIT_REACHED' using errcode = 'P0001';
  end if;

  insert into public.prescriptions (
    id, user_id, storage_path, original_filename, mime_type, size_bytes, image_hash
  ) values (
    v_id,
    v_user_id,
    v_user_id::text || '/' || v_id::text || '/original.' || v_ext,
    left(coalesce(nullif(trim(p_original_filename), ''), 'prescription.' || v_ext), 255),
    p_mime_type,
    p_size_bytes,
    nullif(left(coalesce(p_image_hash, ''), 128), '')
  );

  return query
  select v_id, v_user_id::text || '/' || v_id::text || '/original.' || v_ext;
end;
$$;

create or replace function public.request_prescription_deletion(p_prescription_id uuid)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
begin
  update public.prescriptions
  set deletion_requested_at = now()
  where id = p_prescription_id and user_id = auth.uid();
  return found;
end;
$$;

create or replace function public.request_account_deletion()
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user_id uuid := auth.uid();
  v_request_id uuid;
begin
  if v_user_id is null then
    raise exception 'AUTH_REQUIRED' using errcode = '28000';
  end if;

  select id into v_request_id
  from public.account_deletion_requests
  where user_id = v_user_id and status in ('pending', 'processing')
  order by requested_at desc
  limit 1;

  if v_request_id is null then
    insert into public.account_deletion_requests (user_id)
    values (v_user_id)
    returning id into v_request_id;
  end if;

  return v_request_id;
end;
$$;

-- ---------- Backend-only transactional RPCs ----------
-- These are intentionally granted only to service_role. Edge Functions call them.
create or replace function public.reserve_ai_request(
  p_prescription_id uuid,
  p_provider public.ai_provider_type,
  p_model text
)
returns table (user_id uuid, storage_path text, mime_type text)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_prescription public.prescriptions;
  v_profile public.profiles;
  v_settings public.app_settings;
  v_used integer;
  v_bonus integer;
  v_limit integer;
begin
  select * into v_prescription
  from public.prescriptions
  where id = p_prescription_id
  for update;

  if not found then
    raise exception 'PRESCRIPTION_NOT_FOUND' using errcode = 'P0002';
  end if;
  if v_prescription.status not in ('uploaded', 'failed') then
    raise exception 'PRESCRIPTION_ALREADY_RESERVED' using errcode = '55000';
  end if;

  perform pg_advisory_xact_lock(
    hashtextextended(v_prescription.user_id::text || current_date::text, 0)
  );

  select * into v_profile from public.profiles where id = v_prescription.user_id;
  select * into v_settings from public.app_settings where id = 1;

  if v_profile.status <> 'active' then
    raise exception 'USER_NOT_ACTIVE' using errcode = '42501';
  end if;
  if not v_settings.ai_enabled or v_settings.maintenance_mode then
    raise exception 'AI_UNAVAILABLE' using errcode = '55000';
  end if;

  select coalesce(request_count, 0), coalesce(rewarded_bonus_count, 0)
  into v_used, v_bonus
  from public.daily_usage
  where user_id = v_prescription.user_id and usage_date = current_date;

  v_used := coalesce(v_used, 0);
  v_bonus := coalesce(v_bonus, 0);
  v_limit := coalesce(v_profile.daily_limit_override, v_settings.daily_ai_requests_per_user);

  if v_used >= v_limit + v_bonus then
    raise exception 'DAILY_LIMIT_REACHED' using errcode = 'P0001';
  end if;

  insert into public.daily_usage (user_id, usage_date, request_count)
  values (v_prescription.user_id, current_date, 1)
  on conflict (user_id, usage_date)
  do update set request_count = public.daily_usage.request_count + 1, updated_at = now();

  update public.prescriptions
  set
    status = 'processing',
    provider = p_provider,
    model = left(p_model, 160),
    processing_started_at = now(),
    error_code = null
  where id = p_prescription_id;

  return query
  select v_prescription.user_id, v_prescription.storage_path, v_prescription.mime_type;
end;
$$;

create or replace function public.finish_ai_request(
  p_prescription_id uuid,
  p_structured_result jsonb,
  p_medicines jsonb,
  p_overall_confidence numeric,
  p_needs_review boolean,
  p_latency_ms integer default null,
  p_provider_status_code integer default null,
  p_input_tokens integer default null,
  p_output_tokens integer default null,
  p_estimated_cost numeric default null
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_prescription public.prescriptions;
begin
  if jsonb_typeof(p_structured_result) is distinct from 'object'
    or jsonb_typeof(p_medicines) is distinct from 'array' then
    raise exception 'INVALID_RESULT_JSON' using errcode = '22023';
  end if;

  select * into v_prescription
  from public.prescriptions
  where id = p_prescription_id
  for update;

  if not found or v_prescription.status <> 'processing' then
    raise exception 'INVALID_PRESCRIPTION_STATE' using errcode = '55000';
  end if;

  delete from public.prescription_medicines where prescription_id = p_prescription_id;

  insert into public.prescription_medicines (
    prescription_id, position, raw_name, normalized_name, strength, dosage,
    frequency, route, duration, instructions, confidence, needs_review
  )
  select
    p_prescription_id,
    item_order::integer,
    left(coalesce(nullif(item ->> 'raw_name', ''), 'Unclear'), 500),
    nullif(left(coalesce(item ->> 'normalized_name', ''), 500), ''),
    nullif(left(coalesce(item ->> 'strength', ''), 160), ''),
    nullif(left(coalesce(item ->> 'dosage', ''), 300), ''),
    nullif(left(coalesce(item ->> 'frequency', ''), 300), ''),
    nullif(left(coalesce(item ->> 'route', ''), 120), ''),
    nullif(left(coalesce(item ->> 'duration', ''), 200), ''),
    nullif(left(coalesce(item ->> 'instructions', ''), 1000), ''),
    least(greatest(coalesce((item ->> 'confidence')::numeric, 0), 0), 1),
    coalesce((item ->> 'needs_review')::boolean, true)
  from jsonb_array_elements(p_medicines) with ordinality as items(item, item_order)
  where item_order <= 200;

  update public.prescriptions
  set
    status = case when p_needs_review then 'needs_review' else 'completed' end,
    structured_result = p_structured_result,
    overall_confidence = least(greatest(p_overall_confidence, 0), 1),
    processed_at = now(),
    error_code = null
  where id = p_prescription_id;

  update public.daily_usage
  set successful_count = successful_count + 1, updated_at = now()
  where user_id = v_prescription.user_id and usage_date = current_date;

  insert into public.ai_request_logs (
    prescription_id, user_id, provider, model, request_status,
    provider_status_code, latency_ms, input_tokens, output_tokens, estimated_cost
  ) values (
    p_prescription_id,
    v_prescription.user_id,
    v_prescription.provider,
    coalesce(v_prescription.model, 'unknown'),
    'success',
    p_provider_status_code,
    p_latency_ms,
    p_input_tokens,
    p_output_tokens,
    p_estimated_cost
  );
end;
$$;

create or replace function public.fail_ai_request(
  p_prescription_id uuid,
  p_error_code text,
  p_latency_ms integer default null,
  p_provider_status_code integer default null
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_prescription public.prescriptions;
begin
  select * into v_prescription
  from public.prescriptions
  where id = p_prescription_id
  for update;

  if not found then
    raise exception 'PRESCRIPTION_NOT_FOUND' using errcode = 'P0002';
  end if;

  update public.prescriptions
  set status = 'failed', error_code = left(p_error_code, 80), processed_at = now()
  where id = p_prescription_id;

  update public.daily_usage
  set failed_count = failed_count + 1, updated_at = now()
  where user_id = v_prescription.user_id and usage_date = current_date;

  insert into public.ai_request_logs (
    prescription_id, user_id, provider, model, request_status,
    provider_status_code, latency_ms, error_code
  ) values (
    p_prescription_id,
    v_prescription.user_id,
    coalesce(v_prescription.provider, 'gemini'),
    coalesce(v_prescription.model, 'unknown'),
    'failed',
    p_provider_status_code,
    p_latency_ms,
    left(p_error_code, 80)
  );
end;
$$;

create or replace function public.mark_prescription_image_deleted(p_prescription_id uuid)
returns void
language sql
security definer
set search_path = public
as $$
  update public.prescriptions
  set image_deleted_at = coalesce(image_deleted_at, now())
  where id = p_prescription_id;
$$;

create or replace function public.credit_rewarded_bonus(p_user_id uuid)
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  v_cap integer;
  v_value integer;
begin
  select rewarded_bonus_limit into v_cap from public.app_settings where id = 1;
  insert into public.daily_usage (user_id, usage_date, rewarded_bonus_count)
  values (p_user_id, current_date, 1)
  on conflict (user_id, usage_date)
  do update set
    rewarded_bonus_count = least(public.daily_usage.rewarded_bonus_count + 1, v_cap),
    updated_at = now()
  returning rewarded_bonus_count into v_value;
  return v_value;
end;
$$;

-- ---------- Row Level Security ----------
alter table public.profiles enable row level security;
alter table public.app_settings enable row level security;
alter table public.ai_provider_configs enable row level security;
alter table public.prescriptions enable row level security;
alter table public.prescription_medicines enable row level security;
alter table public.daily_usage enable row level security;
alter table public.ai_request_logs enable row level security;
alter table public.consent_records enable row level security;
alter table public.account_deletion_requests enable row level security;
alter table public.admin_audit_logs enable row level security;

-- Users can read only their own safe records.
drop policy if exists profiles_select_own on public.profiles;
create policy profiles_select_own on public.profiles
  for select to authenticated
  using (id = auth.uid());

drop policy if exists prescriptions_select_own on public.prescriptions;
create policy prescriptions_select_own on public.prescriptions
  for select to authenticated
  using (user_id = auth.uid());

drop policy if exists medicines_select_own on public.prescription_medicines;
create policy medicines_select_own on public.prescription_medicines
  for select to authenticated
  using (
    exists (
      select 1 from public.prescriptions p
      where p.id = prescription_id and p.user_id = auth.uid()
    )
  );

drop policy if exists daily_usage_select_own on public.daily_usage;
create policy daily_usage_select_own on public.daily_usage
  for select to authenticated
  using (user_id = auth.uid());

drop policy if exists consent_select_own on public.consent_records;
create policy consent_select_own on public.consent_records
  for select to authenticated
  using (user_id = auth.uid());

drop policy if exists consent_insert_own on public.consent_records;
create policy consent_insert_own on public.consent_records
  for insert to authenticated
  with check (user_id = auth.uid());

drop policy if exists deletion_request_select_own on public.account_deletion_requests;
create policy deletion_request_select_own on public.account_deletion_requests
  for select to authenticated
  using (user_id = auth.uid());

-- Explicit least-privilege table grants. RLS still applies.
revoke all on all tables in schema public from anon;
revoke all on public.profiles, public.app_settings, public.ai_provider_configs,
  public.prescriptions, public.prescription_medicines, public.daily_usage,
  public.ai_request_logs, public.consent_records, public.account_deletion_requests,
  public.admin_audit_logs from authenticated;

grant select on public.profiles, public.prescriptions, public.prescription_medicines,
  public.daily_usage, public.consent_records, public.account_deletion_requests
  to authenticated;
grant insert on public.consent_records to authenticated;

-- Function privileges.
revoke execute on function public.update_my_profile(text) from public, anon;
revoke execute on function public.get_my_quota() from public, anon;
revoke execute on function public.create_prescription_upload(text, text, bigint, text) from public, anon;
revoke execute on function public.request_prescription_deletion(uuid) from public, anon;
revoke execute on function public.request_account_deletion() from public, anon;

grant execute on function public.update_my_profile(text) to authenticated;
grant execute on function public.get_my_quota() to authenticated;
grant execute on function public.create_prescription_upload(text, text, bigint, text) to authenticated;
grant execute on function public.request_prescription_deletion(uuid) to authenticated;
grant execute on function public.request_account_deletion() to authenticated;

revoke execute on function public.reserve_ai_request(uuid, public.ai_provider_type, text) from public, anon, authenticated;
revoke execute on function public.finish_ai_request(uuid, jsonb, jsonb, numeric, boolean, integer, integer, integer, integer, numeric) from public, anon, authenticated;
revoke execute on function public.fail_ai_request(uuid, text, integer, integer) from public, anon, authenticated;
revoke execute on function public.mark_prescription_image_deleted(uuid) from public, anon, authenticated;
revoke execute on function public.credit_rewarded_bonus(uuid) from public, anon, authenticated;

grant execute on function public.reserve_ai_request(uuid, public.ai_provider_type, text) to service_role;
grant execute on function public.finish_ai_request(uuid, jsonb, jsonb, numeric, boolean, integer, integer, integer, integer, numeric) to service_role;
grant execute on function public.fail_ai_request(uuid, text, integer, integer) to service_role;
grant execute on function public.mark_prescription_image_deleted(uuid) to service_role;
grant execute on function public.credit_rewarded_bonus(uuid) to service_role;

-- ---------- Private Storage bucket ----------
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'prescriptions',
  'prescriptions',
  false,
  10485760,
  array['image/jpeg', 'image/png', 'image/webp']
)
on conflict (id) do update set
  public = false,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

-- Path format: {auth.uid()}/{prescription_id}/original.ext
drop policy if exists prescription_storage_insert_own on storage.objects;
create policy prescription_storage_insert_own on storage.objects
  for insert to authenticated
  with check (
    bucket_id = 'prescriptions'
    and (storage.foldername(name))[1] = auth.uid()::text
    and exists (
      select 1 from public.prescriptions p
      where p.user_id = auth.uid()
        and p.storage_path = name
        and p.status = 'uploaded'
    )
  );

drop policy if exists prescription_storage_select_own on storage.objects;
create policy prescription_storage_select_own on storage.objects
  for select to authenticated
  using (
    bucket_id = 'prescriptions'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

drop policy if exists prescription_storage_delete_own on storage.objects;
create policy prescription_storage_delete_own on storage.objects
  for delete to authenticated
  using (
    bucket_id = 'prescriptions'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

commit;
