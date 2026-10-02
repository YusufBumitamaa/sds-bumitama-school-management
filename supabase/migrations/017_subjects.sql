/*
  Migration 017
  Subjects / Mata Pelajaran

  Sumber acuan:
  - PRD v4.0
  - Master Technical Blueprint v1.0
  - Database Blueprint v1.0

  Fungsi:
  - Menyimpan master data mata pelajaran.
  - Menjadi referensi untuk kurikulum,
    jadwal, penilaian, dan rapor.
*/


/* =========================================================
   1. TABLE: subjects
   ========================================================= */

create table if not exists public.subjects (
  id uuid primary key default gen_random_uuid(),

  code text not null,

  name text not null,

  short_name text,

  category text,

  description text,

  default_hours_per_week numeric(5,2),

  is_active boolean not null default true,

  notes text,

  created_at timestamptz not null default now(),

  updated_at timestamptz not null default now(),

  constraint subjects_code_unique
    unique (code),

  constraint subjects_name_unique
    unique (name),

  constraint subjects_default_hours_check
    check (
      default_hours_per_week is null
      or default_hours_per_week > 0
    )
);


/* =========================================================
   2. COMMENTS
   ========================================================= */

comment on table public.subjects is
  'Master data mata pelajaran sekolah.';

comment on column public.subjects.code is
  'Kode unik mata pelajaran.';

comment on column public.subjects.name is
  'Nama lengkap mata pelajaran.';

comment on column public.subjects.short_name is
  'Nama singkat mata pelajaran.';

comment on column public.subjects.category is
  'Kategori mata pelajaran.';

comment on column public.subjects.default_hours_per_week is
  'Alokasi jam pelajaran default per minggu.';

comment on column public.subjects.is_active is
  'Menentukan apakah mata pelajaran masih aktif digunakan.';


/* =========================================================
   3. INDEXES
   ========================================================= */

create index if not exists
  subjects_name_idx
on public.subjects(name);

create index if not exists
  subjects_category_idx
on public.subjects(category);

create index if not exists
  subjects_active_idx
on public.subjects(is_active);


/* =========================================================
   4. UPDATED_AT TRIGGER
   ========================================================= */

drop trigger if exists
  subjects_set_updated_at
on public.subjects;

create trigger subjects_set_updated_at
before update on public.subjects
for each row
execute function public.set_updated_at();


/* =========================================================
   5. ROW LEVEL SECURITY
   ========================================================= */

alter table public.subjects enable row level security;


/* =========================================================
   6. SELECT POLICY
   ========================================================= */

drop policy if exists
  subjects_select_with_permission
on public.subjects;

create policy subjects_select_with_permission
on public.subjects
for select
to authenticated
using (
  public.is_super_admin()
  or public.has_permission('kurikulum', 'view')
);


/* =========================================================
   7. INSERT POLICY
   ========================================================= */

drop policy if exists
  subjects_insert_with_permission
on public.subjects;

create policy subjects_insert_with_permission
on public.subjects
for insert
to authenticated
with check (
  public.is_super_admin()
  or public.has_permission('kurikulum', 'create')
);


/* =========================================================
   8. UPDATE POLICY
   ========================================================= */

drop policy if exists
  subjects_update_with_permission
on public.subjects;

create policy subjects_update_with_permission
on public.subjects
for update
to authenticated
using (
  public.is_super_admin()
  or public.has_permission('kurikulum', 'update')
)
with check (
  public.is_super_admin()
  or public.has_permission('kurikulum', 'update')
);


/* =========================================================
   9. DELETE POLICY
   ========================================================= */

drop policy if exists
  subjects_delete_with_permission
on public.subjects;

create policy subjects_delete_with_permission
on public.subjects
for delete
to authenticated
using (
  public.is_super_admin()
  or public.has_permission('kurikulum', 'delete')
);


/* =========================================================
   10. GRANTS
   ========================================================= */

grant select, insert, update, delete
on public.subjects
to authenticated;