/*
  Migration 058
  Financial Documents Storage

  Acuan:
  - PRD v4.0
  - Master Technical Blueprint v1.0
  - Database Blueprint v1.0
  - Migration 054 - Financial Documents

  Tujuan:
  - Membuat private storage bucket untuk dokumen keuangan.
  - Membatasi akses file berdasarkan permission keuangan.
  - Menyediakan aturan upload, baca, update, dan delete.
  - File tidak dapat diakses secara public.
  - Metadata dokumen tetap disimpan di financial_documents.

  Struktur storage yang direkomendasikan:

    financial-documents/
      {account_id}/
        {year}/
          {document_code}/
            filename.ext

  Contoh:

    financial-documents/
      7c.../
        2026/
          DOC-2026-00001/
            bukti-transfer.pdf
*/


/* =========================================================
   1. CREATE PRIVATE STORAGE BUCKET
   ========================================================= */

insert into storage.buckets (
  id,
  name,
  public,
  file_size_limit,
  allowed_mime_types
)
values (
  'financial-documents',
  'financial-documents',
  false,
  10485760,
  array[
    'application/pdf',
    'image/jpeg',
    'image/png',
    'image/webp',
    'application/msword',
    'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    'application/vnd.ms-excel',
    'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'
  ]
)
on conflict (id)
do update set
  public = false,
  file_size_limit = 10485760,
  allowed_mime_types = array[
    'application/pdf',
    'image/jpeg',
    'image/png',
    'image/webp',
    'application/msword',
    'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    'application/vnd.ms-excel',
    'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'
  ];


/* =========================================================
   2. STORAGE SELECT POLICY
   ========================================================= */

drop policy if exists
  financial_documents_storage_select
on storage.objects;

create policy financial_documents_storage_select
on storage.objects
for select
to authenticated
using (
  bucket_id = 'financial-documents'
  and (
    public.has_permission(
      'keuangan',
      'view'
    )
    or public.has_permission(
      'keuangan',
      'upload'
    )
  )
);


/* =========================================================
   3. STORAGE INSERT POLICY
   ========================================================= */

drop policy if exists
  financial_documents_storage_insert
on storage.objects;

create policy financial_documents_storage_insert
on storage.objects
for insert
to authenticated
with check (
  bucket_id = 'financial-documents'
  and public.has_permission(
    'keuangan',
    'upload'
  )
);


/* =========================================================
   4. STORAGE UPDATE POLICY
   ========================================================= */

drop policy if exists
  financial_documents_storage_update
on storage.objects;

create policy financial_documents_storage_update
on storage.objects
for update
to authenticated
using (
  bucket_id = 'financial-documents'
  and (
    public.has_permission(
      'keuangan',
      'upload'
    )
    or public.has_permission(
      'keuangan',
      'update'
    )
  )
)
with check (
  bucket_id = 'financial-documents'
  and (
    public.has_permission(
      'keuangan',
      'upload'
    )
    or public.has_permission(
      'keuangan',
      'update'
    )
  )
);


/* =========================================================
   5. STORAGE DELETE POLICY
   ========================================================= */

drop policy if exists
  financial_documents_storage_delete
on storage.objects;

create policy financial_documents_storage_delete
on storage.objects
for delete
to authenticated
using (
  bucket_id = 'financial-documents'
  and public.has_permission(
    'keuangan',
    'delete'
  )
);


/* =========================================================
   6. STORAGE OBJECT PATH VALIDATION
   ========================================================= */

create or replace function public.validate_financial_storage_object()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin

  /*
    Pastikan object berada di bucket yang benar.
  */

  if new.bucket_id <> 'financial-documents' then
    return new;
  end if;


  /*
    Path tidak boleh kosong.
  */

  if new.name is null
     or trim(new.name) = '' then

    raise exception
      'Nama file dokumen keuangan tidak boleh kosong.';

  end if;


  /*
    Tolak path absolut atau pola traversal.
  */

  if new.name like '/%'
     or new.name like '%../%'
     or new.name like '%\..%' then

    raise exception
      'Path dokumen keuangan tidak valid.';

  end if;


  return new;

end;
$$;


/* =========================================================
   7. STORAGE OBJECT VALIDATION TRIGGER
   ========================================================= */

drop trigger if exists
  financial_storage_object_validation
on storage.objects;

create trigger financial_storage_object_validation
before insert or update
on storage.objects
for each row
execute function public.validate_financial_storage_object();


/* =========================================================
   8. FUNCTION SECURITY
   ========================================================= */

revoke execute
on function public.validate_financial_storage_object()
from public;

revoke execute
on function public.validate_financial_storage_object()
from anon;

revoke execute
on function public.validate_financial_storage_object()
from authenticated;


/* =========================================================
   9. COMMENTS
   ========================================================= */

comment on function public.validate_financial_storage_object() is
  'Memvalidasi path file pada private bucket financial-documents.';


/* =========================================================
   MIGRATION 058 SELESAI
   ========================================================= */