-- BadLuckDept complete Supabase schema repair
-- Run in Supabase Dashboard > SQL Editor.
-- This script does not drop or rename existing tables or delete user data.

begin;

create extension if not exists pgcrypto;

-- Main public profile table. If it does not exist, this creates it.
create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  username text not null unique,
  display_name text not null default '',
  bio text not null default '',
  avatar_url text not null default '',
  banner_url text not null default '',
  accent_color text not null default '#f2f2f2',
  background_color text not null default '#090909',
  card_color text not null default '#101010',
  text_color text not null default '#f1f1ef',
  font_style text not null default 'modern',
  button_style text not null default 'solid',
  layout_style text not null default 'centered',
  show_branding boolean not null default true,
  gradient_enabled boolean not null default false,
  background_gradient_start text not null default '#090909',
  background_gradient_end text not null default '#242424',
  card_gradient_start text not null default '#101010',
  card_gradient_end text not null default '#202020',
  gradient_angle integer not null default 135,
  created_at timestamptz not null default now(),
  constraint username_format check (username ~ '^[a-z0-9_]{3,24}$'),
  constraint bio_length check (char_length(bio) <= 180),
  constraint display_name_length check (char_length(display_name) <= 40),
  constraint profiles_font_style_check check (font_style in ('modern','mono','classic')),
  constraint profiles_button_style_check check (button_style in ('solid','outline','soft')),
  constraint profiles_layout_style_check check (layout_style in ('centered','wide','minimal')),
  constraint profiles_gradient_angle_check check (gradient_angle between 0 and 360)
);

-- Ensure all current editor fields exist if profiles was created by an older schema.
alter table public.profiles add column if not exists display_name text not null default '';
alter table public.profiles add column if not exists bio text not null default '';
alter table public.profiles add column if not exists avatar_url text not null default '';
alter table public.profiles add column if not exists banner_url text not null default '';
alter table public.profiles add column if not exists accent_color text not null default '#f2f2f2';
alter table public.profiles add column if not exists background_color text not null default '#090909';
alter table public.profiles add column if not exists card_color text not null default '#101010';
alter table public.profiles add column if not exists text_color text not null default '#f1f1ef';
alter table public.profiles add column if not exists font_style text not null default 'modern';
alter table public.profiles add column if not exists button_style text not null default 'solid';
alter table public.profiles add column if not exists layout_style text not null default 'centered';
alter table public.profiles add column if not exists show_branding boolean not null default true;
alter table public.profiles add column if not exists gradient_enabled boolean not null default false;
alter table public.profiles add column if not exists background_gradient_start text not null default '#090909';
alter table public.profiles add column if not exists background_gradient_end text not null default '#242424';
alter table public.profiles add column if not exists card_gradient_start text not null default '#101010';
alter table public.profiles add column if not exists card_gradient_end text not null default '#202020';
alter table public.profiles add column if not exists gradient_angle integer not null default 135;

-- Link table used by the editor and public profile pages.
create table if not exists public.profile_links (
  id uuid primary key default gen_random_uuid(),
  profile_id uuid not null references public.profiles(id) on delete cascade,
  title text not null default 'New link',
  url text not null default 'https://',
  sort_order integer not null default 0,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  constraint link_title_length check (char_length(title) <= 60),
  constraint link_url_length check (char_length(url) <= 2048)
);

create index if not exists profile_links_profile_order_idx
  on public.profile_links(profile_id, sort_order);

-- Enable row-level security.
alter table public.profiles enable row level security;
alter table public.profile_links enable row level security;

-- Drop/recreate these named policies so this script can be rerun safely.
drop policy if exists "Profiles are publicly readable" on public.profiles;
drop policy if exists "Users can create their own profile" on public.profiles;
drop policy if exists "Users can update their own profile" on public.profiles;
drop policy if exists "Public can read active links" on public.profile_links;
drop policy if exists "Users can add links to their own profile" on public.profile_links;
drop policy if exists "Users can update links on their own profile" on public.profile_links;
drop policy if exists "Users can delete links on their own profile" on public.profile_links;

create policy "Profiles are publicly readable"
  on public.profiles for select
  using (true);

create policy "Users can create their own profile"
  on public.profiles for insert to authenticated
  with check (auth.uid() = id);

create policy "Users can update their own profile"
  on public.profiles for update to authenticated
  using (auth.uid() = id)
  with check (auth.uid() = id);

create policy "Public can read active links"
  on public.profile_links for select
  using (is_active = true or auth.uid() = profile_id);

create policy "Users can add links to their own profile"
  on public.profile_links for insert to authenticated
  with check (auth.uid() = profile_id);

create policy "Users can update links on their own profile"
  on public.profile_links for update to authenticated
  using (auth.uid() = profile_id)
  with check (auth.uid() = profile_id);

create policy "Users can delete links on their own profile"
  on public.profile_links for delete to authenticated
  using (auth.uid() = profile_id);

-- Create a profile automatically when someone signs up with a valid username.
-- The frontend must pass { username: "their_username" } as signup user metadata.
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  chosen_username text;
begin
  chosen_username := lower(coalesce(new.raw_user_meta_data ->> 'username', ''));

  if chosen_username !~ '^[a-z0-9_]{3,24}$' then
    raise exception 'Invalid username. Use 3-24 lowercase letters, numbers, or underscores.';
  end if;

  insert into public.profiles (id, username, display_name)
  values (new.id, chosen_username, chosen_username);

  return new;
end;
$$;

drop trigger if exists on_auth_user_created_profile on auth.users;
create trigger on_auth_user_created_profile
after insert on auth.users
for each row execute function public.handle_new_user();

-- Restore profiles for existing auth users when their stored username is valid.
-- Conflicts are skipped safely rather than overwriting any existing profile.
insert into public.profiles (id, username, display_name)
select
  u.id,
  lower(u.raw_user_meta_data ->> 'username'),
  lower(u.raw_user_meta_data ->> 'username')
from auth.users u
where coalesce(u.raw_user_meta_data ->> 'username', '') ~ '^[a-zA-Z0-9_]{3,24}$'
on conflict do nothing;

commit;

-- Verify after running:
-- select to_regclass('public.profiles'), to_regclass('public.profile_links');
