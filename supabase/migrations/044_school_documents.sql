/*
  Migration 044
  School Documents / Dokumen Sekolah

  Sumber acuan:
  - PRD v4.0
  - Master Technical Blueprint v1.0
  - Database Blueprint v1.0

  Fungsi:
  - Menyimpan metadata dokumen sekolah.
  - Menjadi basis pengelolaan dokumen digital.
  - Mendukung pengelompokan dokumen berdasarkan kategori.
  - Menyimpan lokasi file pada Supabase Storage.
*/


/* =========================================================
   1. ENUM KATEGORI DOKUMEN
   ========================================================= */

do $$
begin
  if not exists (
    select 1
    from pg_type
    where typname = 'school_document_category'
      and typnamespace = 'public'::regnamespace
  ) then

    create type public.school_document_category as enum (
      'profil_sekolah',
      'kurikulum',
      'kesiswaan',
      'akademik',
      'gtk',
      'sarpras',
      'keuangan',
      'persuratan',
      'legalitas',
      'akreditasi',
      'laporan',
      'lainnya'
    );

  end if;
end
$$;


/* =========================================================
   2. ENUM STATUS DOKUMEN
   ========================================================= */

do $$
begin
  if not exists (
    select 1
    from pg_type
    where typname = 'school_document_status'
      and typnamespace = 'public'::regnamespace
  ) then

    create type public.school_document_status as enum (
      'draft',
      'aktif',
      'kedaluwarsa',
      'diarsipkan'
    );

  end if;
end
$$;


/* =========================================================
   3. TABLE SCHOOL DOCUMENTS
   ========================================================= */

create table if not exists public.school_documents (
  id uuid primary key default gen_random_uuid(),

  document_code text,

  document_number text,

  title text not null,

  category public.school_document_category not null
    default 'lainnya',

  description text,

  document_date date,

  effective_date date,

  expiry_date date,

  issuing_institution text,

  responsible_person text,

  status public.school_document_status not null
    default 'aktif',

  file_name text,

  document_url text,

  file_size bigint,

  mime_type text,

  version_number integer not null
    default 1,

  notes text,

  created_by uuid
    references public.users(id)
    on delete set null,

  created_at timestamptz not null
    default now(),

  updated_at timestamptz not null
    default now(),

  constraint school_document_title_check
    check (
      length(trim(title)) > 0
    ),

  constraint school_document_version_check
    check (
      version_number > 0
    ),

  constraint school_document_file_size_check
    check (
      file_size is null
      or file_size >= 0
    ),

  constraint school_document_date_range_check
    check (
      expiry_date is null
      or effective_date is null
      or expiry_date >= effective_date
    )
);


/* =========================================================
   4. UNIQUE DOCUMENT CODE
   ========================================================= */

create unique index if not exists
  uq_school_documents_document_code
on public.school_documents(document_code)
where document_code is not null
  and length(trim(document_code)) > 0;


/* =========================================================
   5. INDEXES
   ========================================================= */

create index if not exists
  idx_school_documents_title
on public.school_documents(title);

create index if not exists
  idx_school_documents_category
on public.school_documents(category);

create index if not exists
  idx_school_documents_status
on public.school_documents(status);

create index if not exists
  idx_school_documents_document_date
on public.school_documents(document_date);

create index if not exists
  idx_school_documents_effective_date
on public.school_documents(effective_date);

create index if not exists
  idx_school_documents_expiry_date
on public.school_documents(expiry_date);

create index if not exists
  idx_school_documents_created_by
on public.school_documents(created_by);


/* =========================================================
   6. UPDATED_AT TRIGGER
   ========================================================= */

drop trigger if exists
  school_documents_set_updated_at
on public.school_documents;

create trigger school_documents_set_updated_at
before update
on public.school_documents
for each row
execute function public.set_updated_at();


/* =========================================================
   7. ROW LEVEL SECURITY
   ========================================================= */

alter table public.school_documents
enable row level security;


/* =========================================================
   8. SELECT POLICY
   ========================================================= */

drop policy if exists
  school_documents_select
on public.school_documents;

create policy school_documents_select
on public.school_documents
for select
to authenticated
using (
  public.has_permission('persuratan', 'view')
);


/* =========================================================
   9. INSERT POLICY
   ========================================================= */

drop policy if exists
  school_documents_insert
on public.school_documents;

create policy school_documents_insert
on public.school_documents
for insert
to authenticated
with check (
  public.has_permission('persuratan', 'create')
);


/* =========================================================
   10. UPDATE POLICY
   ========================================================= */

drop policy if exists
  school_documents_update
on public.school_documents;

create policy school_documents_update
on public.school_documents
for update
to authenticated
using (
  public.has_permission('persuratan', 'update')
)
with check (
  public.has_permission('persuratan', 'update')
);


/* =========================================================
   11. DELETE POLICY
   ========================================================= */

drop policy if exists
  school_documents_delete
on public.school_documents;

create policy school_documents_delete
on public.school_documents
for delete
to authenticated
using (
  public.has_permission('persuratan', 'delete')
);


/* =========================================================
   12. GRANTS
   ========================================================= */

grant select, insert, update, delete
on public.school_documents
to authenticated;


/* =========================================================
   13. COMMENTS
   ========================================================= */

comment on table public.school_documents is
  'Metadata dokumen digital sekolah.';

comment on column public.school_documents.document_code is
  'Kode internal dokumen sekolah.';

comment on column public.school_documents.document_number is
  'Nomor resmi dokumen jika tersedia.';

comment on column public.school_documents.title is
  'Judul dokumen.';

comment on column public.school_documents.category is
  'Kategori dokumen sekolah.';

comment on column public.school_documents.document_date is
  'Tanggal dokumen diterbitkan atau dibuat.';

comment on column public.school_documents.effective_date is
  'Tanggal mulai berlaku dokumen.';

comment on column public.school_documents.expiry_date is
  'Tanggal berakhir dokumen jika ada.';

comment on column public.school_documents.issuing_institution is
  'Instansi penerbit dokumen.';

comment on column public.school_documents.responsible_person is
  'Penanggung jawab dokumen.';

comment on column public.school_documents.file_name is
  'Nama file dokumen.';

comment on column public.school_documents.document_url is
  'Lokasi file pada Supabase Storage atau digital archive.';

comment on column public.school_documents.file_size is
  'Ukuran file dalam byte.';

comment on column public.school_documents.mime_type is
  'MIME type file.';

comment on column public.school_documents.version_number is
  'Nomor versi dokumen.';


/* =========================================================
   MIGRATION SELESAI
   ========================================================= */