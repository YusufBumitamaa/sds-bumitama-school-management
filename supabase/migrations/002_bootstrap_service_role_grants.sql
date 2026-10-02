-- ============================================================
-- SDS BUMITAMA SCHOOL MANAGEMENT
-- Migration 002
-- Bootstrap Service Role Grants
-- ============================================================

-- Function bootstrap-super-admin menggunakan privileged backend
-- untuk membuat user pertama sebelum ada session authenticated.
--
-- Migration ini TIDAK mengubah RLS policy pada migration 001.
-- Migration ini hanya memberikan grant minimum yang diperlukan
-- kepada service_role untuk proses bootstrap dan rollback.

grant
  select,
  insert,
  delete
on table public.users
to service_role;

grant
  select
on table public.roles
to service_role;

grant
  select,
  insert,
  delete
on table public.user_roles
to service_role;