/*
  Migration 006
  Mengembalikan Permission Approve untuk Bendahara

  Keputusan bisnis terbaru:
  Bendahara dapat melakukan approval
  transaksi keuangan untuk mempermudah
  operasional administrasi sekolah.

  Kepala Sekolah tetap memiliki permission approve.
  Super Admin tetap memiliki seluruh permission.

  Migration ini aman dijalankan lebih dari satu kali
  karena menggunakan ON CONFLICT DO NOTHING.
*/

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
  and p.module = 'keuangan'
  and p.action = 'approve'
on conflict (
  role_id,
  permission_id
) do nothing;