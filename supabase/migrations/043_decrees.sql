/*
  Migration 043
  Decrees / Surat Keputusan (SK)

  Sumber acuan:
  - PRD v4.0
  - Master Technical Blueprint v1.0
  - Database Blueprint v1.0

  Fungsi:
  - Menyimpan data Surat Keputusan sekolah.
  - Menyimpan nomor, tanggal, jenis SK,
    tentang/perihal, pejabat penandatangan,
    serta dokumen SK.
*/


/* =========================================================
   1. ENUM JENIS SK
   ========================================================= */

do $$
begin
  if not exists (
    select 1
    from pg_type
    where typname = 'decree_type'
      and typnamespace = 'public'::regnamespace
  ) then

    create type public.decree_type as enum (
      'pengangkatan',
      'pembagian_tugas',
      'wali_kelas',
      'kepanitiaan',
      'kelulusan',
      'kenaikan_kelas',
      'mutasi',
      'kepegawaian',
      'kurikulum',
      'sarpras',
      'keuangan',
      'lainnya'
    );

  end if;
end
$$;


/* =========================================================
   2. ENUM STATUS SK
   ========================================================= */

do $$
begin
  if not exists (
    select 1
    from pg_type
    where typname = 'decree_status'
      and typnamespace = 'public'::regnamespace
  ) then

    create type public.decree_status as enum (
      'draft',
      'berlaku',
      'selesai',
      'dibatalkan',
      'diarsipkan'
    );

  end if;
end
$$;


/* =========================================================
   3. TABLE DECREES
   ========================================================= */

create table if not exists public.decrees (
  id uuid primary key default gen_random_uuid(),

  decree_number text not null,

  decree_date date not null,

  decree_type public.decree_type not null
    default 'lainnya',

  title text not null,

  legal_basis text,

  effective_date date,

  end_date date,

  signer_name text,

  signer_position text,

  signer_nip text,

  recipient_scope text,

  description text,

  document_url text,

  status public.decree_status not null
    default 'draft',

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

  constraint decree_number_check
    check (
      length(trim(decree_number)) > 0
    ),

  constraint decree_title_check
    check (
      length(trim(title)) > 0
    ),

  constraint decree_date_range_check
    check (
      end_date is null
      or effective_date is null
      or end_date >= effective_date
    ),

  constraint decree_approval_check
    check (
      status not in (
        'berlaku',
        'selesai',
        'diarsipkan'
      )
      or approved_at is not null
    )
);


/* =========================================================
   4. UNIQUE DECREE NUMBER
   ========================================================= */

create unique index if not exists
  uq_decrees_decree_number
on public.decrees(decree_number);


/* =========================================================
   5. INDEXES
   ========================================================= */

create index if not exists
  idx_decrees_decree_date
on public.decrees(decree_date);

create index if not exists
  idx_decrees_decree_type
on public.decrees(decree_type);

create index if not exists
  idx_decrees_status
on public.decrees(status);

create index if not exists
  idx_decrees_effective_date
on public.decrees(effective_date);

create index if not exists
  idx_decrees_created_by
on public.decrees(created_by);

create index if not exists
  idx_decrees_approved_by
on public.decrees(approved_by);


/* =========================================================
   6. UPDATED_AT TRIGGER
   ========================================================= */

drop trigger if exists
  decrees_set_updated_at
on public.decrees;

create trigger decrees_set_updated_at
before update
on public.decrees
for each row
execute function public.set_updated_at();


/* =========================================================
   7. ROW LEVEL SECURITY
   ========================================================= */

alter table public.decrees
enable row level security;


/* =========================================================
   8. SELECT POLICY
   ========================================================= */

drop policy if exists
  decrees_select
on public.decrees;

create policy decrees_select
on public.decrees
for select
to authenticated
using (
  public.has_permission('persuratan', 'view')
);


/* =========================================================
   9. INSERT POLICY
   ========================================================= */

drop policy if exists
  decrees_insert
on public.decrees;

create policy decrees_insert
on public.decrees
for insert
to authenticated
with check (
  public.has_permission('persuratan', 'create')
);


/* =========================================================
   10. UPDATE POLICY
   ========================================================= */

drop policy if exists
  decrees_update
on public.decrees;

create policy decrees_update
on public.decrees
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
  decrees_delete
on public.decrees;

create policy decrees_delete
on public.decrees
for delete
to authenticated
using (
  public.has_permission('persuratan', 'delete')
);


/* =========================================================
   12. GRANTS
   ========================================================= */

grant select, insert, update, delete
on public.decrees
to authenticated;


/* =========================================================
   13. COMMENTS
   ========================================================= */

comment on table public.decrees is
  'Administrasi Surat Keputusan (SK) sekolah.';

comment on column public.decrees.decree_number is
  'Nomor resmi Surat Keputusan.';

comment on column public.decrees.decree_date is
  'Tanggal Surat Keputusan diterbitkan.';

comment on column public.decrees.decree_type is
  'Jenis Surat Keputusan.';

comment on column public.decrees.title is
  'Judul atau tentang Surat Keputusan.';

comment on column public.decrees.legal_basis is
  'Dasar hukum atau dasar penerbitan Surat Keputusan.';

comment on column public.decrees.effective_date is
  'Tanggal mulai berlakunya Surat Keputusan.';

comment on column public.decrees.end_date is
  'Tanggal berakhirnya masa berlaku jika ada.';

comment on column public.decrees.signer_name is
  'Nama pejabat penandatangan Surat Keputusan.';

comment on column public.decrees.signer_position is
  'Jabatan pejabat penandatangan.';

comment on column public.decrees.signer_nip is
  'NIP pejabat penandatangan jika tersedia.';

comment on column public.decrees.recipient_scope is
  'Pihak atau kelompok yang menjadi sasaran Surat Keputusan.';

comment on column public.decrees.document_url is
  'Lokasi file Surat Keputusan pada storage/digital archive.';

comment on column public.decrees.approved_by is
  'User yang memberikan persetujuan Surat Keputusan.';

comment on column public.decrees.approved_at is
  'Waktu persetujuan Surat Keputusan.';


/* =========================================================
   MIGRATION SELESAI
   ========================================================= */