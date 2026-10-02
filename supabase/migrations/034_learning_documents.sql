/*
  Migration 034
  Learning Documents / Perangkat Pembelajaran

  Sumber acuan:
  - PRD v4.0
  - Master Technical Blueprint v1.0
  - Database Blueprint v1.0

  Fungsi:
  - Menyimpan perangkat pembelajaran guru.
  - Menghubungkan dokumen dengan tahun ajaran,
    mata pelajaran, kelas, dan GTK.
  - Mendukung penyimpanan dokumen digital melalui URL.
*/


/* =========================================================
   1. ENUM JENIS PERANGKAT PEMBELAJARAN
   ========================================================= */

do $$
begin
  if not exists (
    select 1
    from pg_type
    where typname = 'learning_document_type'
      and typnamespace = 'public'::regnamespace
  ) then

    create type public.learning_document_type as enum (
      'cp',
      'tp',
      'atp',
      'modul_ajar',
      'rpp',
      'bahan_ajar',
      'media_pembelajaran',
      'asesmen',
      'program_semester',
      'program_tahunan',
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
    where typname = 'learning_document_status'
      and typnamespace = 'public'::regnamespace
  ) then

    create type public.learning_document_status as enum (
      'draft',
      'diajukan',
      'disetujui',
      'dikembalikan',
      'arsip'
    );

  end if;
end
$$;


/* =========================================================
   3. TABLE LEARNING DOCUMENTS
   ========================================================= */

create table if not exists public.learning_documents (
  id uuid primary key default gen_random_uuid(),

  academic_year_id uuid not null
    references public.academic_years(id)
    on delete restrict,

  teacher_id uuid not null
    references public.teachers_staff(id)
    on delete restrict,

  subject_id uuid
    references public.subjects(id)
    on delete restrict,

  class_id uuid
    references public.classes(id)
    on delete restrict,

  document_type public.learning_document_type not null,

  title text not null,

  document_number text,

  document_date date,

  semester public.academic_semester,

  status public.learning_document_status not null
    default 'draft',

  document_url text,

  description text,

  notes text,

  created_by uuid
    references public.users(id)
    on delete set null,

  approved_by uuid
    references public.users(id)
    on delete set null,

  approved_at timestamptz,

  created_at timestamptz not null
    default now(),

  updated_at timestamptz not null
    default now(),

  constraint learning_document_title_check
    check (
      length(trim(title)) > 0
    ),

  constraint learning_document_approval_check
    check (
      status <> 'disetujui'
      or approved_at is not null
    )
);


/* =========================================================
   4. INDEXES
   ========================================================= */

create index if not exists
  idx_learning_documents_academic_year
on public.learning_documents(academic_year_id);

create index if not exists
  idx_learning_documents_teacher
on public.learning_documents(teacher_id);

create index if not exists
  idx_learning_documents_subject
on public.learning_documents(subject_id);

create index if not exists
  idx_learning_documents_class
on public.learning_documents(class_id);

create index if not exists
  idx_learning_documents_type
on public.learning_documents(document_type);

create index if not exists
  idx_learning_documents_status
on public.learning_documents(status);

create index if not exists
  idx_learning_documents_semester
on public.learning_documents(semester);


/* =========================================================
   5. UPDATED_AT TRIGGER
   ========================================================= */

drop trigger if exists
  learning_documents_set_updated_at
on public.learning_documents;

create trigger learning_documents_set_updated_at
before update
on public.learning_documents
for each row
execute function public.set_updated_at();


/* =========================================================
   6. ROW LEVEL SECURITY
   ========================================================= */

alter table public.learning_documents
enable row level security;


/* =========================================================
   7. SELECT POLICY
   ========================================================= */

drop policy if exists
  learning_documents_select
on public.learning_documents;

create policy learning_documents_select
on public.learning_documents
for select
to authenticated
using (
  public.has_permission('kurikulum', 'view')
);


/* =========================================================
   8. INSERT POLICY
   ========================================================= */

drop policy if exists
  learning_documents_insert
on public.learning_documents;

create policy learning_documents_insert
on public.learning_documents
for insert
to authenticated
with check (
  public.has_permission('kurikulum', 'create')
);


/* =========================================================
   9. UPDATE POLICY
   ========================================================= */

drop policy if exists
  learning_documents_update
on public.learning_documents;

create policy learning_documents_update
on public.learning_documents
for update
to authenticated
using (
  public.has_permission('kurikulum', 'update')
)
with check (
  public.has_permission('kurikulum', 'update')
);


/* =========================================================
   10. DELETE POLICY
   ========================================================= */

drop policy if exists
  learning_documents_delete
on public.learning_documents;

create policy learning_documents_delete
on public.learning_documents
for delete
to authenticated
using (
  public.has_permission('kurikulum', 'delete')
);


/* =========================================================
   11. GRANTS
   ========================================================= */

grant select, insert, update, delete
on public.learning_documents
to authenticated;


/* =========================================================
   12. COMMENTS
   ========================================================= */

comment on table public.learning_documents is
  'Perangkat pembelajaran dan dokumen pembelajaran Guru.';

comment on column public.learning_documents.academic_year_id is
  'Tahun ajaran perangkat pembelajaran.';

comment on column public.learning_documents.teacher_id is
  'Guru pemilik atau penyusun perangkat pembelajaran.';

comment on column public.learning_documents.subject_id is
  'Mata pelajaran yang terkait dengan dokumen.';

comment on column public.learning_documents.class_id is
  'Rombongan belajar yang terkait dengan dokumen.';

comment on column public.learning_documents.document_type is
  'Jenis perangkat pembelajaran.';

comment on column public.learning_documents.document_url is
  'Lokasi file perangkat pembelajaran pada storage/digital archive.';

comment on column public.learning_documents.approved_by is
  'User yang memberikan persetujuan dokumen.';

comment on column public.learning_documents.approved_at is
  'Waktu persetujuan dokumen.';


/* =========================================================
   MIGRATION SELESAI
   ========================================================= */