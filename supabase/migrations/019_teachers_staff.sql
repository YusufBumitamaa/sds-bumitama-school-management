/*
  Migration 019
  Teachers & Staff

  Sumber acuan:
  - PRD v4.0
  - Master Technical Blueprint v1.0
  - Database Blueprint v1.0

  Fungsi:
  - Menyimpan master data Guru dan Tenaga Kependidikan.
  - Menjadi referensi untuk:
      - Penugasan Guru
      - Wali Kelas
      - Jadwal Pelajaran
      - Kehadiran GTK
      - Data GTK lainnya
*/


/* =========================================================
   1. ENUM STAFF TYPE
   ========================================================= */

do $$
begin
  if not exists (
    select 1
    from pg_type
    where typname = 'staff_type'
      and typnamespace = 'public'::regnamespace
  ) then
    create type public.staff_type as enum (
      'guru',
      'tendik'
    );
  end if;
end
$$;


/* =========================================================
   2. TABLE: teachers_staff
   ========================================================= */

create table if not exists public.teachers_staff (
  id uuid primary key default gen_random_uuid(),

  employee_number text,

  nik text,

  full_name text not null,

  nickname text,

  staff_type public.staff_type not null default 'guru',

  gender text,

  birth_place text,

  birth_date date,

  religion text,

  education text,

  major text,

  employment_status text,

  appointment_date date,

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

  position text,

  subjects_taught text,

  certification_status text,

  certification_number text,

  is_active boolean not null default true,

  notes text,

  created_at timestamptz not null default now(),

  updated_at timestamptz not null default now(),

  constraint teachers_staff_gender_check
    check (
      gender is null
      or gender in ('L', 'P')
    )
);


/* =========================================================
   3. COMMENTS
   ========================================================= */

comment on table public.teachers_staff is
  'Master data Guru dan Tenaga Kependidikan sekolah.';

comment on column public.teachers_staff.employee_number is
  'Nomor identitas kepegawaian, misalnya NIP atau nomor pegawai yayasan.';

comment on column public.teachers_staff.nik is
  'Nomor Induk Kependudukan.';

comment on column public.teachers_staff.staff_type is
  'Jenis personel: guru atau tenaga kependidikan.';

comment on column public.teachers_staff.education is
  'Jenjang pendidikan terakhir.';

comment on column public.teachers_staff.major is
  'Jurusan atau bidang pendidikan terakhir.';

comment on column public.teachers_staff.employment_status is
  'Status kepegawaian, misalnya PNS, PPPK, GTY, GTT, atau lainnya.';

comment on column public.teachers_staff.position is
  'Jabatan atau tugas utama personel.';

comment on column public.teachers_staff.subjects_taught is
  'Informasi mata pelajaran yang diajarkan secara umum. Penugasan resmi disimpan pada teacher_assignments.';

comment on column public.teachers_staff.certification_status is
  'Status sertifikasi guru.';

comment on column public.teachers_staff.is_active is
  'Menentukan apakah personel masih aktif di sekolah.';


/* =========================================================
   4. INDEXES
   ========================================================= */

create index if not exists
  teachers_staff_employee_number_idx
on public.teachers_staff(employee_number);

create index if not exists
  teachers_staff_nik_idx
on public.teachers_staff(nik);

create index if not exists
  teachers_staff_full_name_idx
on public.teachers_staff(full_name);

create index if not exists
  teachers_staff_type_idx
on public.teachers_staff(staff_type);

create index if not exists
  teachers_staff_active_idx
on public.teachers_staff(is_active);

create index if not exists
  teachers_staff_email_idx
on public.teachers_staff(email);


/* =========================================================
   5. UPDATED_AT TRIGGER
   ========================================================= */

drop trigger if exists
  teachers_staff_set_updated_at
on public.teachers_staff;

create trigger teachers_staff_set_updated_at
before update on public.teachers_staff
for each row
execute function public.set_updated_at();


/* =========================================================
   6. ROW LEVEL SECURITY
   ========================================================= */

alter table public.teachers_staff enable row level security;


/* =========================================================
   7. SELECT POLICY
   ========================================================= */

drop policy if exists
  teachers_staff_select_with_permission
on public.teachers_staff;

create policy teachers_staff_select_with_permission
on public.teachers_staff
for select
to authenticated
using (
  public.is_super_admin()
  or public.has_permission('gtk', 'view')
);


/* =========================================================
   8. INSERT POLICY
   ========================================================= */

drop policy if exists
  teachers_staff_insert_with_permission
on public.teachers_staff;

create policy teachers_staff_insert_with_permission
on public.teachers_staff
for insert
to authenticated
with check (
  public.is_super_admin()
  or public.has_permission('gtk', 'create')
);


/* =========================================================
   9. UPDATE POLICY
   ========================================================= */

drop policy if exists
  teachers_staff_update_with_permission
on public.teachers_staff;

create policy teachers_staff_update_with_permission
on public.teachers_staff
for update
to authenticated
using (
  public.is_super_admin()
  or public.has_permission('gtk', 'update')
)
with check (
  public.is_super_admin()
  or public.has_permission('gtk', 'update')
);


/* =========================================================
   10. DELETE POLICY
   ========================================================= */

drop policy if exists
  teachers_staff_delete_with_permission
on public.teachers_staff;

create policy teachers_staff_delete_with_permission
on public.teachers_staff
for delete
to authenticated
using (
  public.is_super_admin()
  or public.has_permission('gtk', 'delete')
);


/* =========================================================
   11. GRANTS
   ========================================================= */

grant select, insert, update, delete
on public.teachers_staff
to authenticated;