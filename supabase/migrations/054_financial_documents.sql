/*
  Migration 054
  Financial Documents / Dokumen Keuangan

  Sumber acuan:
  - PRD v4.0
  - Master Technical Blueprint v1.0
  - Database Blueprint v1.0

  Fungsi:
  - Menyimpan metadata bukti transaksi keuangan.
  - Menghubungkan dokumen dengan transaksi pemasukan,
    pengeluaran, kas, anggaran, atau sumber keuangan lainnya.
  - Menyediakan struktur untuk penyimpanan file melalui
    Supabase Storage pada tahap aplikasi.
  - Menyimpan versi, ukuran, MIME type, dan checksum file.

  Catatan:
  - File fisik tidak disimpan langsung di PostgreSQL.
  - Kolom file_path/file_url digunakan sebagai referensi
    ke Supabase Storage.
  - Dokumen keuangan termasuk data terbatas dan tetap
    menggunakan RLS modul keuangan.
*/


/* =========================================================
   1. ENUM KATEGORI DOKUMEN
   ========================================================= */

do $$
begin
  if not exists (
    select 1
    from pg_type
    where typname = 'financial_document_type'
      and typnamespace = 'public'::regnamespace
  ) then
    create type public.financial_document_type as enum (
      'bukti_pemasukan',
      'bukti_pengeluaran',
      'kwitansi',
      'nota',
      'invoice',
      'faktur',
      'rekening_koran',
      'bukti_transfer',
      'dokumen_anggaran',
      'laporan_keuangan',
      'dokumen_pendukung',
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
    where typname = 'financial_document_status'
      and typnamespace = 'public'::regnamespace
  ) then
    create type public.financial_document_status as enum (
      'aktif',
      'diganti',
      'diarsipkan',
      'dihapus'
    );
  end if;
end
$$;


/* =========================================================
   3. TABLE FINANCIAL DOCUMENTS
   ========================================================= */

create table if not exists public.financial_documents (
  id uuid primary key default gen_random_uuid(),

  document_code text not null,

  document_type public.financial_document_type not null,

  document_title text not null,

  document_number text,

  document_date date,

  financial_account_id uuid
    references public.financial_accounts(id)
    on delete restrict,

  income_transaction_id uuid
    references public.income_transactions(id)
    on delete restrict,

  expense_transaction_id uuid
    references public.expense_transactions(id)
    on delete restrict,

  cash_transaction_id uuid
    references public.cash_transactions(id)
    on delete restrict,

  budget_id uuid
    references public.budgets(id)
    on delete restrict,

  file_name text not null,

  file_path text not null,

  file_url text,

  file_size bigint,

  mime_type text,

  checksum text,

  version_number integer not null
    default 1,

  status public.financial_document_status not null
    default 'aktif',

  description text,

  notes text,

  uploaded_by uuid
    references public.users(id)
    on delete set null,

  uploaded_at timestamptz not null
    default now(),

  archived_at timestamptz,

  replaced_by uuid
    references public.financial_documents(id)
    on delete set null,

  created_at timestamptz not null
    default now(),

  updated_at timestamptz not null
    default now(),

  constraint financial_documents_code_check
    check (
      length(trim(document_code)) > 0
    ),

  constraint financial_documents_title_check
    check (
      length(trim(document_title)) > 0
    ),

  constraint financial_documents_file_name_check
    check (
      length(trim(file_name)) > 0
    ),

  constraint financial_documents_file_path_check
    check (
      length(trim(file_path)) > 0
    ),

  constraint financial_documents_file_size_check
    check (
      file_size is null
      or file_size >= 0
    ),

  constraint financial_documents_version_check
    check (
      version_number > 0
    ),

  constraint financial_documents_archived_check
    check (
      (
        status = 'diarsipkan'
        and archived_at is not null
      )
      or
      (
        status <> 'diarsipkan'
      )
    ),

  constraint financial_documents_replaced_check
    check (
      (
        status = 'diganti'
        and replaced_by is not null
      )
      or
      (
        status <> 'diganti'
      )
    )
);


/* =========================================================
   4. UNIQUE DOCUMENT CODE
   ========================================================= */

create unique index if not exists
  uq_financial_documents_document_code
on public.financial_documents(document_code);


/* =========================================================
   5. INDEXES
   ========================================================= */

create index if not exists
  idx_financial_documents_type
on public.financial_documents(document_type);

create index if not exists
  idx_financial_documents_status
on public.financial_documents(status);

create index if not exists
  idx_financial_documents_date
on public.financial_documents(document_date);

create index if not exists
  idx_financial_documents_account
on public.financial_documents(financial_account_id);

create index if not exists
  idx_financial_documents_income
on public.financial_documents(income_transaction_id);

create index if not exists
  idx_financial_documents_expense
on public.financial_documents(expense_transaction_id);

create index if not exists
  idx_financial_documents_cash
on public.financial_documents(cash_transaction_id);

create index if not exists
  idx_financial_documents_budget
on public.financial_documents(budget_id);

create index if not exists
  idx_financial_documents_uploaded_by
on public.financial_documents(uploaded_by);

create index if not exists
  idx_financial_documents_replaced_by
on public.financial_documents(replaced_by);


/* =========================================================
   6. VALIDATE DOCUMENT RELATION
   ========================================================= */

create or replace function public.validate_financial_document_relation()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  relation_count integer := 0;
begin

  /*
    Hitung jumlah relasi transaksi/anggaran
    yang diberikan.
  */

  if new.financial_account_id is not null then
    relation_count := relation_count + 1;
  end if;

  if new.income_transaction_id is not null then
    relation_count := relation_count + 1;
  end if;

  if new.expense_transaction_id is not null then
    relation_count := relation_count + 1;
  end if;

  if new.cash_transaction_id is not null then
    relation_count := relation_count + 1;
  end if;

  if new.budget_id is not null then
    relation_count := relation_count + 1;
  end if;


  /*
    Dokumen keuangan minimal harus memiliki
    satu hubungan dengan data keuangan.
  */

  if relation_count = 0 then
    raise exception
      'Dokumen keuangan harus terhubung dengan minimal satu data keuangan.';
  end if;


  /*
    Dokumen pemasukan harus terhubung
    dengan transaksi pemasukan jika
    tipe dokumennya bukti pemasukan.
  */

  if new.document_type = 'bukti_pemasukan'
     and new.income_transaction_id is null then

    raise exception
      'Dokumen bukti pemasukan harus memiliki transaksi pemasukan.';

  end if;


  /*
    Dokumen pengeluaran harus terhubung
    dengan transaksi pengeluaran.
  */

  if new.document_type = 'bukti_pengeluaran'
     and new.expense_transaction_id is null then

    raise exception
      'Dokumen bukti pengeluaran harus memiliki transaksi pengeluaran.';

  end if;


  return new;
end;
$$;


/* =========================================================
   7. TRIGGER VALIDATE RELATION
   ========================================================= */

drop trigger if exists
  financial_documents_validate_relation
on public.financial_documents;

create trigger financial_documents_validate_relation
before insert or update
on public.financial_documents
for each row
execute function public.validate_financial_document_relation();


/* =========================================================
   8. UPDATED_AT TRIGGER
   ========================================================= */

drop trigger if exists
  financial_documents_set_updated_at
on public.financial_documents;

create trigger financial_documents_set_updated_at
before update
on public.financial_documents
for each row
execute function public.set_updated_at();


/* =========================================================
   9. ARCHIVE VALIDATION
   ========================================================= */

create or replace function public.validate_financial_document_archive()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin

  if new.status = 'diarsipkan' then

    if new.archived_at is null then
      new.archived_at := now();
    end if;

  else

    new.archived_at := null;

  end if;

  return new;
end;
$$;


/* =========================================================
   10. TRIGGER ARCHIVE VALIDATION
   ========================================================= */

drop trigger if exists
  financial_documents_validate_archive
on public.financial_documents;

create trigger financial_documents_validate_archive
before insert or update of status, archived_at
on public.financial_documents
for each row
execute function public.validate_financial_document_archive();


/* =========================================================
   11. ROW LEVEL SECURITY
   ========================================================= */

alter table public.financial_documents
enable row level security;


/* =========================================================
   12. SELECT POLICY
   ========================================================= */

drop policy if exists
  financial_documents_select
on public.financial_documents;

create policy financial_documents_select
on public.financial_documents
for select
to authenticated
using (
  public.has_permission('keuangan', 'view')
);


/* =========================================================
   13. INSERT POLICY
   ========================================================= */

drop policy if exists
  financial_documents_insert
on public.financial_documents;

create policy financial_documents_insert
on public.financial_documents
for insert
to authenticated
with check (
  public.has_permission('keuangan', 'upload')
);


/* =========================================================
   14. UPDATE POLICY
   ========================================================= */

drop policy if exists
  financial_documents_update
on public.financial_documents;

create policy financial_documents_update
on public.financial_documents
for update
to authenticated
using (
  public.has_permission('keuangan', 'update')
  or
  public.has_permission('keuangan', 'upload')
)
with check (
  public.has_permission('keuangan', 'update')
  or
  public.has_permission('keuangan', 'upload')
);


/* =========================================================
   15. DELETE POLICY
   ========================================================= */

drop policy if exists
  financial_documents_delete
on public.financial_documents;

create policy financial_documents_delete
on public.financial_documents
for delete
to authenticated
using (
  public.has_permission('keuangan', 'delete')
  and status <> 'diarsipkan'
);


/* =========================================================
   16. GRANTS
   ========================================================= */

grant select, insert, update, delete
on public.financial_documents
to authenticated;


/* =========================================================
   17. FUNCTION SECURITY
   ========================================================= */

revoke execute
on function public.validate_financial_document_relation()
from public;

revoke execute
on function public.validate_financial_document_relation()
from anon;

revoke execute
on function public.validate_financial_document_relation()
from authenticated;


revoke execute
on function public.validate_financial_document_archive()
from public;

revoke execute
on function public.validate_financial_document_archive()
from anon;

revoke execute
on function public.validate_financial_document_archive()
from authenticated;


/* =========================================================
   18. COMMENTS
   ========================================================= */

comment on table public.financial_documents is
  'Metadata dokumen dan bukti transaksi keuangan sekolah. File fisik disimpan melalui Supabase Storage.';

comment on column public.financial_documents.document_code is
  'Kode unik dokumen keuangan.';

comment on column public.financial_documents.document_type is
  'Jenis dokumen keuangan.';

comment on column public.financial_documents.document_title is
  'Judul dokumen keuangan.';

comment on column public.financial_documents.document_number is
  'Nomor dokumen atau nomor bukti.';

comment on column public.financial_documents.financial_account_id is
  'Rekening keuangan yang terkait dengan dokumen.';

comment on column public.financial_documents.income_transaction_id is
  'Transaksi pemasukan yang terkait.';

comment on column public.financial_documents.expense_transaction_id is
  'Transaksi pengeluaran yang terkait.';

comment on column public.financial_documents.cash_transaction_id is
  'Transaksi kas yang terkait.';

comment on column public.financial_documents.budget_id is
  'Anggaran yang terkait.';

comment on column public.financial_documents.file_name is
  'Nama file dokumen.';

comment on column public.financial_documents.file_path is
  'Path file pada Supabase Storage.';

comment on column public.financial_documents.file_url is
  'URL file jika diperlukan oleh aplikasi.';

comment on column public.financial_documents.checksum is
  'Checksum file untuk membantu verifikasi integritas dokumen.';

comment on column public.financial_documents.version_number is
  'Nomor versi dokumen.';

comment on column public.financial_documents.status is
  'Status dokumen: aktif, diganti, diarsipkan, atau dihapus.';

comment on column public.financial_documents.replaced_by is
  'Dokumen versi baru yang menggantikan dokumen ini.';


/* =========================================================
   MIGRATION 054 SELESAI
   ========================================================= */