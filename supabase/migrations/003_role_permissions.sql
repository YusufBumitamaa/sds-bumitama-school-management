-- ============================================================
-- SDS BUMITAMA SCHOOL MANAGEMENT
-- Migration 003
-- Role Permission Matrix
-- ============================================================
--
-- Tujuan:
-- Mengisi role_permissions berdasarkan RBAC yang telah
-- disepakati untuk:
--   - Admin / TU
--   - Kepala Sekolah
--   - Guru
--   - Bendahara
--
-- Super Admin TIDAK diubah di migration ini karena pada
-- migration 001 sudah mendapatkan seluruh permission.
--
-- Prinsip:
--   1. Hanya permission yang memang tersedia di tabel
--      permissions yang akan diberikan.
--   2. INSERT menggunakan ON CONFLICT DO NOTHING agar aman
--      apabila migration dijalankan ulang pada data yang
--      sudah ada.
--   3. Tidak menghapus permission yang mungkin sudah ada.
-- ============================================================


-- ============================================================
-- 1. ADMIN / TU
-- ============================================================
--
-- Admin/TU:
-- - Dashboard
-- - Profil Sekolah
-- - Kesiswaan
-- - Kurikulum
-- - Akademik
-- - GTK
-- - Sarpras
-- - Persuratan
-- - Laporan
-- - Pengaturan
--
-- Tidak diberikan:
-- - Pengguna & Hak Akses
-- - Audit Log
--
-- Keuangan hanya VIEW sesuai matrix yang disepakati.
-- ============================================================

insert into public.role_permissions (
  role_id,
  permission_id
)
select
  r.id,
  p.id
from public.roles r
cross join public.permissions p
where r.code = 'admin'
  and (
    p.module = 'dashboard'
    and p.action = 'view'

    or p.module = 'profil_sekolah'
    and p.action in (
      'view',
      'create',
      'update'
    )

    or p.module = 'kesiswaan'
    and p.action in (
      'view',
      'create',
      'update',
      'delete',
      'export',
      'print',
      'upload'
    )

    or p.module = 'kurikulum'
    and p.action in (
      'view',
      'create',
      'update',
      'delete',
      'export',
      'print',
      'upload'
    )

    or p.module = 'akademik'
    and p.action in (
      'view',
      'create',
      'update',
      'delete',
      'approve',
      'export',
      'print'
    )

    or p.module = 'gtk'
    and p.action in (
      'view',
      'create',
      'update',
      'delete',
      'export',
      'print',
      'upload'
    )

    or p.module = 'sarpras'
    and p.action in (
      'view',
      'create',
      'update',
      'delete',
      'export',
      'print',
      'upload'
    )

    or p.module = 'keuangan'
    and p.action = 'view'

    or p.module = 'persuratan'
    and p.action in (
      'view',
      'create',
      'update',
      'delete',
      'export',
      'print',
      'upload'
    )

    or p.module = 'laporan'
    and p.action in (
      'view',
      'export',
      'print'
    )

    or p.module = 'pengaturan'
    and p.action in (
      'view',
      'update'
    )

    or p.module = 'notifikasi'
    and p.action in (
      'view',
      'update'
    )
  )
on conflict (role_id, permission_id) do nothing;


-- ============================================================
-- 2. KEPALA SEKOLAH
-- ============================================================
--
-- Kepala Sekolah:
-- - Monitoring
-- - Approval pada modul yang memang memiliki permission
--   approve.
-- - Export dan Print untuk kebutuhan monitoring/laporan.
--
-- Catatan:
-- Modul Persuratan saat ini belum memiliki permission
-- action = 'approve' pada seed permission.
-- Karena itu hanya permission yang tersedia yang diberikan.
-- ============================================================

insert into public.role_permissions (
  role_id,
  permission_id
)
select
  r.id,
  p.id
from public.roles r
cross join public.permissions p
where r.code = 'kepala_sekolah'
  and (
    p.module = 'dashboard'
    and p.action = 'view'

    or p.module = 'profil_sekolah'
    and p.action = 'view'

    or p.module = 'kesiswaan'
    and p.action in (
      'view',
      'export',
      'print'
    )

    or p.module = 'kurikulum'
    and p.action in (
      'view',
      'export',
      'print'
    )

    or p.module = 'akademik'
    and p.action in (
      'view',
      'approve',
      'export',
      'print'
    )

    or p.module = 'gtk'
    and p.action in (
      'view',
      'export',
      'print'
    )

    or p.module = 'sarpras'
    and p.action in (
      'view',
      'approve',
      'export',
      'print'
    )

    or p.module = 'keuangan'
    and p.action in (
      'view',
      'approve',
      'export',
      'print'
    )

    or p.module = 'persuratan'
    and p.action in (
      'view',
      'export',
      'print'
    )

    or p.module = 'laporan'
    and p.action in (
      'view',
      'export',
      'print'
    )

    or p.module = 'pengaturan'
    and p.action = 'view'

    or p.module = 'notifikasi'
    and p.action in (
      'view',
      'update'
    )
  )
on conflict (role_id, permission_id) do nothing;


-- ============================================================
-- 3. GURU
-- ============================================================
--
-- Guru:
-- - Akses data yang berkaitan dengan pembelajaran dan
--   kegiatan akademik.
-- - Tidak diberikan akses ke Keuangan, Pengguna, Audit Log,
--   maupun administrasi sensitif lainnya.
-- ============================================================

insert into public.role_permissions (
  role_id,
  permission_id
)
select
  r.id,
  p.id
from public.roles r
cross join public.permissions p
where r.code = 'guru'
  and (
    p.module = 'dashboard'
    and p.action = 'view'

    or p.module = 'profil_sekolah'
    and p.action = 'view'

    or p.module = 'kesiswaan'
    and p.action in (
      'view',
      'create',
      'update',
      'export',
      'print'
    )

    or p.module = 'kurikulum'
    and p.action in (
      'view',
      'create',
      'update',
      'export',
      'print'
    )

    or p.module = 'akademik'
    and p.action in (
      'view',
      'create',
      'update',
      'export',
      'print'
    )

    or p.module = 'gtk'
    and p.action = 'view'

    or p.module = 'sarpras'
    and p.action = 'view'

    or p.module = 'persuratan'
    and p.action in (
      'view',
      'create',
      'update',
      'upload'
    )

    or p.module = 'laporan'
    and p.action in (
      'view',
      'export',
      'print'
    )

    or p.module = 'pengaturan'
    and p.action = 'view'

    or p.module = 'notifikasi'
    and p.action in (
      'view',
      'update'
    )
  )
on conflict (role_id, permission_id) do nothing;


-- ============================================================
-- 4. BENDAHARA
-- ============================================================
--
-- Bendahara:
-- - Fokus utama pada Keuangan.
-- - Memiliki seluruh permission yang tersedia pada modul
--   Keuangan.
-- - Dapat melihat data pendukung yang diperlukan.
-- - Tidak diberikan pengelolaan pengguna.
-- ============================================================

insert into public.role_permissions (
  role_id,
  permission_id
)
select
  r.id,
  p.id
from public.roles r
cross join public.permissions p
where r.code = 'bendahara'
  and (
    p.module = 'dashboard'
    and p.action = 'view'

    or p.module = 'profil_sekolah'
    and p.action = 'view'

    or p.module = 'kesiswaan'
    and p.action = 'view'

    or p.module = 'kurikulum'
    and p.action = 'view'

    or p.module = 'akademik'
    and p.action = 'view'

    or p.module = 'gtk'
    and p.action = 'view'

    or p.module = 'sarpras'
    and p.action = 'view'

    or p.module = 'keuangan'
    and p.action in (
      'view',
      'create',
      'update',
      'delete',
      'approve',
      'export',
      'print',
      'upload'
    )

    or p.module = 'persuratan'
    and p.action = 'view'

    or p.module = 'laporan'
    and p.action in (
      'view',
      'export',
      'print'
    )

    or p.module = 'pengaturan'
    and p.action = 'view'

    or p.module = 'notifikasi'
    and p.action in (
      'view',
      'update'
    )
  )
on conflict (role_id, permission_id) do nothing;


-- ============================================================
-- 5. VERIFIKASI RINGKAS
-- ============================================================
--
-- Query ini tidak mengubah data.
-- Digunakan untuk memastikan jumlah permission setiap role.
--
-- Dapat dijalankan terpisah di SQL Editor setelah migration.
-- ============================================================

-- select
--   r.code as role_code,
--   r.name as role_name,
--   count(rp.permission_id) as permission_count
-- from public.roles r
-- left join public.role_permissions rp
--   on rp.role_id = r.id
-- group by
--   r.id,
--   r.code,
--   r.name
-- order by
--   case r.code
--     when 'super_admin' then 1
--     when 'admin' then 2
--     when 'kepala_sekolah' then 3
--     when 'guru' then 4
--     when 'bendahara' then 5
--     else 99
--   end;