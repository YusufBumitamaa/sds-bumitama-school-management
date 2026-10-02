/*
  Migration 040
  School Profile / Profil Sekolah

  Sumber acuan:
  - PRD v4.0
  - Master Technical Blueprint v1.0
  - Database Blueprint v1.0

  Fungsi:
  - Menyimpan identitas resmi sekolah.
  - Menyimpan alamat dan kontak sekolah.
  - Menyimpan informasi legalitas dan identitas satuan pendidikan.
  - Menjadi sumber data utama untuk dokumen dan laporan sekolah.
*/


/* =========================================================
   1. TABLE SCHOOL PROFILE
   ========================================================= */

create table if not exists public.school_profile (
  id uuid primary key default gen_random_uuid(),

  school_name text not null,

  school_short_name text,

  school_level text,

  npsn text,

  nss text,

  nss_nis text,

  accreditation text,

  accreditation_year integer,

  establishment_date date,

  operational_license_number text,

  operational_license_date date,

  principal_name text,

  principal_nip text,

  email text,

  phone text,

  website text,

  address text,

  rt text,

  rw text,

  village text,

  district text,

  regency text,

  province text,

  postal_code text,

  latitude numeric(10,7),

  longitude numeric(10,7),

  logo_url text,

  school_photo_url text,

  vision text,

  mission text,

  history text,

  description text,

  notes text,

  created_at timestamptz not null
    default now(),

  updated_at timestamptz not null
    default now(),

  constraint school_profile_name_check
    check (
      length(trim(school_name)) > 0
    ),

  constraint school_profile_accreditation_year_check
    check (
      accreditation_year is null
      or (
        accreditation_year >= 1900
        and accreditation_year <= 2100
      )
    ),

  constraint school_profile_latitude_check
    check (
      latitude is null
      or (
        latitude >= -90
        and latitude <= 90
      )
    ),

  constraint school_profile_longitude_check
    check (
      longitude is null
      or (
        longitude >= -180
        and longitude <= 180
      )
    )
);


/* =========================================================
   2. UNIQUE IDENTIFIERS
   ========================================================= */

create unique index if not exists
  uq_school_profile_npsn
on public.school_profile(npsn)
where npsn is not null
  and length(trim(npsn)) > 0;

create unique index if not exists
  uq_school_profile_nss
on public.school_profile(nss)
where nss is not null
  and length(trim(nss)) > 0;


/* =========================================================
   3. INDEXES
   ========================================================= */

create index if not exists
  idx_school_profile_name
on public.school_profile(school_name);

create index if not exists
  idx_school_profile_province
on public.school_profile(province);

create index if not exists
  idx_school_profile_regency
on public.school_profile(regency);


/* =========================================================
   4. UPDATED_AT TRIGGER
   ========================================================= */

drop trigger if exists
  school_profile_set_updated_at
on public.school_profile;

create trigger school_profile_set_updated_at
before update
on public.school_profile
for each row
execute function public.set_updated_at();


/* =========================================================
   5. ROW LEVEL SECURITY
   ========================================================= */

alter table public.school_profile
enable row level security;


/* =========================================================
   6. SELECT POLICY
   ========================================================= */

drop policy if exists
  school_profile_select
on public.school_profile;

create policy school_profile_select
on public.school_profile
for select
to authenticated
using (
  public.has_permission('profil_sekolah', 'view')
);


/* =========================================================
   7. INSERT POLICY
   ========================================================= */

drop policy if exists
  school_profile_insert
on public.school_profile;

create policy school_profile_insert
on public.school_profile
for insert
to authenticated
with check (
  public.has_permission('profil_sekolah', 'create')
);


/* =========================================================
   8. UPDATE POLICY
   ========================================================= */

drop policy if exists
  school_profile_update
on public.school_profile;

create policy school_profile_update
on public.school_profile
for update
to authenticated
using (
  public.has_permission('profil_sekolah', 'update')
)
with check (
  public.has_permission('profil_sekolah', 'update')
);


/* =========================================================
   9. DELETE POLICY
   ========================================================= */

drop policy if exists
  school_profile_delete
on public.school_profile;

create policy school_profile_delete
on public.school_profile
for delete
to authenticated
using (
  public.has_permission('profil_sekolah', 'delete')
);


/* =========================================================
   10. GRANTS
   ========================================================= */

grant select, insert, update, delete
on public.school_profile
to authenticated;


/* =========================================================
   11. COMMENTS
   ========================================================= */

comment on table public.school_profile is
  'Profil dan identitas resmi satuan pendidikan.';

comment on column public.school_profile.school_name is
  'Nama resmi sekolah.';

comment on column public.school_profile.school_short_name is
  'Nama singkat sekolah.';

comment on column public.school_profile.school_level is
  'Jenjang satuan pendidikan.';

comment on column public.school_profile.npsn is
  'Nomor Pokok Sekolah Nasional.';

comment on column public.school_profile.nss is
  'Nomor Statistik Sekolah.';

comment on column public.school_profile.nss_nis is
  'Nomor statistik atau identitas sekolah tambahan jika diperlukan.';

comment on column public.school_profile.accreditation is
  'Status atau peringkat akreditasi sekolah.';

comment on column public.school_profile.accreditation_year is
  'Tahun akreditasi.';

comment on column public.school_profile.operational_license_number is
  'Nomor izin operasional sekolah.';

comment on column public.school_profile.operational_license_date is
  'Tanggal izin operasional.';

comment on column public.school_profile.principal_name is
  'Nama kepala sekolah.';

comment on column public.school_profile.principal_nip is
  'NIP kepala sekolah jika tersedia.';

comment on column public.school_profile.logo_url is
  'Lokasi logo sekolah pada storage/digital archive.';

comment on column public.school_profile.school_photo_url is
  'Lokasi foto sekolah pada storage/digital archive.';

comment on column public.school_profile.vision is
  'Visi sekolah.';

comment on column public.school_profile.mission is
  'Misi sekolah.';

comment on column public.school_profile.history is
  'Sejarah singkat sekolah.';

comment on column public.school_profile.description is
  'Deskripsi umum sekolah.';


/* =========================================================
   MIGRATION SELESAI
   ========================================================= */