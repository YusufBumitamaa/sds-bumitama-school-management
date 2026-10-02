/*
  Migration 028
  Promotion Records / Kenaikan Kelas

  Sumber acuan:
  - PRD v4.0
  - Master Technical Blueprint v1.0
  - Database Blueprint v1.0

  Fungsi:
  - Menyimpan keputusan kenaikan kelas siswa.
  - Mempertahankan histori keputusan akademik.
  - Menghubungkan tahun ajaran asal dengan tahun ajaran tujuan.
  - Menghubungkan kelas asal dengan kelas tujuan.
*/


/* =========================================================
   1. ENUM KEPUTUSAN KENAIKAN
   ========================================================= */

do $$
begin
  if not exists (
    select 1
    from pg_type
    where typname = 'promotion_decision'
      and typnamespace = 'public'::regnamespace
  ) then

    create type public.promotion_decision as enum (
      'naik',
      'tidak_naik',
      'mengulang'
    );

  end if;
end
$$;


/* =========================================================
   2. TABLE PROMOTION RECORDS
   ========================================================= */

create table if not exists public.promotion_records (
  id uuid primary key default gen_random_uuid(),

  student_id uuid not null
    references public.students(id)
    on delete restrict,

  from_academic_year_id uuid not null
    references public.academic_years(id)
    on delete restrict,

  from_class_id uuid not null
    references public.classes(id)
    on delete restrict,

  to_academic_year_id uuid
    references public.academic_years(id)
    on delete restrict,

  to_class_id uuid
    references public.classes(id)
    on delete restrict,

  decision public.promotion_decision not null,

  decision_date date not null,

  notes text,

  decided_by uuid
    references public.users(id)
    on delete set null,

  created_at timestamptz not null
    default now(),

  updated_at timestamptz not null
    default now(),

  constraint promotion_records_date_check
    check (
      decision_date is not null
    ),

  constraint promotion_records_target_check
    check (
      (
        decision = 'naik'
        and to_academic_year_id is not null
        and to_class_id is not null
      )
      or
      (
        decision in ('tidak_naik', 'mengulang')
      )
    )
);


/* =========================================================
   3. UNIQUE KEPUTUSAN
   =========================================================

   Satu siswa hanya memiliki satu keputusan kenaikan
   untuk satu tahun ajaran asal.
*/

create unique index if not exists
  uq_promotion_records_student_from_year
on public.promotion_records(
  student_id,
  from_academic_year_id
);


/* =========================================================
   4. INDEXES
   ========================================================= */

create index if not exists
  idx_promotion_records_student
on public.promotion_records(student_id);

create index if not exists
  idx_promotion_records_from_year
on public.promotion_records(from_academic_year_id);

create index if not exists
  idx_promotion_records_from_class
on public.promotion_records(from_class_id);

create index if not exists
  idx_promotion_records_to_year
on public.promotion_records(to_academic_year_id);

create index if not exists
  idx_promotion_records_to_class
on public.promotion_records(to_class_id);

create index if not exists
  idx_promotion_records_decision
on public.promotion_records(decision);

create index if not exists
  idx_promotion_records_decision_date
on public.promotion_records(decision_date);

create index if not exists
  idx_promotion_records_decided_by
on public.promotion_records(decided_by);


/* =========================================================
   5. UPDATED_AT TRIGGER
   ========================================================= */

drop trigger if exists
  promotion_records_set_updated_at
on public.promotion_records;

create trigger promotion_records_set_updated_at
before update
on public.promotion_records
for each row
execute function public.set_updated_at();


/* =========================================================
   6. VALIDASI ENROLLMENT ASAL
   =========================================================

   Memastikan siswa memang terdaftar pada kelas asal
   dan tahun ajaran asal.
*/

create or replace function public.validate_promotion_source_enrollment()
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
      and se.academic_year_id = new.from_academic_year_id
      and se.class_id = new.from_class_id
  ) then

    raise exception
      using
        errcode = '23514',
        message = 'Data kenaikan kelas tidak valid: siswa tidak terdaftar pada kelas asal dan tahun ajaran asal.',
        detail = 'Promotion record harus mengacu pada student_enrollment yang sesuai.';

  end if;

  return new;
end;
$$;


/* =========================================================
   7. VALIDASI ENROLLMENT TUJUAN
   =========================================================

   Untuk keputusan "naik", siswa harus memiliki kelas tujuan
   yang berada pada tahun ajaran tujuan.

   Belum mewajibkan student_enrollment tujuan karena proses
   kenaikan kelas dapat dicatat sebelum pembagian rombel
   tahun ajaran baru selesai.
*/

create or replace function public.validate_promotion_target()
returns trigger
language plpgsql
security invoker
set search_path = public
as $$
declare
  target_class_year_id uuid;
begin

  if new.decision = 'naik' then

    select c.academic_year_id
    into target_class_year_id
    from public.classes c
    where c.id = new.to_class_id;

    if target_class_year_id is null then

      raise exception
        using
          errcode = '23514',
          message = 'Kelas tujuan tidak ditemukan.';

    end if;


    if target_class_year_id <> new.to_academic_year_id then

      raise exception
        using
          errcode = '23514',
          message = 'Kelas tujuan tidak sesuai dengan tahun ajaran tujuan.',
          detail = 'to_class_id harus berasal dari to_academic_year_id.';

    end if;

  end if;

  return new;
end;
$$;


/* =========================================================
   8. VALIDASI TAHUN AJARAN
   =========================================================

   Tahun ajaran tujuan tidak boleh sama dengan tahun ajaran
   asal untuk keputusan naik.
*/

create or replace function public.validate_promotion_academic_year()
returns trigger
language plpgsql
security invoker
set search_path = public
as $$
begin

  if new.decision = 'naik'
     and new.to_academic_year_id = new.from_academic_year_id then

    raise exception
      using
        errcode = '23514',
        message = 'Tahun ajaran tujuan harus berbeda dari tahun ajaran asal untuk keputusan naik.';

  end if;

  return new;
end;
$$;


/* =========================================================
   9. TRIGGER SOURCE ENROLLMENT
   ========================================================= */

drop trigger if exists
  promotion_records_validate_source
on public.promotion_records;

create trigger promotion_records_validate_source
before insert or update
on public.promotion_records
for each row
execute function public.validate_promotion_source_enrollment();


/* =========================================================
   10. TRIGGER TARGET
   ========================================================= */

drop trigger if exists
  promotion_records_validate_target
on public.promotion_records;

create trigger promotion_records_validate_target
before insert or update
on public.promotion_records
for each row
execute function public.validate_promotion_target();


/* =========================================================
   11. TRIGGER ACADEMIC YEAR
   ========================================================= */

drop trigger if exists
  promotion_records_validate_year
on public.promotion_records;

create trigger promotion_records_validate_year
before insert or update
on public.promotion_records
for each row
execute function public.validate_promotion_academic_year();


/* =========================================================
   12. ROW LEVEL SECURITY
   ========================================================= */

alter table public.promotion_records enable row level security;


/* =========================================================
   13. SELECT POLICY
   ========================================================= */

drop policy if exists
  promotion_records_select
on public.promotion_records;

create policy promotion_records_select
on public.promotion_records
for select
to authenticated
using (
  public.has_permission('akademik', 'view')
);


/* =========================================================
   14. INSERT POLICY
   ========================================================= */

drop policy if exists
  promotion_records_insert
on public.promotion_records;

create policy promotion_records_insert
on public.promotion_records
for insert
to authenticated
with check (
  public.has_permission('akademik', 'create')
);


/* =========================================================
   15. UPDATE POLICY
   ========================================================= */

drop policy if exists
  promotion_records_update
on public.promotion_records;

create policy promotion_records_update
on public.promotion_records
for update
to authenticated
using (
  public.has_permission('akademik', 'update')
)
with check (
  public.has_permission('akademik', 'update')
);


/* =========================================================
   16. DELETE POLICY
   =========================================================

   Histori akademik sebaiknya tidak dihapus sembarangan.
   Delete tetap dibatasi permission akademik delete.
*/

drop policy if exists
  promotion_records_delete
on public.promotion_records;

create policy promotion_records_delete
on public.promotion_records
for delete
to authenticated
using (
  public.has_permission('akademik', 'delete')
);


/* =========================================================
   17. GRANTS
   ========================================================= */

grant select, insert, update, delete
on public.promotion_records
to authenticated;


/* =========================================================
   18. FUNCTION GRANTS
   ========================================================= */

grant execute
on function public.validate_promotion_source_enrollment()
to authenticated;

grant execute
on function public.validate_promotion_target()
to authenticated;

grant execute
on function public.validate_promotion_academic_year()
to authenticated;


/* =========================================================
   19. COMMENTS
   ========================================================= */

comment on table public.promotion_records is
  'Riwayat keputusan kenaikan kelas siswa antar tahun ajaran.';

comment on column public.promotion_records.student_id is
  'Siswa yang mendapatkan keputusan kenaikan kelas.';

comment on column public.promotion_records.from_academic_year_id is
  'Tahun ajaran asal siswa.';

comment on column public.promotion_records.from_class_id is
  'Rombel asal siswa.';

comment on column public.promotion_records.to_academic_year_id is
  'Tahun ajaran tujuan jika siswa naik.';

comment on column public.promotion_records.to_class_id is
  'Rombel tujuan jika siswa naik.';

comment on column public.promotion_records.decision is
  'Keputusan: naik, tidak naik, atau mengulang.';

comment on column public.promotion_records.decision_date is
  'Tanggal keputusan kenaikan kelas.';

comment on column public.promotion_records.decided_by is
  'User yang menetapkan keputusan.';


/* =========================================================
   MIGRATION SELESAI
   ========================================================= */