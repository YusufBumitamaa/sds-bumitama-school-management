/*
  Migration 005
  Penyesuaian Permission Persetujuan Keuangan

  Aturan bisnis:
  - Bendahara dapat membuat, mengubah, menghapus,
    melihat, export, print, dan upload transaksi.
  - Bendahara TIDAK memiliki hak approve.
  - Kepala Sekolah memiliki hak approve.
  - Super Admin tetap memiliki seluruh permission.

  Migration ini hanya menghapus relasi:
  Bendahara + Keuangan + approve

  Permission master "approve" pada tabel permissions
  tetap dipertahankan karena digunakan oleh role lain.
*/

delete from public.role_permissions
where role_id = (
  select id
  from public.roles
  where code = 'bendahara'
  limit 1
)
and permission_id = (
  select id
  from public.permissions
  where module = 'keuangan'
    and action = 'approve'
  limit 1
);