grant
  select,
  insert,
  update,
  delete
on table public.users
to service_role;

grant
  select,
  insert,
  update,
  delete
on table public.user_roles
to service_role;