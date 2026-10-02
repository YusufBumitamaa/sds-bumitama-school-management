/*
  Migration 045
  Digital Archives / Arsip Digital

  Sumber acuan:
  - PRD v4.0
  - Master Technical Blueprint v1.0
  - Database Blueprint v1.0

  Fungsi:
  - Menyediakan indeks arsip digital lintas modul.
  - Menyimpan metadata file dan lokasi penyimpanan.
  - Mendukung pengelompokan arsip berdasarkan modul,
    kategori, tahun, dan tingkat akses.
*/


/* =========================================================
   1. ENUM MODUL ARSIP
   ========================================================= */

do $$
begin
  if not exists (
    select 1
    from pg_type
    where typname = 'archive_module'
      and typnamespace = 'public'::regnamespace
  ) then

    create type public.archive_module as enum (
      'profil_sekolah',
      'kesiswaan',
      'kurikulum',
      'akademik',
      'gtk',
      'sarpras',
      'keuangan',
      'persuratan',
      'laporan',
      'lainnya'
    );

  end if;
end
$$;


/* =========================================================
   2. ENUM STATUS ARSIP
   ========================================================= */

do $$
begin
  if not exists (
    select 1
    from pg_type
    where typname = 'archive_status'
      and typnamespace = 'public'::regnamespace
  ) then

    create type public.archive_status as enum (
      'aktif',
      'diarsipkan',
      'kedaluwarsa',
      'dihapus'
    );

  end if;
end
$$;


/* =========================================================
   3. ENUM TINGKAT AKSES
   ========================================================= */

do $$
begin
  if not exists (
    select 1
    from pg_type
    where typname = 'archive_access_level'
      and typnamespace = 'public'::regnamespace
  ) then

    create type public.archive_access_level as enum (
      'umum',
      'internal',
      'terbatas',
      'rahasia'
    );

  end if;
end
$$;


/* =========================================================
   4. TABLE DIGITAL ARCHIVES
   ========================================================= */

create table if not exists public.digital_archives (
  id uuid primary key default gen_random_uuid(),

  archive_code text not null,

  module public.archive_module not null
    default 'lainnya',

  category text not null,

  title text not null,

  description text,

  document_number text,

  document_date date,

  academic_year_id uuid
    references public.academic_years(id)
    on delete set null,

  source_table text,

  source_record_id uuid,

  file_name text not null,

  file_path text not null,

  file_url text,

  file_size bigint,

  mime_type text,

  checksum text,

  version_number integer not null
    default 1,

  access_level public.archive_access_level not null
    default 'internal',

  status public.archive_status not null
    default 'aktif',

  archived_at timestamptz,

  retention_until date,

  notes text,

  created_by uuid
    references public.users(id)
    on delete set null,

  created_at timestamptz not null
    default now(),

  updated_at timestamptz not null
    default now(),

  constraint digital_archive_code_check
    check (
      length(trim(archive_code)) > 0
    ),

  constraint digital_archive_category_check
    check (
      length(trim(category)) > 0
    ),

  constraint digital_archive_title_check
    check (
      length(trim(title)) > 0
    ),

  constraint digital_archive_file_name_check
    check (
      length(trim(file_name)) > 0
    ),

  constraint digital_archive_file_path_check
    check (
      length(trim(file_path)) > 0
    ),

  constraint digital_archive_file_size_check
    check (
      file_size is null
      or file_size >= 0
    ),

  constraint digital_archive_version_check
    check (
      version_number > 0
    ),

  constraint digital_archive_retention_check
    check (
      retention_until is null
      or document_date is null
      or retention_until >= document_date
    ),

  constraint digital_archive_archived_at_check
    check (
      status <> 'diarsipkan'
      or archived_at is not null
    )
);


/* =========================================================
   5. UNIQUE ARCHIVE CODE
   ========================================================= */

create unique index if not exists
  uq_digital_archives_archive_code
on public.digital_archives(archive_code);


/* =========================================================
   6. INDEXES
   ========================================================= */

create index if not exists
  idx_digital_archives_module
on public.digital_archives(module);

create index if not exists
  idx_digital_archives_category
on public.digital_archives(category);

create index if not exists
  idx_digital_archives_title
on public.digital_archives(title);

create index if not exists
  idx_digital_archives_document_number
on public.digital_archives(document_number);

create index if not exists
  idx_digital_archives_document_date
on public.digital_archives(document_date);

create index if not exists
  idx_digital_archives_academic_year
on public.digital_archives(academic_year_id);

create index if not exists
  idx_digital_archives_source
on public.digital_archives(source_table, source_record_id);

create index if not exists
  idx_digital_archives_status
on public.digital_archives(status);

create index if not exists
  idx_digital_archives_access_level
on public.digital_archives(access_level);

create index if not exists
  idx_digital_archives_created_by
on public.digital_archives(created_by);


/* =========================================================
   7. UPDATED_AT TRIGGER
   ========================================================= */

drop trigger if exists
  digital_archives_set_updated_at
on public.digital_archives;

create trigger digital_archives_set_updated_at
before update
on public.digital_archives
for each row
execute function public.set_updated_at();


/* =========================================================
   8. ROW LEVEL SECURITY
   ========================================================= */

alter table public.digital_archives
enable row level security;


/* =========================================================
   9. SELECT POLICY
   ========================================================= */

drop policy if exists
  digital_archives_select
on public.digital_archives;

create policy digital_archives_select
on public.digital_archives
for select
to authenticated
using (
  public.has_permission('persuratan', 'view')
);


/* =========================================================
   10. INSERT POLICY
   ========================================================= */

drop policy if exists
  digital_archives_insert
on public.digital_archives;

create policy digital_archives_insert
on public.digital_archives
for insert
to authenticated
with check (
  public.has_permission('persuratan', 'create')
);


/* =========================================================
   11. UPDATE POLICY
   ========================================================= */

drop policy if exists
  digital_archives_update
on public.digital_archives;

create policy digital_archives_update
on public.digital_archives
for update
to authenticated
using (
  public.has_permission('persuratan', 'update')
)
with check (
  public.has_permission('persuratan', 'update')
);


/* =========================================================
   12. DELETE POLICY
   ========================================================= */

drop policy if exists
  digital_archives_delete
on public.digital_archives;

create policy digital_archives_delete
on public.digital_archives
for delete
to authenticated
using (
  public.has_permission('persuratan', 'delete')
);


/* =========================================================
   13. GRANTS
   ========================================================= */

grant select, insert, update, delete
on public.digital_archives
to authenticated;


/* =========================================================
   14. COMMENTS
   ========================================================= */

comment on table public.digital_archives is
  'Indeks arsip digital lintas modul sekolah.';

comment on column public.digital_archives.archive_code is
  'Kode unik arsip digital.';

comment on column public.digital_archives.module is
  'Modul sumber arsip.';

comment on column public.digital_archives.category is
  'Kategori arsip.';

comment on column public.digital_archives.title is
  'Judul arsip digital.';

comment on column public.digital_archives.document_number is
  'Nomor dokumen jika tersedia.';

comment on column public.digital_archives.document_date is
  'Tanggal dokumen.';

comment on column public.digital_archives.academic_year_id is
  'Tahun ajaran terkait jika ada.';

comment on column public.digital_archives.source_table is
  'Nama tabel sumber arsip jika arsip terkait record tertentu.';

comment on column public.digital_archives.source_record_id is
  'ID record sumber arsip jika tersedia.';

comment on column public.digital_archives.file_name is
  'Nama file arsip.';

comment on column public.digital_archives.file_path is
  'Path file pada storage.';

comment on column public.digital_archives.file_url is
  'URL file jika diperlukan.';

comment on column public.digital_archives.checksum is
  'Checksum file untuk verifikasi integritas.';

comment on column public.digital_archives.version_number is
  'Versi arsip digital.';

comment on column public.digital_archives.access_level is
  'Tingkat akses terhadap arsip.';

comment on column public.digital_archives.retention_until is
  'Tanggal akhir masa retensi arsip.';


/* =========================================================
   MIGRATION SELESAI
   ========================================================= */