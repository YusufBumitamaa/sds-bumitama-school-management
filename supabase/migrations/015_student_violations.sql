/*
  Migration 015
  Student Violations

  Sumber acuan:
  - PRD v4.0
  - Master Technical Blueprint v1.0
  - Database Blueprint v1.0

  Fungsi:
  - Menyimpan riwayat pelanggaran siswa.
  - Mendukung pencatatan tindakan dan tindak lanjut.
  - Satu siswa dapat memiliki banyak catatan pelanggaran.
*/


/* =========================================================
   1. ENUM VIOLATION LEVEL
   ========================================================= */

do $$
begin
  if not exists (
    select 1
    from pg_type
    where typname = 'violation_level'
      and typnamespace = 'public'::regnamespace
  ) then
    create type public.violation_level as enum (
      'ringan',
      'sedang',
      'berat'
    );
  end if;
end
$$;


/* =========================================================
   2. TABLE: student_violations
   ========================================================= */

create table if not exists public.student_violations (
  id uuid primary key default gen_random_uuid(),

  student_id uuid not null
    references public.students(id)
    on delete restrict,

  violation_date date not null default current_date,

  violation_type text not null,

  description text,

  level public.violation_level not null default 'ringan',

  action_taken text,

  follow_up text,

  parent_notified boolean not null default false,

  parent_notification_date date,

  document_number text,

  document_date date,

  resolved boolean not null default false,

  resolved_date date,

  notes text,

  created_by uuid
    references public.users(id)
    on delete set null,

  created_at timestamptz not null default now(),

  updated_at timestamptz not null default now(),

  constraint student_violations_parent_notification_check
    check (
      parent_notified = false
      or parent_notification_date is not null
    ),

  constraint student_violations_resolved_check
    check (
      resolved = false
      or resolved_date is not null
    ),

  constraint student_violations_resolved_date_check
    check (
      resolved_date is null
      or resolved_date >= violation_date
    )
);


/* =========================================================
   3. COMMENTS
   ========================================================= */

comment on table public.student_violations is
  'Riwayat pelanggaran dan pembinaan siswa.';

comment on column public.student_violations.violation_type is
  'Jenis atau kategori pelanggaran siswa.';

comment on column public.student_violations.level is
  'Tingkat pelanggaran: ringan, sedang, atau berat.';

comment on column public.student_violations.action_taken is
  'Tindakan atau pembinaan yang diberikan.';

comment on column public.student_violations.follow_up is
  'Tindak lanjut setelah penanganan pelanggaran.';

comment on column public.student_violations.parent_notified is
  'Menandai apakah orang tua/wali telah diberitahu.';

comment on column public.student_violations.resolved is
  'Menandai apakah kasus pelanggaran telah diselesaikan.';


/* =========================================================
   4. INDEXES
   ========================================================= */

create index if not exists
  student_violations_student_id_idx
on public.student_violations(student_id);

create index if not exists
  student_violations_date_idx
on public.student_violations(violation_date desc);

create index if not exists
  student_violations_type_idx
on public.student_violations(violation_type);

create index if not exists
  student_violations_level_idx
on public.student_violations(level);

create index if not exists
  student_violations_resolved_idx
on public.student_violations(resolved);

create index if not exists
  student_violations_created_by_idx
on public.student_violations(created_by);


/* =========================================================
   5. UPDATED_AT TRIGGER
   ========================================================= */

drop trigger if exists
  student_violations_set_updated_at
on public.student_violations;

create trigger student_violations_set_updated_at
before update on public.student_violations
for each row
execute function public.set_updated_at();


/* =========================================================
   6. ROW LEVEL SECURITY
   ========================================================= */

alter table public.student_violations enable row level security;


/* =========================================================
   7. SELECT POLICY
   ========================================================= */

drop policy if exists
  student_violations_select_with_permission
on public.student_violations;

create policy student_violations_select_with_permission
on public.student_violations
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
  student_violations_insert_with_permission
on public.student_violations;

create policy student_violations_insert_with_permission
on public.student_violations
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
  student_violations_update_with_permission
on public.student_violations;

create policy student_violations_update_with_permission
on public.student_violations
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
  student_violations_delete_with_permission
on public.student_violations;

create policy student_violations_delete_with_permission
on public.student_violations
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
on public.student_violations
to authenticated;