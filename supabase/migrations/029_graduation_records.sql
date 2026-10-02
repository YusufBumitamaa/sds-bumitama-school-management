/*
  Migration 029
  Graduation Records / Kelulusan Siswa

  Sumber acuan:
  - PRD v4.0
  - Master Technical Blueprint v1.0
  - Database Blueprint v1.0

  Fungsi:
  - Menyimpan keputusan kelulusan siswa.
  - Mempertahankan histori kelulusan.
  - Menghubungkan siswa dengan tahun ajaran dan rombel terakhir.
  - Menyimpan informasi dokumen kelulusan.

  Catatan:
  - Migration ini TIDAK otomatis mengubah students.status.
  - Perubahan status siswa menjadi "lulus" akan dilakukan
    melalui alur aplikasi yang terkontrol.
*/


/* =========================================================
   1. ENUM STATUS KELULUSAN
   ========================================================= */

do $$
begin
  if not exists (
    select 1
    from pg_type
    where typname = 'graduation_status'
      and typnamespace = 'public'::regnamespace
  ) then

    create type public.graduation_status as enum (
      'lulus',
      'tidak_lulus'
    );

  end if;
end
$$;


/* =========================================================
   2. TABLE GRADUATION RECORDS
   ========================================================= */

create table if not exists public.graduation_records (
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

  status public.graduation_status not null,

  decision_date date not null,

  document_number text,

  document_date date,

  notes text,

  decided_by uuid
    references public.users(id)
    on delete set null,

  created_at timestamptz not null
    default now(),

  updated_at timestamptz not null
    default now(),

  constraint graduation_document_date_check
    check (
      document_date is null
      or document_date <= decision_date
    )
);


/* =========================================================
   3. UNIQUE KELULUSAN
   =========================================================

   Satu siswa memiliki satu keputusan kelulusan
   untuk satu tahun ajaran.
*/

create unique index if not exists
  uq_graduation_records_student_year
on public.graduation_records(
  student_id,
  academic_year_id
);


/* =========================================================
   4. INDEXES
   ========================================================= */

create index if not exists
  idx_graduation_records_student
on public.graduation_records(student_id);

create index if not exists
  idx_graduation_records_academic_year
on public.graduation_records(academic_year_id);

create index if not exists
  idx_graduation_records_class
on public.graduation_records(class_id);

create index if not exists
  idx_graduation_records_status
on public.graduation_records(status);

create index if not exists
  idx_graduation_records_decision_date
on public.graduation_records(decision_date);

create index if not exists
  idx_graduation_records_decided_by
on public.graduation_records(decided_by);


/* =========================================================
   5. UPDATED_AT TRIGGER
   ========================================================= */

drop trigger if exists
  graduation_records_set_updated_at
on public.graduation_records;

create trigger graduation_records_set_updated_at
before update
on public.graduation_records
for each row
execute function public.set_updated_at();


/* =========================================================
   6. VALIDASI ENROLLMENT
   =========================================================

   Memastikan siswa memang terdaftar pada:
   - tahun ajaran kelulusan
   - rombel terakhir
*/

create or replace function public.validate_graduation_enrollment()
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
        message = 'Data kelulusan tidak valid: siswa tidak terdaftar pada kelas dan tahun ajaran yang dipilih.',
        detail = 'Graduation record harus mengacu pada student_enrollment yang sesuai.';

  end if;

  return new;
end;
$$;


/* =========================================================
   7. TRIGGER VALIDASI ENROLLMENT
   ========================================================= */

drop trigger if exists
  graduation_records_validate_enrollment
on public.graduation_records;

create trigger graduation_records_validate_enrollment
before insert or update
on public.graduation_records
for each row
execute function public.validate_graduation_enrollment();


/* =========================================================
   8. VALIDASI STATUS SISWA
   =========================================================

   Kelulusan hanya dapat dicatat untuk siswa yang
   pada saat proses belum berstatus "lulus".

   Siswa dengan status:
   - aktif
   - pindah
   - keluar

   masih dapat memiliki proses administratif yang
   diverifikasi oleh aplikasi.

   Siswa yang sudah "lulus" tidak boleh dibuatkan
   keputusan kelulusan kedua untuk tahun ajaran yang sama.
   Unique index juga menjaga aturan tersebut.
*/

create or replace function public.validate_graduation_student()
returns trigger
language plpgsql
security invoker
set search_path = public
as $$
declare
  current_student_status public.student_status;
begin

  select status
  into current_student_status
  from public.students
  where id = new.student_id;

  if current_student_status is null then

    raise exception
      using
        errcode = '23514',
        message = 'Siswa tidak ditemukan.';

  end if;


  /*
    Siswa yang sudah lulus tidak boleh dibuatkan
    proses kelulusan baru.
  */

  if current_student_status = 'lulus' then

    raise exception
      using
        errcode = '23514',
        message = 'Siswa sudah berstatus lulus.',
        detail = 'Gunakan histori kelulusan yang sudah ada dan jangan membuat keputusan kelulusan baru.';

  end if;


  return new;
end;
$$;


/* =========================================================
   9. TRIGGER VALIDASI SISWA
   ========================================================= */

drop trigger if exists
  graduation_records_validate_student
on public.graduation_records;

create trigger graduation_records_validate_student
before insert or update
on public.graduation_records
for each row
execute function public.validate_graduation_student();


/* =========================================================
   10. ROW LEVEL SECURITY
   ========================================================= */

alter table public.graduation_records enable row level security;


/* =========================================================
   11. SELECT POLICY
   ========================================================= */

drop policy if exists
  graduation_records_select
on public.graduation_records;

create policy graduation_records_select
on public.graduation_records
for select
to authenticated
using (
  public.has_permission('akademik', 'view')
);


/* =========================================================
   12. INSERT POLICY
   ========================================================= */

drop policy if exists
  graduation_records_insert
on public.graduation_records;

create policy graduation_records_insert
on public.graduation_records
for insert
to authenticated
with check (
  public.has_permission('akademik', 'create')
);


/* =========================================================
   13. UPDATE POLICY
   ========================================================= */

drop policy if exists
  graduation_records_update
on public.graduation_records;

create policy graduation_records_update
on public.graduation_records
for update
to authenticated
using (
  public.has_permission('akademik', 'update')
)
with check (
  public.has_permission('akademik', 'update')
);


/* =========================================================
   14. DELETE POLICY
   =========================================================

   Data kelulusan merupakan histori akademik.
   Penghapusan tetap membutuhkan permission delete.
*/

drop policy if exists
  graduation_records_delete
on public.graduation_records;

create policy graduation_records_delete
on public.graduation_records
for delete
to authenticated
using (
  public.has_permission('akademik', 'delete')
);


/* =========================================================
   15. GRANTS
   ========================================================= */

grant select, insert, update, delete
on public.graduation_records
to authenticated;


/* =========================================================
   16. FUNCTION GRANTS
   ========================================================= */

grant execute
on function public.validate_graduation_enrollment()
to authenticated;

grant execute
on function public.validate_graduation_student()
to authenticated;


/* =========================================================
   17. COMMENTS
   ========================================================= */

comment on table public.graduation_records is
  'Riwayat keputusan kelulusan siswa berdasarkan tahun ajaran.';

comment on column public.graduation_records.student_id is
  'Siswa yang mendapatkan keputusan kelulusan.';

comment on column public.graduation_records.academic_year_id is
  'Tahun ajaran saat keputusan kelulusan dibuat.';

comment on column public.graduation_records.class_id is
  'Rombel terakhir siswa pada tahun ajaran kelulusan.';

comment on column public.graduation_records.status is
  'Status keputusan: lulus atau tidak_lulus.';

comment on column public.graduation_records.decision_date is
  'Tanggal keputusan kelulusan.';

comment on column public.graduation_records.document_number is
  'Nomor dokumen/SK kelulusan jika tersedia.';

comment on column public.graduation_records.document_date is
  'Tanggal dokumen/SK kelulusan.';

comment on column public.graduation_records.decided_by is
  'User yang menetapkan keputusan kelulusan.';


/* =========================================================
   MIGRATION SELESAI
   ========================================================= */