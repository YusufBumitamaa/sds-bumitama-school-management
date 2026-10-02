/*
  Migration 050
  Budget Items / Detail Anggaran

  Sumber acuan:
  - PRD v4.0
  - Master Technical Blueprint v1.0
  - Database Blueprint v1.0

  Fungsi:
  - Menyimpan rincian setiap anggaran.
  - Menghubungkan anggaran dengan kategori keuangan.
  - Menyimpan volume, satuan, harga satuan,
    dan total anggaran setiap item.
*/


/* =========================================================
   1. TABLE BUDGET ITEMS
   ========================================================= */

create table if not exists public.budget_items (
  id uuid primary key default gen_random_uuid(),

  budget_id uuid not null
    references public.budgets(id)
    on delete cascade,

  category_id uuid not null
    references public.financial_categories(id)
    on delete restrict,

  item_code text,

  item_name text not null,

  description text,

  quantity numeric(18,3) not null
    default 1,

  unit text not null
    default 'unit',

  unit_price numeric(18,2) not null
    default 0,

  total_amount numeric(18,2) not null
    default 0,

  priority integer,

  notes text,

  created_at timestamptz not null
    default now(),

  updated_at timestamptz not null
    default now(),

  constraint budget_item_name_check
    check (
      length(trim(item_name)) > 0
    ),

  constraint budget_item_unit_check
    check (
      length(trim(unit)) > 0
    ),

  constraint budget_item_quantity_check
    check (
      quantity > 0
    ),

  constraint budget_item_unit_price_check
    check (
      unit_price >= 0
    ),

  constraint budget_item_total_amount_check
    check (
      total_amount >= 0
    ),

  constraint budget_item_priority_check
    check (
      priority is null
      or priority > 0
    )
);


/* =========================================================
   2. INDEXES
   ========================================================= */

create index if not exists
  idx_budget_items_budget
on public.budget_items(budget_id);

create index if not exists
  idx_budget_items_category
on public.budget_items(category_id);

create index if not exists
  idx_budget_items_name
on public.budget_items(item_name);

create index if not exists
  idx_budget_items_priority
on public.budget_items(priority);


/* =========================================================
   3. UPDATED_AT TRIGGER
   ========================================================= */

drop trigger if exists
  budget_items_set_updated_at
on public.budget_items;

create trigger budget_items_set_updated_at
before update
on public.budget_items
for each row
execute function public.set_updated_at();


/* =========================================================
   4. FUNCTION CALCULATE TOTAL ITEM
   ========================================================= */

create or replace function public.calculate_budget_item_total()
returns trigger
language plpgsql
set search_path = public, pg_temp
as $$
begin
  new.total_amount :=
    round(new.quantity * new.unit_price, 2);

  return new;
end;
$$;


/* =========================================================
   5. TRIGGER CALCULATE TOTAL ITEM
   ========================================================= */

drop trigger if exists
  budget_items_calculate_total
on public.budget_items;

create trigger budget_items_calculate_total
before insert or update of quantity, unit_price
on public.budget_items
for each row
execute function public.calculate_budget_item_total();


/* =========================================================
   6. FUNCTION UPDATE TOTAL BUDGET
   ========================================================= */

create or replace function public.update_budget_total_amount()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  target_budget_id uuid;
begin

  if tg_op = 'DELETE' then
    target_budget_id := old.budget_id;
  else
    target_budget_id := new.budget_id;
  end if;

  update public.budgets
  set
    total_amount = coalesce(
      (
        select sum(bi.total_amount)
        from public.budget_items bi
        where bi.budget_id = target_budget_id
      ),
      0
    ),
    updated_at = now()
  where id = target_budget_id;

  if tg_op = 'UPDATE'
     and old.budget_id is distinct from new.budget_id then

    update public.budgets
    set
      total_amount = coalesce(
        (
          select sum(bi.total_amount)
          from public.budget_items bi
          where bi.budget_id = old.budget_id
        ),
        0
      ),
      updated_at = now()
    where id = old.budget_id;

  end if;

  return coalesce(new, old);

end;
$$;


/* =========================================================
   7. TRIGGER UPDATE TOTAL BUDGET
   ========================================================= */

drop trigger if exists
  budget_items_update_budget_total
on public.budget_items;

create trigger budget_items_update_budget_total
after insert or update or delete
on public.budget_items
for each row
execute function public.update_budget_total_amount();


/* =========================================================
   8. ROW LEVEL SECURITY
   ========================================================= */

alter table public.budget_items
enable row level security;


/* =========================================================
   9. SELECT POLICY
   ========================================================= */

drop policy if exists
  budget_items_select
on public.budget_items;

create policy budget_items_select
on public.budget_items
for select
to authenticated
using (
  public.has_permission('keuangan', 'view')
);


/* =========================================================
   10. INSERT POLICY
   ========================================================= */

drop policy if exists
  budget_items_insert
on public.budget_items;

create policy budget_items_insert
on public.budget_items
for insert
to authenticated
with check (
  public.has_permission('keuangan', 'create')
);


/* =========================================================
   11. UPDATE POLICY
   ========================================================= */

drop policy if exists
  budget_items_update
on public.budget_items;

create policy budget_items_update
on public.budget_items
for update
to authenticated
using (
  public.has_permission('keuangan', 'update')
)
with check (
  public.has_permission('keuangan', 'update')
);


/* =========================================================
   12. DELETE POLICY
   ========================================================= */

drop policy if exists
  budget_items_delete
on public.budget_items;

create policy budget_items_delete
on public.budget_items
for delete
to authenticated
using (
  public.has_permission('keuangan', 'delete')
);


/* =========================================================
   13. GRANTS
   ========================================================= */

grant select, insert, update, delete
on public.budget_items
to authenticated;


/* =========================================================
   14. FUNCTION SECURITY
   ========================================================= */

revoke execute
on function public.calculate_budget_item_total()
from public;

revoke execute
on function public.calculate_budget_item_total()
from anon;

revoke execute
on function public.calculate_budget_item_total()
from authenticated;

revoke execute
on function public.update_budget_total_amount()
from public;

revoke execute
on function public.update_budget_total_amount()
from anon;

revoke execute
on function public.update_budget_total_amount()
from authenticated;


/* =========================================================
   15. COMMENTS
   ========================================================= */

comment on table public.budget_items is
  'Rincian item dalam suatu anggaran keuangan sekolah.';

comment on column public.budget_items.budget_id is
  'Anggaran induk yang memiliki item ini.';

comment on column public.budget_items.category_id is
  'Kategori keuangan untuk item anggaran.';

comment on column public.budget_items.item_code is
  'Kode item anggaran jika digunakan.';

comment on column public.budget_items.item_name is
  'Nama item atau kegiatan yang dianggarkan.';

comment on column public.budget_items.quantity is
  'Jumlah atau volume item.';

comment on column public.budget_items.unit is
  'Satuan item anggaran.';

comment on column public.budget_items.unit_price is
  'Harga satuan item.';

comment on column public.budget_items.total_amount is
  'Total nilai item, dihitung otomatis dari quantity dikali unit_price.';

comment on column public.budget_items.priority is
  'Urutan prioritas item anggaran.';


/* =========================================================
   MIGRATION SELESAI
   ========================================================= */