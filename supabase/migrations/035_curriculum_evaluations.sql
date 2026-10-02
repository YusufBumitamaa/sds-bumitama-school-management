/*
  Migration 035
  Curriculum Evaluations / Evaluasi Kurikulum

  Sumber acuan:
  - PRD v4.0
  - Master Technical Blueprint v1.0
  - Database Blueprint v1.0

  Fungsi:
  - Menyimpan evaluasi penerapan kurikulum.
  - Menghubungkan evaluasi dengan tahun ajaran.
  - Menyimpan aspek, hasil evaluasi, rekomendasi,
    dan tindak lanjut.
*/


/* =========================================================
   1. ENUM STATUS EVALUASI
   ========================================================= */

do $$
begin
  if not exists (
    select 1
    from pg_type
    where typname = 'curriculum_evaluation_status'
      and typnamespace = 'public'::regnamespace
  ) then

    create type public.curriculum_evaluation_status as enum (
      'draft',
      'proses',
      'selesai',
      'ditindaklanjuti',
      'dibatalkan'
    );

  end if;
end
$$;


/* =========================================================
   2. TABLE CURRICULUM EVALUATIONS
   ========================================================= */

create table if not exists public.curriculum_evaluations (
  id uuid primary key default gen_random_uuid(),

  academic_year_id uuid not null
    references public.academic_years(id)
    on delete restrict,

  evaluation_date date not null,

  title text not null,

  evaluation_aspect text not null,

  evaluator text,

  findings text,

  strengths text,

  weaknesses text,

  recommendations text,

  follow_up_plan text,

  follow_up_date date,

  status public.curriculum_evaluation_status not null
    default 'draft',

  document_url text,

  notes text,

  created_by uuid
    references public.users(id)
    on delete set null,

  created_at timestamptz not null
    default now(),

  updated_at timestamptz not null
    default now(),

  constraint curriculum_evaluation_title_check
    check (
      length(trim(title)) > 0
    ),

  constraint curriculum_evaluation_aspect_check
    check (
      length(trim(evaluation_aspect)) > 0
    ),

  constraint curriculum_evaluation_follow_up_date_check
    check (
      follow_up_date is null
      or follow_up_date >= evaluation_date
    )
);


/* =========================================================
   3. INDEXES
   ========================================================= */

create index if not exists
  idx_curriculum_evaluations_academic_year
on public.curriculum_evaluations(academic_year_id);

create index if not exists
  idx_curriculum_evaluations_date
on public.curriculum_evaluations(evaluation_date);

create index if not exists
  idx_curriculum_evaluations_status
on public.curriculum_evaluations(status);

create index if not exists
  idx_curriculum_evaluations_created_by
on public.curriculum_evaluations(created_by);


/* =========================================================
   4. UPDATED_AT TRIGGER
   ========================================================= */

drop trigger if exists
  curriculum_evaluations_set_updated_at
on public.curriculum_evaluations;

create trigger curriculum_evaluations_set_updated_at
before update
on public.curriculum_evaluations
for each row
execute function public.set_updated_at();


/* =========================================================
   5. ROW LEVEL SECURITY
   ========================================================= */

alter table public.curriculum_evaluations
enable row level security;


/* =========================================================
   6. SELECT POLICY
   ========================================================= */

drop policy if exists
  curriculum_evaluations_select
on public.curriculum_evaluations;

create policy curriculum_evaluations_select
on public.curriculum_evaluations
for select
to authenticated
using (
  public.has_permission('kurikulum', 'view')
);


/* =========================================================
   7. INSERT POLICY
   ========================================================= */

drop policy if exists
  curriculum_evaluations_insert
on public.curriculum_evaluations;

create policy curriculum_evaluations_insert
on public.curriculum_evaluations
for insert
to authenticated
with check (
  public.has_permission('kurikulum', 'create')
);


/* =========================================================
   8. UPDATE POLICY
   ========================================================= */

drop policy if exists
  curriculum_evaluations_update
on public.curriculum_evaluations;

create policy curriculum_evaluations_update
on public.curriculum_evaluations
for update
to authenticated
using (
  public.has_permission('kurikulum', 'update')
)
with check (
  public.has_permission('kurikulum', 'update')
);


/* =========================================================
   9. DELETE POLICY
   ========================================================= */

drop policy if exists
  curriculum_evaluations_delete
on public.curriculum_evaluations;

create policy curriculum_evaluations_delete
on public.curriculum_evaluations
for delete
to authenticated
using (
  public.has_permission('kurikulum', 'delete')
);


/* =========================================================
   10. GRANTS
   ========================================================= */

grant select, insert, update, delete
on public.curriculum_evaluations
to authenticated;


/* =========================================================
   11. COMMENTS
   ========================================================= */

comment on table public.curriculum_evaluations is
  'Evaluasi penerapan kurikulum dan tindak lanjutnya.';

comment on column public.curriculum_evaluations.academic_year_id is
  'Tahun ajaran yang menjadi konteks evaluasi.';

comment on column public.curriculum_evaluations.evaluation_date is
  'Tanggal pelaksanaan evaluasi.';

comment on column public.curriculum_evaluations.evaluation_aspect is
  'Aspek kurikulum yang dievaluasi.';

comment on column public.curriculum_evaluations.evaluator is
  'Nama atau pihak yang melakukan evaluasi.';

comment on column public.curriculum_evaluations.findings is
  'Temuan hasil evaluasi.';

comment on column public.curriculum_evaluations.strengths is
  'Kekuatan atau hal yang sudah berjalan dengan baik.';

comment on column public.curriculum_evaluations.weaknesses is
  'Kelemahan atau hal yang perlu diperbaiki.';

comment on column public.curriculum_evaluations.recommendations is
  'Rekomendasi hasil evaluasi.';

comment on column public.curriculum_evaluations.follow_up_plan is
  'Rencana tindak lanjut hasil evaluasi.';

comment on column public.curriculum_evaluations.document_url is
  'Lokasi dokumen hasil evaluasi pada storage/digital archive.';


/* =========================================================
   MIGRATION SELESAI
   ========================================================= */