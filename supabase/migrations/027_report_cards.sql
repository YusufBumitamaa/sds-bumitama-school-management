/*
  Migration 027
  Report Cards / Rapor Siswa

  Sumber acuan:
  - PRD v4.0
  - Master Technical Blueprint v1.0
  - Database Blueprint v1.0

  Konsep:
  - report_cards       = header/identitas rapor
  - report_card_details = detail nilai rapor
  - Nilai pada detail merupakan snapshot nilai.
  - Rapor yang telah diterbitkan dapat dikunci.
*/


/* =========================================================
   1. ENUM STATUS RAPOR
   ========================================================= */

do $$
begin
  if not exists (
    select 1
    from pg_type
    where typname = 'report_card_status'
      and typnamespace = 'public'::regnamespace
  ) then

    create type public.report_card_status as enum (
      'draft',
      'final',
      'diterbitkan'
    );

  end if;
end
$$;


/* =========================================================
   2. TABLE REPORT CARDS
   ========================================================= */

create table if not exists public.report_cards (
  id uuid primary key default gen_random_uuid(),

  student_id uuid not null
    references public.students(id)
    on delete restrict,

  academic_year_id uuid not null
    references public.academic_years(id)
    on delete restrict,

  class_id uuid not null
    references public.classes(id)
    on delete restrict,

  semester public.academic_semester not null,

  status public.report_card_status not null
    default 'draft',

  report_number text,

  issue_date date,

  homeroom_teacher_id uuid
    references public.teachers_staff(id)
    on delete restrict,

  homeroom_teacher_note text,

  principal_note text,

  attendance_sick integer not null default 0,

  attendance_permission integer not null default 0,

  attendance_absent integer not null default 0,

  general_notes text,

  created_by uuid
    references public.users(id)
    on delete set null,

  finalized_by uuid
    references public.users(id)
    on delete set null,

  finalized_at timestamptz,

  published_by uuid
    references public.users(id)
    on delete set null,

  published_at timestamptz,

  created_at timestamptz not null
    default now(),

  updated_at timestamptz not null
    default now(),

  constraint report_cards_attendance_sick_check
    check (attendance_sick >= 0),

  constraint report_cards_attendance_permission_check
    check (attendance_permission >= 0),

  constraint report_cards_attendance_absent_check
    check (attendance_absent >= 0),

  constraint report_cards_issue_date_check
    check (
      issue_date is null
      or status <> 'draft'
    ),

  constraint report_cards_finalized_check
    check (
      (
        status = 'draft'
        and finalized_at is null
      )
      or
      (
        status in ('final', 'diterbitkan')
        and finalized_at is not null
      )
    ),

  constraint report_cards_published_check
    check (
      (
        status <> 'diterbitkan'
        and published_at is null
      )
      or
      (
        status = 'diterbitkan'
        and published_at is not null
      )
    )
);


/* =========================================================
   3. UNIQUE RAPOR
   =========================================================

   Satu siswa hanya memiliki satu rapor untuk:
   - tahun ajaran
   - semester
*/

create unique index if not exists
  uq_report_cards_student_year_semester
on public.report_cards(
  student_id,
  academic_year_id,
  semester
);


/* =========================================================
   4. INDEX REPORT CARDS
   ========================================================= */

create index if not exists
  idx_report_cards_student
on public.report_cards(student_id);

create index if not exists
  idx_report_cards_academic_year
on public.report_cards(academic_year_id);

create index if not exists
  idx_report_cards_class
on public.report_cards(class_id);

create index if not exists
  idx_report_cards_semester
on public.report_cards(semester);

create index if not exists
  idx_report_cards_status
on public.report_cards(status);

create index if not exists
  idx_report_cards_homeroom_teacher
on public.report_cards(homeroom_teacher_id);


/* =========================================================
   5. TABLE REPORT CARD DETAILS
   ========================================================= */

create table if not exists public.report_card_details (
  id uuid primary key default gen_random_uuid(),

  report_card_id uuid not null
    references public.report_cards(id)
    on delete restrict,

  subject_id uuid not null
    references public.subjects(id)
    on delete restrict,

  subject_name_snapshot text not null,

  subject_code_snapshot text,

  score numeric(5,2) not null,

  minimum_passing_grade numeric(5,2),

  grade_predicate text,

  teacher_note text,

  description text,

  created_at timestamptz not null
    default now(),

  updated_at timestamptz not null
    default now(),

  constraint report_card_details_score_check
    check (
      score >= 0
      and score <= 100
    ),

  constraint report_card_details_minimum_grade_check
    check (
      minimum_passing_grade is null
      or (
        minimum_passing_grade >= 0
        and minimum_passing_grade <= 100
      )
    ),

  constraint report_card_details_subject_name_check
    check (
      length(trim(subject_name_snapshot)) > 0
    )
);


/* =========================================================
   6. UNIQUE DETAIL RAPOR
   ========================================================= */

create unique index if not exists
  uq_report_card_details_subject
on public.report_card_details(
  report_card_id,
  subject_id
);


/* =========================================================
   7. INDEX REPORT CARD DETAILS
   ========================================================= */

create index if not exists
  idx_report_card_details_report_card
on public.report_card_details(report_card_id);

create index if not exists
  idx_report_card_details_subject
on public.report_card_details(subject_id);


/* =========================================================
   8. UPDATED_AT REPORT CARDS
   ========================================================= */

drop trigger if exists
  report_cards_set_updated_at
on public.report_cards;

create trigger report_cards_set_updated_at
before update
on public.report_cards
for each row
execute function public.set_updated_at();


/* =========================================================
   9. UPDATED_AT REPORT CARD DETAILS
   ========================================================= */

drop trigger if exists
  report_card_details_set_updated_at
on public.report_card_details;

create trigger report_card_details_set_updated_at
before update
on public.report_card_details
for each row
execute function public.set_updated_at();


/* =========================================================
   10. VALIDASI REPORT CARD
   =========================================================

   Memastikan siswa memang terdaftar pada:
   - tahun ajaran
   - kelas
*/

create or replace function public.validate_report_card_enrollment()
returns trigger
language plpgsql
security invoker
set search_path = public
as $$
begin

  if not exists (
    select 1
    from public.student_enrollments se
    where se.student_id = new.student_id
      and se.academic_year_id = new.academic_year_id
      and se.class_id = new.class_id
  ) then

    raise exception
      using
        errcode = '23514',
        message = 'Data rapor tidak valid: siswa tidak terdaftar pada kelas dan tahun ajaran yang dipilih.',
        detail = 'Rapor harus mengacu pada student_enrollment yang sesuai.';

  end if;

  return new;
end;
$$;


/* =========================================================
   11. TRIGGER VALIDASI REPORT CARD
   ========================================================= */

drop trigger if exists
  report_cards_validate_enrollment
on public.report_cards;

create trigger report_cards_validate_enrollment
before insert or update
on public.report_cards
for each row
execute function public.validate_report_card_enrollment();


/* =========================================================
   12. VALIDASI STATUS RAPOR
   =========================================================

   Aturan:
   - Draft dapat diedit.
   - Final harus memiliki finalized_at.
   - Diterbitkan harus memiliki finalized_at dan published_at.
*/

create or replace function public.validate_report_card_status()
returns trigger
language plpgsql
security invoker
set search_path = public
as $$
begin

  if new.status = 'final'
     and new.finalized_at is null then

    raise exception
      using
        errcode = '23514',
        message = 'Rapor berstatus final harus memiliki waktu finalisasi.';

  end if;


  if new.status = 'diterbitkan'
     and (
       new.finalized_at is null
       or new.published_at is null
     ) then

    raise exception
      using
        errcode = '23514',
        message = 'Rapor berstatus diterbitkan harus memiliki waktu finalisasi dan penerbitan.';

  end if;


  return new;
end;
$$;


/* =========================================================
   13. TRIGGER VALIDASI STATUS
   ========================================================= */

drop trigger if exists
  report_cards_validate_status
on public.report_cards;

create trigger report_cards_validate_status
before insert or update
on public.report_cards
for each row
execute function public.validate_report_card_status();


/* =========================================================
   14. RLS REPORT CARDS
   ========================================================= */

alter table public.report_cards enable row level security;


/* =========================================================
   15. RLS REPORT CARD DETAILS
   ========================================================= */

alter table public.report_card_details enable row level security;


/* =========================================================
   16. SELECT REPORT CARDS
   ========================================================= */

drop policy if exists
  report_cards_select
on public.report_cards;

create policy report_cards_select
on public.report_cards
for select
to authenticated
using (
  public.has_permission('akademik', 'view')
);


/* =========================================================
   17. INSERT REPORT CARDS
   ========================================================= */

drop policy if exists
  report_cards_insert
on public.report_cards;

create policy report_cards_insert
on public.report_cards
for insert
to authenticated
with check (
  public.has_permission('akademik', 'create')
);


/* =========================================================
   18. UPDATE REPORT CARDS
   ========================================================= */

drop policy if exists
  report_cards_update
on public.report_cards;

create policy report_cards_update
on public.report_cards
for update
to authenticated
using (
  public.has_permission('akademik', 'update')
)
with check (
  public.has_permission('akademik', 'update')
);


/* =========================================================
   19. DELETE REPORT CARDS
   =========================================================

   Rapor yang sudah final/diterbitkan tidak boleh
   dihapus melalui RLS.

   Draft masih dapat dihapus oleh pengguna yang
   memiliki permission delete.
*/

drop policy if exists
  report_cards_delete
on public.report_cards;

create policy report_cards_delete
on public.report_cards
for delete
to authenticated
using (
  public.has_permission('akademik', 'delete')
  and status = 'draft'
);


/* =========================================================
   20. SELECT REPORT CARD DETAILS
   ========================================================= */

drop policy if exists
  report_card_details_select
on public.report_card_details;

create policy report_card_details_select
on public.report_card_details
for select
to authenticated
using (
  public.has_permission('akademik', 'view')
);


/* =========================================================
   21. INSERT REPORT CARD DETAILS
   ========================================================= */

drop policy if exists
  report_card_details_insert
on public.report_card_details;

create policy report_card_details_insert
on public.report_card_details
for insert
to authenticated
with check (
  public.has_permission('akademik', 'create')
  and exists (
    select 1
    from public.report_cards rc
    where rc.id = report_card_id
      and rc.status = 'draft'
  )
);


/* =========================================================
   22. UPDATE REPORT CARD DETAILS
   ========================================================= */

drop policy if exists
  report_card_details_update
on public.report_card_details;

create policy report_card_details_update
on public.report_card_details
for update
to authenticated
using (
  public.has_permission('akademik', 'update')
  and exists (
    select 1
    from public.report_cards rc
    where rc.id = report_card_id
      and rc.status = 'draft'
  )
)
with check (
  public.has_permission('akademik', 'update')
  and exists (
    select 1
    from public.report_cards rc
    where rc.id = report_card_id
      and rc.status = 'draft'
  )
);


/* =========================================================
   23. DELETE REPORT CARD DETAILS
   ========================================================= */

drop policy if exists
  report_card_details_delete
on public.report_card_details;

create policy report_card_details_delete
on public.report_card_details
for delete
to authenticated
using (
  public.has_permission('akademik', 'delete')
  and exists (
    select 1
    from public.report_cards rc
    where rc.id = report_card_id
      and rc.status = 'draft'
  )
);


/* =========================================================
   24. GRANTS
   ========================================================= */

grant select, insert, update, delete
on public.report_cards
to authenticated;

grant select, insert, update, delete
on public.report_card_details
to authenticated;


/* =========================================================
   25. FUNCTION GRANTS
   ========================================================= */

grant execute
on function public.validate_report_card_enrollment()
to authenticated;

grant execute
on function public.validate_report_card_status()
to authenticated;


/* =========================================================
   26. COMMENTS
   ========================================================= */

comment on table public.report_cards is
  'Header rapor siswa berdasarkan tahun ajaran dan semester.';

comment on table public.report_card_details is
  'Detail nilai rapor yang menyimpan snapshot nilai saat rapor dibuat.';

comment on column public.report_cards.status is
  'Status rapor: draft, final, atau diterbitkan.';

comment on column public.report_cards.report_number is
  'Nomor rapor/dokumen jika sekolah menggunakan nomor rapor.';

comment on column public.report_cards.homeroom_teacher_note is
  'Catatan wali kelas pada rapor.';

comment on column public.report_cards.principal_note is
  'Catatan kepala sekolah pada rapor.';

comment on column public.report_card_details.subject_name_snapshot is
  'Nama mata pelajaran saat rapor diterbitkan/disimpan.';

comment on column public.report_card_details.subject_code_snapshot is
  'Kode mata pelajaran saat rapor diterbitkan/disimpan.';

comment on column public.report_card_details.score is
  'Snapshot nilai rapor dengan rentang 0 sampai 100.';

comment on column public.report_card_details.minimum_passing_grade is
  'Snapshot nilai minimum yang digunakan pada saat rapor dibuat.';

comment on column public.report_card_details.grade_predicate is
  'Predikat nilai jika digunakan oleh sistem sekolah.';


/* =========================================================
   MIGRATION SELESAI
   ========================================================= */