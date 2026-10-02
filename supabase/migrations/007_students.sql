/*
  Migration 007
  Master Data Siswa

  Sumber acuan:
  - PRD v4.0
  - Master Technical Blueprint v1.0
  - Database Blueprint v1.0

  Aturan utama:
  - Status siswa: aktif, lulus, pindah, keluar.
  - Hanya status aktif yang dihitung sebagai siswa aktif.
  - Data siswa tidak dihapus ketika status berubah.
  - Riwayat perubahan status akan disimpan pada tabel
    student_status_history pada migration berikutnya.
*/

create type public.student_status as enum (
  'aktif',
  'lulus',
  'pindah',
  'keluar'
);

create table public.students (
  id uuid primary key default gen_random_uuid(),

  /*
    Identitas utama sekolah.
    NIS dibuat sebagai identitas internal sekolah.
  */
  nis text not null unique,

  /*
    NISN bersifat nasional dan dapat belum tersedia
    untuk siswa tertentu.
  */
  nisn text unique,

  /*
    Identitas pribadi siswa.
  */
  nik text unique,
  full_name text not null,
  nickname text,

  gender text not null
    check (gender in ('L', 'P')),

  birth_place text,
  birth_date date,

  /*
    Informasi tambahan identitas.
  */
  religion text,
  family_card_number text,
  birth_certificate_number text,

  /*
    Kontak dan alamat.
  */
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

  /*
    Status adalah sumber utama untuk menentukan
    apakah siswa masih aktif.
  */
  status public.student_status not null default 'aktif',

  /*
    Tanggal masuk dan keluar dicatat untuk histori.
  */
  admission_date date,
  exit_date date,

  /*
    Keterangan tambahan.
  */
  notes text,

  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),

  constraint students_admission_date_check
    check (
      exit_date is null
      or admission_date is null
      or exit_date >= admission_date
    )
);

comment on table public.students is
  'Master data siswa SDS Bumitama. Hanya siswa dengan status aktif yang dihitung sebagai siswa aktif.';

comment on column public.students.status is
  'Status siswa: aktif, lulus, pindah, keluar. Hanya aktif dihitung sebagai siswa aktif.';

comment on column public.students.nis is
  'Nomor Induk Siswa internal sekolah.';

comment on column public.students.nisn is
  'Nomor Induk Siswa Nasional.';

comment on column public.students.nik is
  'Nomor Induk Kependudukan siswa.';

create index students_status_idx
  on public.students(status);

create index students_full_name_idx
  on public.students(full_name);

create index students_nisn_idx
  on public.students(nisn);

create index students_nik_idx
  on public.students(nik);

create index students_birth_date_idx
  on public.students(birth_date);

create trigger students_set_updated_at
before update on public.students
for each row
execute function public.set_updated_at();

alter table public.students enable row level security;

create policy students_select_with_permission
on public.students
for select
to authenticated
using (
  public.has_permission(
    'kesiswaan',
    'view'
  )
);

create policy students_insert_with_permission
on public.students
for insert
to authenticated
with check (
  public.has_permission(
    'kesiswaan',
    'create'
  )
);

create policy students_update_with_permission
on public.students
for update
to authenticated
using (
  public.has_permission(
    'kesiswaan',
    'update'
  )
)
with check (
  public.has_permission(
    'kesiswaan',
    'update'
  )
);

create policy students_delete_with_permission
on public.students
for delete
to authenticated
using (
  public.has_permission(
    'kesiswaan',
    'delete'
  )
);

grant select on table public.students to authenticated;
grant insert on table public.students to authenticated;
grant update on table public.students to authenticated;
grant delete on table public.students to authenticated;