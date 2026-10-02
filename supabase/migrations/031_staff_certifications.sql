/*
  Migration 031
  Staff Certifications / Sertifikasi GTK

  Sumber acuan:
  - PRD v4.0
  - Master Technical Blueprint v1.0
  - Database Blueprint v1.0

  Fungsi:
  - Menyimpan riwayat sertifikasi Guru/Tendik.
  - Mendukung lebih dari satu sertifikasi untuk satu GTK.
  - Menyimpan informasi sertifikat dan dokumen pendukung.
*/


/* =========================================================
   1. ENUM JENIS SERTIFIKASI
   ========================================================= */

do $$
begin
  if not exists (
    select 1
    from pg_type
    where typname = 'staff_certification_type'
      and typnamespace = 'public'::regnamespace
  ) then

    create type public.staff_certification_type as enum (
      'sertifikasi_pendidik',
      'sertifikasi_profesi',
      'kompetensi',
      'pelatihan',
      'lainnya'
    );

  end if;
end
$$;


/* =========================================================
   2. ENUM STATUS SERTIFIKASI
   ========================================================= */

do $$
begin
  if not exists (
    select 1
    from pg_type
    where typname = 'staff_certification_status'
      and typnamespace = 'public'::regnamespace
  ) then

    create type public.staff_certification_status as enum (
      'aktif',
      'berakhir',
      'dicabut',
      'lainnya'
    );

  end if;
end
$$;


/* =========================================================
   3. TABLE STAFF CERTIFICATIONS
   ========================================================= */

create table if not exists public.staff_certifications (
  id uuid primary key default gen_random_uuid(),

  staff_id uuid not null
    references public.teachers_staff(id)
    on delete restrict,

  certification_type public.staff_certification_type not null,

  certification_name text not null,

  certification_field text,

  issuing_institution text,

  certificate_number text,

  participant_number text,

  certification_year integer,

  issue_date date,

  expiry_date date,

  status public.staff_certification_status not null
    default 'aktif',

  document_url text,

  notes text,

  created_at timestamptz not null
    default now(),

  updated_at timestamptz not null
    default now(),

  constraint staff_certification_year_check
    check (
      certification_year is null
      or (
        certification_year >= 1900
        and certification_year <= 2100
      )
    ),

  constraint staff_certification_date_check
    check (
      expiry_date is null
      or issue_date is null
      or expiry_date >= issue_date
    ),

  constraint staff_certification_name_check
    check (
      length(trim(certification_name)) > 0
    )
);


/* =========================================================
   4. INDEXES
   ========================================================= */

create index if not exists
  idx_staff_certifications_staff
on public.staff_certifications(staff_id);

create index if not exists
  idx_staff_certifications_type
on public.staff_certifications(certification_type);

create index if not exists
  idx_staff_certifications_status
on public.staff_certifications(status);

create index if not exists
  idx_staff_certifications_year
on public.staff_certifications(certification_year);

create index if not exists
  idx_staff_certifications_issue_date
on public.staff_certifications(issue_date);

create index if not exists
  idx_staff_certifications_expiry_date
on public.staff_certifications(expiry_date);


/* =========================================================
   5. UPDATED_AT TRIGGER
   ========================================================= */

drop trigger if exists
  staff_certifications_set_updated_at
on public.staff_certifications;

create trigger staff_certifications_set_updated_at
before update
on public.staff_certifications
for each row
execute function public.set_updated_at();


/* =========================================================
   6. ROW LEVEL SECURITY
   ========================================================= */

alter table public.staff_certifications enable row level security;


/* =========================================================
   7. SELECT POLICY
   ========================================================= */

drop policy if exists
  staff_certifications_select
on public.staff_certifications;

create policy staff_certifications_select
on public.staff_certifications
for select
to authenticated
using (
  public.has_permission('gtk', 'view')
);


/* =========================================================
   8. INSERT POLICY
   ========================================================= */

drop policy if exists
  staff_certifications_insert
on public.staff_certifications;

create policy staff_certifications_insert
on public.staff_certifications
for insert
to authenticated
with check (
  public.has_permission('gtk', 'create')
);


/* =========================================================
   9. UPDATE POLICY
   ========================================================= */

drop policy if exists
  staff_certifications_update
on public.staff_certifications;

create policy staff_certifications_update
on public.staff_certifications
for update
to authenticated
using (
  public.has_permission('gtk', 'update')
)
with check (
  public.has_permission('gtk', 'update')
);


/* =========================================================
   10. DELETE POLICY
   ========================================================= */

drop policy if exists
  staff_certifications_delete
on public.staff_certifications;

create policy staff_certifications_delete
on public.staff_certifications
for delete
to authenticated
using (
  public.has_permission('gtk', 'delete')
);


/* =========================================================
   11. GRANTS
   ========================================================= */

grant select, insert, update, delete
on public.staff_certifications
to authenticated;


/* =========================================================
   12. COMMENTS
   ========================================================= */

comment on table public.staff_certifications is
  'Riwayat sertifikasi, kompetensi, dan pelatihan Guru/Tenaga Kependidikan.';

comment on column public.staff_certifications.staff_id is
  'GTK pemilik sertifikasi.';

comment on column public.staff_certifications.certification_type is
  'Jenis sertifikasi atau pengembangan kompetensi.';

comment on column public.staff_certifications.certification_name is
  'Nama sertifikasi, kompetensi, atau pelatihan.';

comment on column public.staff_certifications.certification_field is
  'Bidang atau kompetensi sertifikasi.';

comment on column public.staff_certifications.issuing_institution is
  'Lembaga yang menerbitkan sertifikat.';

comment on column public.staff_certifications.certificate_number is
  'Nomor sertifikat.';

comment on column public.staff_certifications.participant_number is
  'Nomor peserta atau registrasi jika tersedia.';

comment on column public.staff_certifications.document_url is
  'Lokasi dokumen sertifikat pada storage/digital archive.';


/* =========================================================
   MIGRATION SELESAI
   ========================================================= */