/*
  Migration 013
  Student Mutations

  Sumber acuan:
  - PRD v4.0
  - Master Technical Blueprint v1.0
  - Database Blueprint v1.0

  Fungsi:
  - Menyimpan riwayat mutasi siswa.
  - Mendukung mutasi masuk, pindah, dan keluar.
  - Menjaga data siswa tetap tersimpan.
  - Menjadi sumber histori administrasi mutasi.
*/


/* =========================================================
   1. ENUM MUTATION TYPE
   ========================================================= */

do $$
begin
  if not exists (
    select 1
    from pg_type
    where typname = 'student_mutation_type'
      and typnamespace = 'public'::regnamespace
  ) then
    create type public.student_mutation_type as enum (
      'masuk',
      'pindah',
      'keluar'
    );
  end if;
end
$$;


/* =========================================================
   2. TABLE: student_mutations
   ========================================================= */

create table if not exists public.student_mutations (
  id uuid primary key default gen_random_uuid(),

  student_id uuid not null
    references public.students(id)
    on delete restrict,

  mutation_type public.student_mutation_type not null,

  mutation_date date not null default current_date,

  origin_school_name text,

  origin_school_npsn text,

  destination_school_name text,

  destination_school_npsn text,

  destination_school_address text,

  document_number text,

  document_date date,

  reason text,

  notes text,

  created_by uuid
    references public.users(id)
    on delete set null,

  created_at timestamptz not null default now(),

  updated_at timestamptz not null default now()
);


/* =========================================================
   3. COMMENTS
   ========================================================= */

comment on table public.student_mutations is
  'Riwayat mutasi siswa masuk, pindah, dan keluar.';

comment on column public.student_mutations.mutation_type is
  'Jenis mutasi: masuk, pindah, atau keluar.';

comment on column public.student_mutations.origin_school_name is
  'Nama sekolah asal siswa untuk mutasi masuk.';

comment on column public.student_mutations.destination_school_name is
  'Nama sekolah tujuan siswa untuk mutasi pindah atau keluar.';

comment on column public.student_mutations.document_number is
  'Nomor surat atau dokumen pendukung mutasi.';

comment on column public.student_mutations.created_by is
  'User yang mencatat data mutasi.';


/* =========================================================
   4. INDEXES
   ========================================================= */

create index if not exists
  student_mutations_student_id_idx
on public.student_mutations(student_id);

create index if not exists
  student_mutations_type_idx
on public.student_mutations(mutation_type);

create index if not exists
  student_mutations_date_idx
on public.student_mutations(mutation_date desc);

create index if not exists
  student_mutations_document_number_idx
on public.student_mutations(document_number);

create index if not exists
  student_mutations_created_by_idx
on public.student_mutations(created_by);


/* =========================================================
   5. UPDATED_AT TRIGGER
   ========================================================= */

drop trigger if exists
  student_mutations_set_updated_at
on public.student_mutations;

create trigger student_mutations_set_updated_at
before update on public.student_mutations
for each row
execute function public.set_updated_at();


/* =========================================================
   6. ROW LEVEL SECURITY
   ========================================================= */

alter table public.student_mutations enable row level security;


/* =========================================================
   7. SELECT POLICY
   ========================================================= */

drop policy if exists
  student_mutations_select_with_permission
on public.student_mutations;

create policy student_mutations_select_with_permission
on public.student_mutations
for select
to authenticated
using (
  public.is_super_admin()
  or public.has_permission('kesiswaan', 'view')
);


/* =========================================================
   8. INSERT POLICY
   ========================================================= */

drop policy if exists
  student_mutations_insert_with_permission
on public.student_mutations;

create policy student_mutations_insert_with_permission
on public.student_mutations
for insert
to authenticated
with check (
  public.is_super_admin()
  or public.has_permission('kesiswaan', 'create')
);


/* =========================================================
   9. UPDATE POLICY
   ========================================================= */

drop policy if exists
  student_mutations_update_with_permission
on public.student_mutations;

create policy student_mutations_update_with_permission
on public.student_mutations
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

drop policy if exists
  student_mutations_delete_with_permission
on public.student_mutations;

create policy student_mutations_delete_with_permission
on public.student_mutations
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
on public.student_mutations
to authenticated;