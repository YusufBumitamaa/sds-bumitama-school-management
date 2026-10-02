/*
  Migration 011
  Parents / Guardians

  Sumber acuan:
  - PRD v4.0
  - Master Technical Blueprint v1.0
  - Database Blueprint v1.0

  Fungsi:
  - Menyimpan data orang tua/wali siswa.
  - Mendukung Ayah, Ibu, dan Wali.
  - Satu siswa dapat memiliki beberapa orang tua/wali.
  - Satu orang tua/wali dapat dikaitkan dengan beberapa siswa.
*/


/* =========================================================
   1. ENUM RELATIONSHIP
   ========================================================= */

do $$
begin
  if not exists (
    select 1
    from pg_type
    where typname = 'parent_relationship'
      and typnamespace = 'public'::regnamespace
  ) then
    create type public.parent_relationship as enum (
      'ayah',
      'ibu',
      'wali'
    );
  end if;
end
$$;


/* =========================================================
   2. TABLE: parents
   ========================================================= */

create table if not exists public.parents (
  id uuid primary key default gen_random_uuid(),

  student_id uuid not null
    references public.students(id)
    on delete restrict,

  relationship public.parent_relationship not null,

  full_name text not null,

  nik text,

  birth_place text,

  birth_date date,

  religion text,

  education text,

  occupation text,

  income numeric(15,2),

  phone text,

  email text,

  address text,

  rt text,

  rw text,

  village text,

  district text,

  regency text,

  province text,

  postal_code text,

  is_primary boolean not null default false,

  notes text,

  created_at timestamptz not null default now(),

  updated_at timestamptz not null default now()
);


/* =========================================================
   3. COMMENTS
   ========================================================= */

comment on table public.parents is
  'Data orang tua atau wali siswa.';

comment on column public.parents.relationship is
  'Hubungan dengan siswa: ayah, ibu, atau wali.';

comment on column public.parents.is_primary is
  'Menandai orang tua/wali utama yang menjadi kontak utama siswa.';

comment on column public.parents.income is
  'Perkiraan penghasilan orang tua/wali dalam rupiah.';


/* =========================================================
   4. INDEXES
   ========================================================= */

create index if not exists parents_student_id_idx
  on public.parents(student_id);

create index if not exists parents_relationship_idx
  on public.parents(relationship);

create index if not exists parents_full_name_idx
  on public.parents(full_name);

create index if not exists parents_nik_idx
  on public.parents(nik);

create index if not exists parents_phone_idx
  on public.parents(phone);

create index if not exists parents_is_primary_idx
  on public.parents(is_primary);


/* =========================================================
   5. UPDATED_AT TRIGGER
   ========================================================= */

drop trigger if exists parents_set_updated_at
on public.parents;

create trigger parents_set_updated_at
before update on public.parents
for each row
execute function public.set_updated_at();


/* =========================================================
   6. ROW LEVEL SECURITY
   ========================================================= */

alter table public.parents enable row level security;


/* =========================================================
   7. SELECT POLICY
   ========================================================= */

drop policy if exists parents_select_with_permission
on public.parents;

create policy parents_select_with_permission
on public.parents
for select
to authenticated
using (
  public.is_super_admin()
  or public.has_permission('kesiswaan', 'view')
);


/* =========================================================
   8. INSERT POLICY
   ========================================================= */

drop policy if exists parents_insert_with_permission
on public.parents;

create policy parents_insert_with_permission
on public.parents
for insert
to authenticated
with check (
  public.is_super_admin()
  or public.has_permission('kesiswaan', 'create')
);


/* =========================================================
   9. UPDATE POLICY
   ========================================================= */

drop policy if exists parents_update_with_permission
on public.parents;

create policy parents_update_with_permission
on public.parents
for update
to authenticated
using (
  public.is_super_admin()
  or public.has_permission('kesiswaan', 'update')
)
with check (
  public.is_super_admin()
  or public.has_permission('kesiswaan', 'update')
);


/* =========================================================
   10. DELETE POLICY
   ========================================================= */

drop policy if exists parents_delete_with_permission
on public.parents;

create policy parents_delete_with_permission
on public.parents
for delete
to authenticated
using (
  public.is_super_admin()
  or public.has_permission('kesiswaan', 'delete')
);


/* =========================================================
   11. GRANTS
   ========================================================= */

grant select, insert, update, delete
on public.parents
to authenticated;