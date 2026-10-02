-- ============================================================
-- SDS BUMITAMA SCHOOL MANAGEMENT
-- Migration: 001_identity_security
-- Module: Identity & Security
-- Based on: PRD v4.0 + Database Blueprint v1.0
-- ============================================================


-- ============================================================
-- 1. EXTENSIONS
-- ============================================================

create extension if not exists pgcrypto;


-- ============================================================
-- 2. ENUMS
-- ============================================================

do $$
begin
  if not exists (
    select 1
    from pg_type
    where typname = 'app_role'
      and typnamespace = 'public'::regnamespace
  ) then
    create type public.app_role as enum (
      'super_admin',
      'admin',
      'kepala_sekolah',
      'guru',
      'bendahara'
    );
  end if;
end
$$;


do $$
begin
  if not exists (
    select 1
    from pg_type
    where typname = 'permission_action'
      and typnamespace = 'public'::regnamespace
  ) then
    create type public.permission_action as enum (
      'view',
      'create',
      'update',
      'delete',
      'approve',
      'export',
      'print',
      'upload'
    );
  end if;
end
$$;


-- ============================================================
-- 3. USERS
-- ============================================================

create table if not exists public.users (
  id uuid primary key references auth.users(id) on delete cascade,
  email text not null unique,
  full_name text not null,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);


-- ============================================================
-- 4. ROLES
-- ============================================================

create table if not exists public.roles (
  id uuid primary key default gen_random_uuid(),
  code public.app_role not null unique,
  name text not null,
  description text,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);


-- ============================================================
-- 5. PERMISSIONS
-- ============================================================

create table if not exists public.permissions (
  id uuid primary key default gen_random_uuid(),
  module text not null,
  action public.permission_action not null,
  description text,
  created_at timestamptz not null default now(),
  unique (module, action)
);


-- ============================================================
-- 6. USER ROLES
-- ============================================================

create table if not exists public.user_roles (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null
    references public.users(id)
    on delete cascade,
  role_id uuid not null
    references public.roles(id)
    on delete cascade,
  created_at timestamptz not null default now(),
  unique (user_id, role_id)
);


-- ============================================================
-- 7. ROLE PERMISSIONS
-- ============================================================

create table if not exists public.role_permissions (
  id uuid primary key default gen_random_uuid(),
  role_id uuid not null
    references public.roles(id)
    on delete cascade,
  permission_id uuid not null
    references public.permissions(id)
    on delete cascade,
  created_at timestamptz not null default now(),
  unique (role_id, permission_id)
);


-- ============================================================
-- 8. ACTIVITY LOGS
-- ============================================================

create table if not exists public.activity_logs (
  id uuid primary key default gen_random_uuid(),
  user_id uuid
    references public.users(id)
    on delete set null,
  action text not null,
  module text not null,
  description text,
  before_data jsonb,
  after_data jsonb,
  ip_address inet,
  user_agent text,
  created_at timestamptz not null default now()
);


-- ============================================================
-- 9. NOTIFICATIONS
-- ============================================================

create table if not exists public.notifications (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null
    references public.users(id)
    on delete cascade,
  title text not null,
  message text not null,
  is_read boolean not null default false,
  created_at timestamptz not null default now(),
  read_at timestamptz
);


-- ============================================================
-- 10. INDEXES
-- ============================================================

create index if not exists idx_users_email
  on public.users(email);

create index if not exists idx_users_is_active
  on public.users(is_active);

create index if not exists idx_user_roles_user_id
  on public.user_roles(user_id);

create index if not exists idx_user_roles_role_id
  on public.user_roles(role_id);

create index if not exists idx_role_permissions_role_id
  on public.role_permissions(role_id);

create index if not exists idx_role_permissions_permission_id
  on public.role_permissions(permission_id);

create index if not exists idx_activity_logs_user_id
  on public.activity_logs(user_id);

create index if not exists idx_activity_logs_module
  on public.activity_logs(module);

create index if not exists idx_activity_logs_created_at
  on public.activity_logs(created_at desc);

create index if not exists idx_notifications_user_id
  on public.notifications(user_id);

create index if not exists idx_notifications_is_read
  on public.notifications(user_id, is_read);


-- ============================================================
-- 11. UPDATED_AT FUNCTION
-- ============================================================

create or replace function public.set_updated_at()
returns trigger
language plpgsql
security invoker
set search_path = public, pg_temp
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;


-- ============================================================
-- 12. UPDATED_AT TRIGGERS
-- ============================================================

drop trigger if exists users_set_updated_at
on public.users;

create trigger users_set_updated_at
before update on public.users
for each row
execute function public.set_updated_at();


drop trigger if exists roles_set_updated_at
on public.roles;

create trigger roles_set_updated_at
before update on public.roles
for each row
execute function public.set_updated_at();


-- ============================================================
-- 13. DEFAULT ROLES
-- ============================================================

insert into public.roles (
  code,
  name,
  description
)
values
  (
    'super_admin',
    'Super Admin',
    'Mengelola seluruh sistem, pengguna, hak akses, konfigurasi, dan administrasi aplikasi.'
  ),
  (
    'admin',
    'Admin/TU',
    'Mengelola administrasi sekolah sesuai hak akses yang diberikan.'
  ),
  (
    'kepala_sekolah',
    'Kepala Sekolah',
    'Melakukan monitoring, persetujuan, dan akses administratif sesuai kewenangan.'
  ),
  (
    'guru',
    'Guru',
    'Mengelola aktivitas akademik dan data pembelajaran sesuai kewenangan.'
  ),
  (
    'bendahara',
    'Bendahara',
    'Mengelola administrasi dan transaksi keuangan sekolah sesuai kewenangan.'
  )
on conflict (code) do update
set
  name = excluded.name,
  description = excluded.description;


-- ============================================================
-- 14. CORE PERMISSIONS
-- ============================================================

insert into public.permissions (
  module,
  action,
  description
)
values
  ('dashboard', 'view', 'Melihat dashboard'),

  ('profil_sekolah', 'view', 'Melihat profil sekolah'),
  ('profil_sekolah', 'create', 'Membuat data profil sekolah'),
  ('profil_sekolah', 'update', 'Mengubah data profil sekolah'),

  ('kesiswaan', 'view', 'Melihat modul kesiswaan'),
  ('kesiswaan', 'create', 'Membuat data kesiswaan'),
  ('kesiswaan', 'update', 'Mengubah data kesiswaan'),
  ('kesiswaan', 'delete', 'Menghapus data kesiswaan'),
  ('kesiswaan', 'export', 'Mengekspor data kesiswaan'),
  ('kesiswaan', 'print', 'Mencetak data kesiswaan'),
  ('kesiswaan', 'upload', 'Mengunggah dokumen kesiswaan'),

  ('kurikulum', 'view', 'Melihat modul kurikulum'),
  ('kurikulum', 'create', 'Membuat data kurikulum'),
  ('kurikulum', 'update', 'Mengubah data kurikulum'),
  ('kurikulum', 'delete', 'Menghapus data kurikulum'),
  ('kurikulum', 'export', 'Mengekspor data kurikulum'),
  ('kurikulum', 'print', 'Mencetak data kurikulum'),
  ('kurikulum', 'upload', 'Mengunggah dokumen kurikulum'),

  ('akademik', 'view', 'Melihat modul akademik'),
  ('akademik', 'create', 'Membuat data akademik'),
  ('akademik', 'update', 'Mengubah data akademik'),
  ('akademik', 'delete', 'Menghapus data akademik'),
  ('akademik', 'approve', 'Menyetujui proses akademik'),
  ('akademik', 'export', 'Mengekspor data akademik'),
  ('akademik', 'print', 'Mencetak data akademik'),

  ('gtk', 'view', 'Melihat data GTK'),
  ('gtk', 'create', 'Membuat data GTK'),
  ('gtk', 'update', 'Mengubah data GTK'),
  ('gtk', 'delete', 'Menghapus data GTK'),
  ('gtk', 'export', 'Mengekspor data GTK'),
  ('gtk', 'print', 'Mencetak data GTK'),
  ('gtk', 'upload', 'Mengunggah dokumen GTK'),

  ('sarpras', 'view', 'Melihat data sarpras'),
  ('sarpras', 'create', 'Membuat data sarpras'),
  ('sarpras', 'update', 'Mengubah data sarpras'),
  ('sarpras', 'delete', 'Menghapus data sarpras'),
  ('sarpras', 'export', 'Mengekspor data sarpras'),
  ('sarpras', 'print', 'Mencetak data sarpras'),
  ('sarpras', 'upload', 'Mengunggah dokumen sarpras'),

  ('keuangan', 'view', 'Melihat modul keuangan'),
  ('keuangan', 'create', 'Membuat transaksi keuangan'),
  ('keuangan', 'update', 'Mengubah transaksi keuangan'),
  ('keuangan', 'delete', 'Menghapus data keuangan'),
  ('keuangan', 'approve', 'Menyetujui transaksi keuangan'),
  ('keuangan', 'export', 'Mengekspor data keuangan'),
  ('keuangan', 'print', 'Mencetak laporan keuangan'),
  ('keuangan', 'upload', 'Mengunggah bukti transaksi'),

  ('persuratan', 'view', 'Melihat persuratan dan arsip'),
  ('persuratan', 'create', 'Membuat surat atau dokumen'),
  ('persuratan', 'update', 'Mengubah surat atau dokumen'),
  ('persuratan', 'delete', 'Menghapus surat atau dokumen'),
  ('persuratan', 'export', 'Mengekspor arsip'),
  ('persuratan', 'print', 'Mencetak surat atau dokumen'),
  ('persuratan', 'upload', 'Mengunggah dokumen'),

  ('laporan', 'view', 'Melihat laporan'),
  ('laporan', 'export', 'Mengekspor laporan'),
  ('laporan', 'print', 'Mencetak laporan'),

  ('pengguna', 'view', 'Melihat pengguna dan hak akses'),
  ('pengguna', 'create', 'Membuat pengguna'),
  ('pengguna', 'update', 'Mengubah pengguna'),
  ('pengguna', 'delete', 'Menghapus pengguna'),

  ('pengaturan', 'view', 'Melihat pengaturan sistem'),
  ('pengaturan', 'update', 'Mengubah pengaturan sistem'),

  ('audit_log', 'view', 'Melihat audit log'),

  ('notifikasi', 'view', 'Melihat notifikasi'),
  ('notifikasi', 'update', 'Mengubah status notifikasi')
on conflict (module, action) do nothing;


-- ============================================================
-- 15. SUPER ADMIN CORE PERMISSIONS
-- ============================================================

insert into public.role_permissions (
  role_id,
  permission_id
)
select
  r.id,
  p.id
from public.roles r
cross join public.permissions p
where r.code = 'super_admin'
on conflict (role_id, permission_id) do nothing;


-- ============================================================
-- 16. ENABLE ROW LEVEL SECURITY
-- ============================================================

alter table public.users enable row level security;
alter table public.roles enable row level security;
alter table public.permissions enable row level security;
alter table public.user_roles enable row level security;
alter table public.role_permissions enable row level security;
alter table public.activity_logs enable row level security;
alter table public.notifications enable row level security;


-- ============================================================
-- 17. RLS HELPER FUNCTIONS
-- ============================================================

create or replace function public.is_super_admin()
returns boolean
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select exists (
    select 1
    from public.user_roles ur
    inner join public.roles r
      on r.id = ur.role_id
    where ur.user_id = auth.uid()
      and r.code = 'super_admin'
      and r.is_active = true
  );
$$;


create or replace function public.has_role(
  requested_role public.app_role
)
returns boolean
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select exists (
    select 1
    from public.user_roles ur
    inner join public.roles r
      on r.id = ur.role_id
    where ur.user_id = auth.uid()
      and r.code = requested_role
      and r.is_active = true
  );
$$;


create or replace function public.has_permission(
  requested_module text,
  requested_action public.permission_action
)
returns boolean
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select exists (
    select 1
    from public.user_roles ur
    inner join public.roles r
      on r.id = ur.role_id
    inner join public.role_permissions rp
      on rp.role_id = r.id
    inner join public.permissions p
      on p.id = rp.permission_id
    where ur.user_id = auth.uid()
      and r.is_active = true
      and p.module = requested_module
      and p.action = requested_action
  );
$$;


-- ============================================================
-- 18. FUNCTION SECURITY
-- ============================================================

revoke all
on function public.is_super_admin()
from public;

revoke all
on function public.has_role(public.app_role)
from public;

revoke all
on function public.has_permission(
  text,
  public.permission_action
)
from public;


grant execute
on function public.is_super_admin()
to authenticated;

grant execute
on function public.has_role(public.app_role)
to authenticated;

grant execute
on function public.has_permission(
  text,
  public.permission_action
)
to authenticated;


-- ============================================================
-- 19. USERS POLICIES
-- ============================================================

drop policy if exists users_select_self_or_admin
on public.users;

create policy users_select_self_or_admin
on public.users
for select
to authenticated
using (
  id = auth.uid()
  or public.is_super_admin()
);


drop policy if exists users_insert_super_admin
on public.users;

create policy users_insert_super_admin
on public.users
for insert
to authenticated
with check (
  public.is_super_admin()
);


drop policy if exists users_update_self_or_admin
on public.users;

create policy users_update_self_or_admin
on public.users
for update
to authenticated
using (
  id = auth.uid()
  or public.is_super_admin()
)
with check (
  id = auth.uid()
  or public.is_super_admin()
);


drop policy if exists users_delete_super_admin
on public.users;

create policy users_delete_super_admin
on public.users
for delete
to authenticated
using (
  public.is_super_admin()
);


-- ============================================================
-- 20. ROLES POLICIES
-- ============================================================

drop policy if exists roles_select_authenticated
on public.roles;

create policy roles_select_authenticated
on public.roles
for select
to authenticated
using (
  is_active = true
  or public.is_super_admin()
);


drop policy if exists roles_manage_super_admin
on public.roles;

create policy roles_manage_super_admin
on public.roles
for all
to authenticated
using (
  public.is_super_admin()
)
with check (
  public.is_super_admin()
);


-- ============================================================
-- 21. PERMISSIONS POLICIES
-- ============================================================

drop policy if exists permissions_select_authenticated
on public.permissions;

create policy permissions_select_authenticated
on public.permissions
for select
to authenticated
using (true);


drop policy if exists permissions_manage_super_admin
on public.permissions;

create policy permissions_manage_super_admin
on public.permissions
for all
to authenticated
using (
  public.is_super_admin()
)
with check (
  public.is_super_admin()
);


-- ============================================================
-- 22. USER ROLES POLICIES
-- ============================================================

drop policy if exists user_roles_select_self_or_admin
on public.user_roles;

create policy user_roles_select_self_or_admin
on public.user_roles
for select
to authenticated
using (
  user_id = auth.uid()
  or public.is_super_admin()
);


drop policy if exists user_roles_manage_super_admin
on public.user_roles;

create policy user_roles_manage_super_admin
on public.user_roles
for all
to authenticated
using (
  public.is_super_admin()
)
with check (
  public.is_super_admin()
);


-- ============================================================
-- 23. ROLE PERMISSIONS POLICIES
-- ============================================================

drop policy if exists role_permissions_select_authenticated
on public.role_permissions;

create policy role_permissions_select_authenticated
on public.role_permissions
for select
to authenticated
using (true);


drop policy if exists role_permissions_manage_super_admin
on public.role_permissions;

create policy role_permissions_manage_super_admin
on public.role_permissions
for all
to authenticated
using (
  public.is_super_admin()
)
with check (
  public.is_super_admin()
);


-- ============================================================
-- 24. ACTIVITY LOG POLICIES
-- ============================================================

drop policy if exists activity_logs_insert_authenticated
on public.activity_logs;

create policy activity_logs_insert_authenticated
on public.activity_logs
for insert
to authenticated
with check (
  user_id = auth.uid()
);


drop policy if exists activity_logs_select_super_admin
on public.activity_logs;

create policy activity_logs_select_super_admin
on public.activity_logs
for select
to authenticated
using (
  public.is_super_admin()
);


-- ============================================================
-- 25. NOTIFICATION POLICIES
-- ============================================================

drop policy if exists notifications_select_own
on public.notifications;

create policy notifications_select_own
on public.notifications
for select
to authenticated
using (
  user_id = auth.uid()
);


drop policy if exists notifications_update_own
on public.notifications;

create policy notifications_update_own
on public.notifications
for update
to authenticated
using (
  user_id = auth.uid()
)
with check (
  user_id = auth.uid()
);


-- ============================================================
-- 26. TABLE PRIVILEGES
-- ============================================================

revoke all
on public.users
from anon;

revoke all
on public.roles
from anon;

revoke all
on public.permissions
from anon;

revoke all
on public.user_roles
from anon;

revoke all
on public.role_permissions
from anon;

revoke all
on public.activity_logs
from anon;

revoke all
on public.notifications
from anon;


grant select
on public.roles
to authenticated;

grant select
on public.permissions
to authenticated;

grant select
on public.role_permissions
to authenticated;

grant select, insert, update, delete
on public.users
to authenticated;

grant select, insert, update, delete
on public.user_roles
to authenticated;

grant insert, select
on public.activity_logs
to authenticated;

grant select, update
on public.notifications
to authenticated;


-- ============================================================
-- 27. FUNCTION COMMENTS
-- ============================================================

comment on function public.is_super_admin()
is 'Memeriksa apakah pengguna aktif memiliki role super_admin. Digunakan oleh RLS.';

comment on function public.has_role(public.app_role)
is 'Memeriksa apakah pengguna aktif memiliki role tertentu. Digunakan oleh authorization layer.';

comment on function public.has_permission(
  text,
  public.permission_action
)
is 'Memeriksa apakah pengguna memiliki permission tertentu melalui role yang dimilikinya.';


-- ============================================================
-- END OF MIGRATION 001
-- ============================================================