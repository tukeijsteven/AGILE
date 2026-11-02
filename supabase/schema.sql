-- Church Registration System Database Schema
-- Run this in the Supabase SQL Editor.

create extension if not exists pgcrypto;

create table if not exists public.churches (
    id uuid primary key default gen_random_uuid(),
    name text not null unique,
    location text not null,
    website text,
    image_url text,
    created_at timestamptz not null default now()
);

create table if not exists public.users (
    id uuid primary key default gen_random_uuid(),
    church_id uuid references public.churches(id) on delete cascade,
    name text not null,
    email text not null unique,
    password_hash text,
    phone text,
    role text not null default 'member' check (role in ('member', 'organizer', 'admin')),
    created_at timestamptz not null default now()
);

create table if not exists public.events (
    id uuid primary key default gen_random_uuid(),
    church_id uuid not null references public.churches(id) on delete cascade,
    title text not null,
    event_datetime timestamptz,
    venue text not null,
    description text not null,
    image_url text,
    created_by uuid not null references public.users(id) on delete cascade,
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now()
);

create table if not exists public.registrations (
    id uuid primary key default gen_random_uuid(),
    event_id uuid not null references public.events(id) on delete cascade,
    user_id uuid not null references public.users(id) on delete cascade,
    registered_at timestamptz not null default now(),
    unique (event_id, user_id)
);

create or replace function public.set_updated_at()
returns trigger as $$
begin
    new.updated_at = now();
    return new;
end;
$$ language plpgsql;

create trigger events_set_updated_at
before update on public.events
for each row
execute function public.set_updated_at();

create index if not exists idx_churches_name on public.churches(name);
create index if not exists idx_users_church_id on public.users(church_id);
create index if not exists idx_users_email on public.users(email);
create index if not exists idx_events_church_id on public.events(church_id);
create index if not exists idx_events_datetime on public.events(event_datetime);
create index if not exists idx_registrations_event_id on public.registrations(event_id);
create index if not exists idx_registrations_user_id on public.registrations(user_id);

-- Optional: enable RLS for the app tables
alter table public.churches enable row level security;
alter table public.users enable row level security;
alter table public.events enable row level security;
alter table public.registrations enable row level security;

create policy "Churches are viewable by everyone" on public.churches
for select using (true);

create policy "Users can view all users in their church" on public.users
for select using (
    church_id in (
        select church_id from public.users where id = auth.uid()
    )
    or auth.uid() = id
    or exists (
        select 1 from public.users where id = auth.uid() and role = 'admin'
    )
);

create policy "Users can manage their own profile" on public.users
for insert with check (auth.uid() = id or auth.uid() is null);

create policy "Members can view events for their church" on public.events
for select using (true);

create policy "Organizers and admins can manage events" on public.events
for insert with check (
    exists (
        select 1 from public.users u
        where u.id = auth.uid() and u.church_id = events.church_id and u.role in ('organizer', 'admin')
    )
);

create policy "Organizers and admins can update their church events" on public.events
for update using (
    exists (
        select 1 from public.users u
        where u.id = auth.uid() and u.church_id = events.church_id and u.role in ('organizer', 'admin')
    )
) with check (
    exists (
        select 1 from public.users u
        where u.id = auth.uid() and u.church_id = events.church_id and u.role in ('organizer', 'admin')
    )
);

create policy "Organizers and admins can delete their church events" on public.events
for delete using (
    exists (
        select 1 from public.users u
        where u.id = auth.uid() and u.church_id = events.church_id and u.role in ('organizer', 'admin')
    )
);

create policy "Users can manage their own registrations" on public.registrations
for all using (auth.uid() = user_id)
with check (auth.uid() = user_id);

-- Sample seed data (optional)
insert into public.churches (id, name, location, website, image_url)
values
    ('11111111-1111-4111-8111-111111111111', 'Phaneroo Ministries International', 'Kampala, Uganda', 'https://phaneroo.org/', 'PICTURES/Phaneroo%20logo.png'),
    ('22222222-2222-4222-8222-222222222222', 'Apokalupsis Ministries', 'Kampala, Uganda', 'https://www.apokalupsisministries.org/', 'PICTURES/Apokalupsis%20logo.jpeg')
on conflict (name) do nothing;

insert into public.users (id, church_id, name, email, password_hash, phone, role)
values
    ('33333333-3333-4333-8333-333333333333', '11111111-1111-4111-8111-111111111111', 'John', 'john@phaneroo.com', '123', '+256700000001', 'member'),
    ('44444444-4444-4444-8444-444444444444', '11111111-1111-4111-8111-111111111111', 'Admin', 'admin@phaneroo.com', '123', '+256700000002', 'organizer'),
    ('55555555-5555-4555-8555-555555555555', '22222222-2222-4222-8222-222222222222', 'John', 'john@apokalupsis.com', '123', '+256700000003', 'member'),
    ('66666666-6666-4666-8666-666666666666', '22222222-2222-4222-8222-222222222222', 'Admin', 'admin@apokalupsis.com', '123', '+256700000004', 'organizer'),
    ('77777777-7777-4777-8777-777777777777', null, 'System Admin', 'john@gmail.com', '123', '+256700000005', 'admin')
on conflict (email) do nothing;

-- Example events
insert into public.events (id, church_id, title, event_datetime, venue, description, image_url, created_by)
values
    ('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa', '11111111-1111-4111-8111-111111111111', 'Phaneroo Thursday Service', '2026-10-08 17:00:00+00', 'Phaneroo Grounds, Naguru', 'An evening of deep worship, deliverance, and spiritual revelation.', 'PICTURES/Phaneroo%20Thursday%20Service%20Event.jpeg', '44444444-4444-4444-8444-444444444444'),
    ('bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb', '11111111-1111-4111-8111-111111111111', 'Phaneroo Sunday Service', '2026-10-11 09:00:00+00', 'Phaneroo Grounds, Naguru', 'A vibrant Sunday gathering with worship, prayer, and teaching.', 'PICTURES/Phaneroo%20Sunday%20Service%20Event.jpeg', '44444444-4444-4444-8444-444444444444')
on conflict do nothing;
