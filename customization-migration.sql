-- Run this migration once in Supabase SQL Editor if the original schema
-- has already been applied. It adds the new profile editor appearance fields.
alter table public.profiles add column if not exists background_color text not null default '#090909';
alter table public.profiles add column if not exists card_color text not null default '#101010';
alter table public.profiles add column if not exists text_color text not null default '#f1f1ef';
alter table public.profiles add column if not exists font_style text not null default 'modern';
alter table public.profiles add column if not exists button_style text not null default 'solid';
alter table public.profiles add column if not exists layout_style text not null default 'centered';
alter table public.profiles add column if not exists show_branding boolean not null default true;
alter table public.profiles alter column accent_color set default '#f2f2f2';

-- Constrain appearance options to known values even if requests bypass the UI.
alter table public.profiles drop constraint if exists profiles_font_style_check;
alter table public.profiles add constraint profiles_font_style_check
  check (font_style in ('modern', 'mono', 'classic'));
alter table public.profiles drop constraint if exists profiles_button_style_check;
alter table public.profiles add constraint profiles_button_style_check
  check (button_style in ('solid', 'outline', 'soft'));
alter table public.profiles drop constraint if exists profiles_layout_style_check;
alter table public.profiles add constraint profiles_layout_style_check
  check (layout_style in ('centered', 'wide', 'minimal'));

-- Apply the new monochrome default to existing starter profiles only.
update public.profiles set accent_color = '#f2f2f2' where accent_color = '#c6ff4d';


-- Custom two-color gradients for the profile background and profile card.
alter table public.profiles add column if not exists gradient_enabled boolean not null default false;
alter table public.profiles add column if not exists background_gradient_start text not null default '#090909';
alter table public.profiles add column if not exists background_gradient_end text not null default '#242424';
alter table public.profiles add column if not exists card_gradient_start text not null default '#101010';
alter table public.profiles add column if not exists card_gradient_end text not null default '#202020';
alter table public.profiles add column if not exists gradient_angle integer not null default 135;
alter table public.profiles drop constraint if exists profiles_gradient_angle_check;
alter table public.profiles add constraint profiles_gradient_angle_check check (gradient_angle between 0 and 360);
