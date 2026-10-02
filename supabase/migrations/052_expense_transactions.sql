/*
  Migration 052
  Expense Transactions / Transaksi Pengeluaran

  Sumber acuan:
  - PRD v4.0
  - Master Technical Blueprint v1.0
  - Database Blueprint v1.0

  Fungsi:
  - Mencatat seluruh transaksi pengeluaran sekolah.
  - Menghubungkan transaksi dengan rekening,
    kategori, sumber dana, dan anggaran.
  - Mendukung status transaksi keuangan.
  - Mendukung proses persetujuan.
  - Menjaga histori transaksi yang telah disetujui.

  Catatan:
  - Tidak digunakan untuk gaji/honor.
  - Tidak digunakan untuk pembayaran siswa.
  - Transaksi yang sudah disetujui tidak boleh
    dihapus secara permanen.
*/


/* =========================================================
   1. ENUM STATUS TRANSAKSI PENGELUARAN
   ========================================================= */

do $$
begin
  if not exists (
    select 1
    from pg_type
    where typname = 'expense_transaction_status'
      and typnamespace = 'public'::regnamespace
  ) then
    create type public.expense_transaction_status as enum (
      'draft',
      'menunggu_persetujuan',
      'disetujui',
      'ditolak',
      'dibatalkan'
    );
  end if;
end
$$;


/* =========================================================
   2. TABLE EXPENSE TRANSACTIONS
   ========================================================= */

create table if not exists public.expense_transactions (
  id uuid primary key default gen_random_uuid(),

  transaction_number text not null,

  transaction_date date not null
    default current_date,

  account_id uuid not null
    references public.financial_accounts(id)
    on delete restrict,

  category_id uuid not null
    references public.financial_categories(id)
    on delete restrict,

  funding_source_id uuid
    references public.funding_sources(id)
    on delete restrict,

  budget_id uuid
    references public.budgets(id)
    on delete restrict,

  budget_item_id uuid
    references public.budget_items(id)
    on delete restrict,

  description text not null,

  amount numeric(18,2) not null,

  recipient_name text,

  reference_number text,

  payment_method text,

  status public.expense_transaction_status not null
    default 'draft',

  document_url text,

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

  constraint expense_transactions_number_check
    check (
      length(trim(transaction_number)) > 0
    ),

  constraint expense_transactions_description_check
    check (
      length(trim(description)) > 0
    ),

  constraint expense_transactions_amount_check
    check (
      amount > 0
    ),

  constraint expense_transactions_approval_check
    check (
      (
        status = 'disetujui'
        and approved_at is not null
      )
      or
      (
        status <> 'disetujui'
      )
    )
);


/* =========================================================
   3. UNIQUE TRANSACTION NUMBER
   ========================================================= */

create unique index if not exists
  uq_expense_transactions_transaction_number
on public.expense_transactions(transaction_number);


/* =========================================================
   4. INDEXES
   ========================================================= */

create index if not exists
  idx_expense_transactions_date
on public.expense_transactions(transaction_date);

create index if not exists
  idx_expense_transactions_account
on public.expense_transactions(account_id);

create index if not exists
  idx_expense_transactions_category
on public.expense_transactions(category_id);

create index if not exists
  idx_expense_transactions_funding_source
on public.expense_transactions(funding_source_id);

create index if not exists
  idx_expense_transactions_budget
on public.expense_transactions(budget_id);

create index if not exists
  idx_expense_transactions_budget_item
on public.expense_transactions(budget_item_id);

create index if not exists
  idx_expense_transactions_status
on public.expense_transactions(status);

create index if not exists
  idx_expense_transactions_created_by
on public.expense_transactions(created_by);

create index if not exists
  idx_expense_transactions_approved_by
on public.expense_transactions(approved_by);


/* =========================================================
   5. VALIDATE EXPENSE CATEGORY
   ========================================================= */

create or replace function public.validate_expense_transaction_category()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  selected_category_type public.financial_category_type;
begin

  select category_type
  into selected_category_type
  from public.financial_categories
  where id = new.category_id;

  if selected_category_type is null then
    raise exception
      'Kategori keuangan tidak ditemukan.';
  end if;

  if selected_category_type not in (
    'pengeluaran',
    'umum'
  ) then
    raise exception
      'Kategori transaksi pengeluaran harus bertipe pengeluaran atau umum.';
  end if;

  return new;
end;
$$;


/* =========================================================
   6. TRIGGER VALIDASI KATEGORI
   ========================================================= */

drop trigger if exists
  expense_transactions_validate_category
on public.expense_transactions;

create trigger expense_transactions_validate_category
before insert or update of category_id
on public.expense_transactions
for each row
execute function public.validate_expense_transaction_category();


/* =========================================================
   7. VALIDATE BUDGET RELATION
   ========================================================= */

create or replace function public.validate_expense_transaction_budget()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  selected_budget_id uuid;
begin

  /*
    Jika budget_item_id diisi,
    maka budget_id wajib diisi.
  */

  if new.budget_item_id is not null
     and new.budget_id is null then

    raise exception
      'Budget harus diisi jika budget item digunakan.';

  end if;


  /*
    Jika budget item digunakan,
    pastikan item tersebut memang milik
    budget yang dipilih.
  */

  if new.budget_item_id is not null
     and new.budget_id is not null then

    select budget_id
    into selected_budget_id
    from public.budget_items
    where id = new.budget_item_id;

    if selected_budget_id is null then
      raise exception
        'Budget item tidak ditemukan.';
    end if;

    if selected_budget_id <> new.budget_id then
      raise exception
        'Budget item tidak sesuai dengan budget yang dipilih.';
    end if;

  end if;

  return new;
end;
$$;


/* =========================================================
   8. TRIGGER VALIDASI BUDGET
   ========================================================= */

drop trigger if exists
  expense_transactions_validate_budget
on public.expense_transactions;

create trigger expense_transactions_validate_budget
before insert or update of budget_id, budget_item_id
on public.expense_transactions
for each row
execute function public.validate_expense_transaction_budget();


/* =========================================================
   9. VALIDATE APPROVAL
   ========================================================= */

create or replace function public.validate_expense_transaction_approval()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin

  /*
    Jika transaksi disetujui,
    approved_by wajib tersedia.
  */

  if new.status = 'disetujui' then

    if new.approved_by is null then
      raise exception
        'Transaksi yang disetujui harus memiliki approved_by.';
    end if;

    if new.approved_at is null then
      new.approved_at := now();
    end if;

  else

    /*
      Status selain disetujui
      tidak boleh menyimpan informasi approval.
    */

    new.approved_by := null;
    new.approved_at := null;

  end if;

  return new;
end;
$$;


/* =========================================================
   10. TRIGGER VALIDASI APPROVAL
   ========================================================= */

drop trigger if exists
  expense_transactions_validate_approval
on public.expense_transactions;

create trigger expense_transactions_validate_approval
before insert or update of status, approved_by, approved_at
on public.expense_transactions
for each row
execute function public.validate_expense_transaction_approval();


/* =========================================================
   11. UPDATED_AT TRIGGER
   ========================================================= */

drop trigger if exists
  expense_transactions_set_updated_at
on public.expense_transactions;

create trigger expense_transactions_set_updated_at
before update
on public.expense_transactions
for each row
execute function public.set_updated_at();


/* =========================================================
   12. ROW LEVEL SECURITY
   ========================================================= */

alter table public.expense_transactions
enable row level security;


/* =========================================================
   13. SELECT POLICY
   ========================================================= */

drop policy if exists
  expense_transactions_select
on public.expense_transactions;

create policy expense_transactions_select
on public.expense_transactions
for select
to authenticated
using (
  public.has_permission('keuangan', 'view')
);


/* =========================================================
   14. INSERT POLICY
   ========================================================= */

drop policy if exists
  expense_transactions_insert
on public.expense_transactions;

create policy expense_transactions_insert
on public.expense_transactions
for insert
to authenticated
with check (
  public.has_permission('keuangan', 'create')
);


/* =========================================================
   15. UPDATE POLICY
   ========================================================= */

drop policy if exists
  expense_transactions_update
on public.expense_transactions;

create policy expense_transactions_update
on public.expense_transactions
for update
to authenticated
using (
  public.has_permission('keuangan', 'update')
  or
  public.has_permission('keuangan', 'approve')
)
with check (
  public.has_permission('keuangan', 'update')
  or
  public.has_permission('keuangan', 'approve')
);


/* =========================================================
   16. DELETE POLICY
   ========================================================= */

drop policy if exists
  expense_transactions_delete
on public.expense_transactions;

create policy expense_transactions_delete
on public.expense_transactions
for delete
to authenticated
using (
  public.has_permission('keuangan', 'delete')
  and status in (
    'draft',
    'ditolak',
    'dibatalkan'
  )
);


/* =========================================================
   17. GRANTS
   ========================================================= */

grant select, insert, update, delete
on public.expense_transactions
to authenticated;


/* =========================================================
   18. FUNCTION SECURITY
   ========================================================= */

revoke execute
on function public.validate_expense_transaction_category()
from public;

revoke execute
on function public.validate_expense_transaction_category()
from anon;

revoke execute
on function public.validate_expense_transaction_category()
from authenticated;


revoke execute
on function public.validate_expense_transaction_budget()
from public;

revoke execute
on function public.validate_expense_transaction_budget()
from anon;

revoke execute
on function public.validate_expense_transaction_budget()
from authenticated;


revoke execute
on function public.validate_expense_transaction_approval()
from public;

revoke execute
on function public.validate_expense_transaction_approval()
from anon;

revoke execute
on function public.validate_expense_transaction_approval()
from authenticated;


/* =========================================================
   19. COMMENTS
   ========================================================= */

comment on table public.expense_transactions is
  'Transaksi pengeluaran sekolah. Tidak digunakan untuk gaji/honor atau pembayaran siswa.';

comment on column public.expense_transactions.transaction_number is
  'Nomor unik transaksi pengeluaran.';

comment on column public.expense_transactions.transaction_date is
  'Tanggal transaksi pengeluaran.';

comment on column public.expense_transactions.account_id is
  'Rekening atau kas yang digunakan untuk pengeluaran.';

comment on column public.expense_transactions.category_id is
  'Kategori pengeluaran.';

comment on column public.expense_transactions.funding_source_id is
  'Sumber dana transaksi.';

comment on column public.expense_transactions.budget_id is
  'Anggaran yang terkait dengan transaksi.';

comment on column public.expense_transactions.budget_item_id is
  'Detail item anggaran yang terkait dengan transaksi.';

comment on column public.expense_transactions.description is
  'Uraian transaksi pengeluaran.';

comment on column public.expense_transactions.amount is
  'Nilai transaksi pengeluaran.';

comment on column public.expense_transactions.recipient_name is
  'Pihak penerima pembayaran.';

comment on column public.expense_transactions.reference_number is
  'Nomor referensi atau bukti transaksi.';

comment on column public.expense_transactions.payment_method is
  'Metode pembayaran transaksi.';

comment on column public.expense_transactions.status is
  'Status transaksi: draft, menunggu_persetujuan, disetujui, ditolak, dibatalkan.';

comment on column public.expense_transactions.approved_by is
  'User yang memberikan persetujuan transaksi.';

comment on column public.expense_transactions.approved_at is
  'Waktu transaksi disetujui.';


/* =========================================================
   MIGRATION 052 SELESAI
   ========================================================= */