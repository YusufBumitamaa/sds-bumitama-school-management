import {
  useEffect,
  useMemo,
  useState,
} from 'react'

import type { FormEvent } from 'react'

import {
  Check,
  ChevronDown,
  KeyRound,
  Mail,
  Pencil,
  Plus,
  Search,
  ShieldCheck,
  User,
  Users,
  X,
  Power,
  AlertTriangle,
} from 'lucide-react'

import {
  activateUser,
  createUser,
  deactivateUser,
  updateUser,
} from '../../services/userService'

import type {
  CreateUserRole,
} from '../../services/userService'

import { supabase } from '../../lib/supabase'

interface UserRecord {
  id: string
  email: string
  full_name: string
  is_active: boolean
  created_at: string
  roles: {
    id: string
    code: CreateUserRole
    name: string
  }[]
}

interface RoleRecord {
  id: string
  code: CreateUserRole
  name: string
}

interface UserFormData {
  fullName: string
  email: string
  password: string
  confirmPassword: string
  role: CreateUserRole
}

interface StatusConfirmation {
  user: UserRecord
  nextStatus: boolean
}

const defaultForm: UserFormData = {
  fullName: '',
  email: '',
  password: '',
  confirmPassword: '',
  role: 'admin',
}

const roleLabels: Record<
  CreateUserRole,
  string
> = {
  super_admin: 'Super Admin',
  admin: 'Admin / TU',
  kepala_sekolah: 'Kepala Sekolah',
  guru: 'Guru',
  bendahara: 'Bendahara',
}

const roleBadgeClasses: Record<
  CreateUserRole,
  string
> = {
  super_admin:
    'bg-emerald-50 text-emerald-700 dark:bg-emerald-950/40 dark:text-emerald-300',
  admin:
    'bg-blue-50 text-blue-700 dark:bg-blue-950/40 dark:text-blue-300',
  kepala_sekolah:
    'bg-violet-50 text-violet-700 dark:bg-violet-950/40 dark:text-violet-300',
  guru:
    'bg-amber-50 text-amber-700 dark:bg-amber-950/40 dark:text-amber-300',
  bendahara:
    'bg-slate-100 text-slate-700 dark:bg-slate-800 dark:text-slate-300',
}

function formatDate(value: string) {
  return new Intl.DateTimeFormat(
    'id-ID',
    {
      day: '2-digit',
      month: 'short',
      year: 'numeric',
    },
  ).format(new Date(value))
}

function getPrimaryRole(
  user: UserRecord,
): RoleRecord | null {
  const role = user.roles?.[0]

  if (!role) {
    return null
  }

  return {
    id: role.id,
    code: role.code,
    name: role.name,
  }
}

function getInitials(fullName: string) {
  const words = fullName
    .trim()
    .split(/\s+/)
    .filter(Boolean)

  if (words.length === 0) {
    return 'U'
  }

  if (words.length === 1) {
    return words[0]
      .slice(0, 2)
      .toUpperCase()
  }

  return (
    words[0][0] +
    words[words.length - 1][0]
  ).toUpperCase()
}

export default function UsersPage() {
  const [users, setUsers] =
    useState<UserRecord[]>([])

  const [roles, setRoles] =
    useState<RoleRecord[]>([])

  const [isLoading, setIsLoading] =
    useState(true)

  const [isSubmitting, setIsSubmitting] =
    useState(false)

  const [
    processingStatusUserId,
    setProcessingStatusUserId,
  ] = useState<string | null>(null)

  const [error, setError] =
    useState('')

  const [success, setSuccess] =
    useState('')

  const [search, setSearch] =
    useState('')

  const [roleFilter, setRoleFilter] =
    useState('all')

  const [statusFilter, setStatusFilter] =
    useState<
      'all' | 'active' | 'inactive'
    >('all')

  const [isModalOpen, setIsModalOpen] =
    useState(false)

  const [editingUser, setEditingUser] =
    useState<UserRecord | null>(null)

  const [
    statusConfirmation,
    setStatusConfirmation,
  ] =
    useState<StatusConfirmation | null>(
      null,
    )

  const [form, setForm] =
    useState<UserFormData>(
      defaultForm,
    )

  const loadRoles = async () => {
    const {
      data,
      error: rolesError,
    } = await supabase
      .from('roles')
      .select('id, code, name')
      .order('name')

    if (rolesError) {
      throw rolesError
    }

    setRoles(
      (data ?? []) as RoleRecord[],
    )
  }

  const loadUsers = async () => {
    const {
      data,
      error: usersError,
    } = await supabase
      .from('users')
      .select(
        `
          id,
          email,
          full_name,
          is_active,
          created_at,
          user_roles (
            roles (
              id,
              code,
              name
            )
          )
        `,
      )
      .order('created_at', {
        ascending: false,
      })

    if (usersError) {
      throw usersError
    }

    const normalizedUsers =
      (data ?? []).map((user) => {
        const userRoles =
          Array.isArray(
            user.user_roles,
          )
            ? user.user_roles
            : []

        const normalizedRoles =
          userRoles
            .map((userRole) => {
              const role =
                Array.isArray(
                  userRole.roles,
                )
                  ? userRole.roles[0]
                  : userRole.roles

              if (!role) {
                return null
              }

              return {
                id: role.id,
                code:
                  role.code as CreateUserRole,
                name: role.name,
              }
            })
            .filter(
              (
                role,
              ): role is RoleRecord =>
                role !== null,
            )

        return {
          id: user.id,
          email: user.email,
          full_name:
            user.full_name,
          is_active:
            user.is_active,
          created_at:
            user.created_at,
          roles:
            normalizedRoles,
        }
      })

    setUsers(normalizedUsers)
  }

  const loadData = async () => {
    setIsLoading(true)
    setError('')

    try {
      await Promise.all([
        loadRoles(),
        loadUsers(),
      ])
    } catch (loadError) {
      console.error(
        'Gagal memuat data pengguna:',
        loadError,
      )

      setError(
        loadError instanceof Error
          ? loadError.message
          : 'Gagal memuat data pengguna.',
      )
    } finally {
      setIsLoading(false)
    }
  }

  useEffect(() => {
    void loadData()
  }, [])

  const statistics = useMemo(() => {
    const total = users.length

    const active =
      users.filter(
        (user) =>
          user.is_active,
      ).length

    return {
      total,
      active,
      inactive:
        total - active,
    }
  }, [users])

  const filteredUsers = useMemo(() => {
    const normalizedSearch =
      search
        .trim()
        .toLowerCase()

    return users.filter(
      (user) => {
        const role =
          getPrimaryRole(user)

        const matchesSearch =
          !normalizedSearch ||
          user.full_name
            .toLowerCase()
            .includes(
              normalizedSearch,
            ) ||
          user.email
            .toLowerCase()
            .includes(
              normalizedSearch,
            )

        const matchesRole =
          roleFilter === 'all' ||
          role?.code ===
            roleFilter

        const matchesStatus =
          statusFilter === 'all' ||
          (statusFilter ===
            'active' &&
            user.is_active) ||
          (statusFilter ===
            'inactive' &&
            !user.is_active)

        return (
          matchesSearch &&
          matchesRole &&
          matchesStatus
        )
      },
    )
  }, [
    users,
    search,
    roleFilter,
    statusFilter,
  ])

  const openCreateModal =
    () => {
      setEditingUser(null)
      setForm(defaultForm)
      setError('')
      setSuccess('')
      setIsModalOpen(true)
    }

  const openEditModal = (
    user: UserRecord,
  ) => {
    const role =
      getPrimaryRole(user)

    setEditingUser(user)

    setForm({
      fullName:
        user.full_name,
      email:
        user.email,
      password: '',
      confirmPassword: '',
      role:
        role?.code ??
        'admin',
    })

    setError('')
    setSuccess('')
    setIsModalOpen(true)
  }

  const closeModal = () => {
    if (isSubmitting) {
      return
    }

    setIsModalOpen(false)
    setEditingUser(null)
    setForm(defaultForm)
    setError('')
  }

  const handleSubmit = async (
    event: FormEvent<HTMLFormElement>,
  ) => {
    event.preventDefault()

    setError('')
    setSuccess('')

    const fullName =
      form.fullName.trim()

    const email =
      form.email
        .trim()
        .toLowerCase()

    if (!fullName) {
      setError(
        'Nama lengkap wajib diisi.',
      )
      return
    }

    if (!email) {
      setError(
        'Email wajib diisi.',
      )
      return
    }

    if (!editingUser) {
      if (
        form.password.length <
        8
      ) {
        setError(
          'Password minimal 8 karakter.',
        )
        return
      }

      if (
        form.password !==
        form.confirmPassword
      ) {
        setError(
          'Konfirmasi password tidak sama.',
        )
        return
      }
    }

    if (
      editingUser &&
      editingUser.roles.some(
        (role) =>
          role.code ===
          'super_admin',
      ) &&
      form.role !==
        'super_admin'
    ) {
      setError(
        'Role akun Super Admin tidak dapat diturunkan melalui form ini.',
      )
      return
    }

    setIsSubmitting(true)

    try {
      if (editingUser) {
        await updateUser({
          userId:
            editingUser.id,
          email,
          fullName,
          role: form.role,
        })

        setSuccess(
          'Data pengguna berhasil diperbarui.',
        )
      } else {
        await createUser({
          email,
          password:
            form.password,
          fullName,
          role: form.role,
        })

        setSuccess(
          'Akun pengguna berhasil dibuat.',
        )
      }

      await loadUsers()

      setIsModalOpen(false)
      setEditingUser(null)
      setForm(defaultForm)
    } catch (submitError) {
      console.error(
        'Gagal menyimpan pengguna:',
        submitError,
      )

      setError(
        submitError instanceof Error
          ? submitError.message
          : 'Gagal menyimpan data pengguna.',
      )
    } finally {
      setIsSubmitting(false)
    }
  }

  const requestStatusChange = (
    user: UserRecord,
  ) => {
    const role =
      getPrimaryRole(user)

    if (
      role?.code ===
      'super_admin'
    ) {
      setError(
        'Akun Super Admin tidak dapat dinonaktifkan melalui fitur ini.',
      )
      setSuccess('')
      return
    }

    setError('')
    setSuccess('')

    setStatusConfirmation({
      user,
      nextStatus:
        !user.is_active,
    })
  }

  const closeStatusConfirmation =
    () => {
      if (
        processingStatusUserId
      ) {
        return
      }

      setStatusConfirmation(
        null,
      )
    }

  const handleStatusChange =
    async () => {
      if (
        !statusConfirmation
      ) {
        return
      }

      const {
        user,
        nextStatus,
      } =
        statusConfirmation

      setProcessingStatusUserId(
        user.id,
      )
      setError('')
      setSuccess('')

      try {
        if (nextStatus) {
          await activateUser(
            user.id,
          )
        } else {
          await deactivateUser(
            user.id,
          )
        }

        setUsers(
          (currentUsers) =>
            currentUsers.map(
              (currentUser) =>
                currentUser.id ===
                user.id
                  ? {
                      ...currentUser,
                      is_active:
                        nextStatus,
                    }
                  : currentUser,
            ),
        )

        setSuccess(
          nextStatus
            ? `Akun ${user.full_name} berhasil diaktifkan.`
            : `Akun ${user.full_name} berhasil dinonaktifkan.`,
        )

        setStatusConfirmation(
          null,
        )
      } catch (statusError) {
        console.error(
          'Gagal mengubah status pengguna:',
          statusError,
        )

        setError(
          statusError instanceof Error
            ? statusError.message
            : 'Gagal mengubah status pengguna.',
        )
      } finally {
        setProcessingStatusUserId(
          null,
        )
      }
    }

  return (
    <div className="min-h-full bg-slate-50 px-4 py-6 dark:bg-slate-950 sm:px-6 lg:px-8">
      <div className="mx-auto max-w-7xl">
        <div className="mb-6 flex flex-col gap-4 sm:flex-row sm:items-end sm:justify-between">
          <div>
            <p className="text-sm font-medium text-emerald-600 dark:text-emerald-400">
              Administrasi Sistem
            </p>

            <h1 className="mt-1 text-2xl font-semibold tracking-tight text-slate-950 dark:text-white">
              Pengguna & Hak Akses
            </h1>

            <p className="mt-2 max-w-2xl text-sm leading-6 text-slate-500 dark:text-slate-400">
              Kelola akun pengguna,
              role, dan status akses
              ke sistem administrasi
              sekolah.
            </p>
          </div>

          <button
            type="button"
            onClick={
              openCreateModal
            }
            className="inline-flex h-11 items-center justify-center gap-2 rounded-xl bg-slate-900 px-4 text-sm font-semibold text-white shadow-sm transition hover:bg-slate-800 dark:bg-white dark:text-slate-900 dark:hover:bg-slate-200"
          >
            <Plus
              className="h-4 w-4"
              strokeWidth={2}
            />
            Tambah Pengguna
          </button>
        </div>

        {success && (
          <div className="mb-5 flex items-start gap-3 rounded-xl border border-emerald-200 bg-emerald-50 px-4 py-3 text-sm text-emerald-800 dark:border-emerald-900/60 dark:bg-emerald-950/30 dark:text-emerald-300">
            <Check className="mt-0.5 h-4 w-4 shrink-0" />

            <span>{success}</span>

            <button
              type="button"
              onClick={() =>
                setSuccess('')
              }
              className="ml-auto rounded-md p-1 opacity-60 transition hover:bg-emerald-100 hover:opacity-100 dark:hover:bg-emerald-900/40"
              aria-label="Tutup pesan"
            >
              <X className="h-4 w-4" />
            </button>
          </div>
        )}

        {error &&
          !isModalOpen && (
            <div className="mb-5 flex items-start gap-3 rounded-xl border border-red-200 bg-red-50 px-4 py-3 text-sm text-red-700 dark:border-red-900/60 dark:bg-red-950/30 dark:text-red-300">
              <AlertTriangle className="mt-0.5 h-4 w-4 shrink-0" />

              <span>{error}</span>

              <button
                type="button"
                onClick={() =>
                  setError('')
                }
                className="ml-auto rounded-md p-1 opacity-60 transition hover:bg-red-100 hover:opacity-100 dark:hover:bg-red-900/40"
                aria-label="Tutup pesan"
              >
                <X className="h-4 w-4" />
              </button>
            </div>
          )}

        <div className="mb-6 grid grid-cols-1 gap-4 sm:grid-cols-3">
          <div className="rounded-2xl border border-slate-200 bg-white p-5 shadow-sm dark:border-slate-800 dark:bg-slate-900">
            <div className="flex items-center justify-between">
              <div>
                <p className="text-sm text-slate-500 dark:text-slate-400">
                  Total Pengguna
                </p>

                <p className="mt-2 text-2xl font-semibold text-slate-950 dark:text-white">
                  {statistics.total}
                </p>
              </div>

              <div className="flex h-10 w-10 items-center justify-center rounded-xl bg-slate-100 text-slate-600 dark:bg-slate-800 dark:text-slate-300">
                <Users className="h-5 w-5" />
              </div>
            </div>
          </div>

          <div className="rounded-2xl border border-slate-200 bg-white p-5 shadow-sm dark:border-slate-800 dark:bg-slate-900">
            <div className="flex items-center justify-between">
              <div>
                <p className="text-sm text-slate-500 dark:text-slate-400">
                  Pengguna Aktif
                </p>

                <p className="mt-2 text-2xl font-semibold text-slate-950 dark:text-white">
                  {statistics.active}
                </p>
              </div>

              <div className="flex h-10 w-10 items-center justify-center rounded-xl bg-emerald-50 text-emerald-600 dark:bg-emerald-950/30 dark:text-emerald-400">
                <Check className="h-5 w-5" />
              </div>
            </div>
          </div>

          <div className="rounded-2xl border border-slate-200 bg-white p-5 shadow-sm dark:border-slate-800 dark:bg-slate-900">
            <div className="flex items-center justify-between">
              <div>
                <p className="text-sm text-slate-500 dark:text-slate-400">
                  Nonaktif
                </p>

                <p className="mt-2 text-2xl font-semibold text-slate-950 dark:text-white">
                  {statistics.inactive}
                </p>
              </div>

              <div className="flex h-10 w-10 items-center justify-center rounded-xl bg-slate-100 text-slate-600 dark:bg-slate-800 dark:text-slate-300">
                <Power className="h-5 w-5" />
              </div>
            </div>
          </div>
        </div>

        <div className="mb-5 rounded-2xl border border-slate-200 bg-white p-4 shadow-sm dark:border-slate-800 dark:bg-slate-900">
          <div className="grid grid-cols-1 gap-3 lg:grid-cols-[minmax(0,1fr)_220px_180px]">
            <div className="relative">
              <Search className="pointer-events-none absolute left-3 top-1/2 h-4 w-4 -translate-y-1/2 text-slate-400" />

              <input
                type="search"
                value={search}
                onChange={(
                  event,
                ) =>
                  setSearch(
                    event.target.value,
                  )
                }
                placeholder="Cari nama atau email..."
                className="h-11 w-full rounded-xl border border-slate-200 bg-slate-50 pl-10 pr-4 text-sm text-slate-900 outline-none transition placeholder:text-slate-400 focus:border-emerald-500 focus:bg-white focus:ring-2 focus:ring-emerald-500/10 dark:border-slate-700 dark:bg-slate-950 dark:text-white dark:focus:border-emerald-400"
              />
            </div>

            <div className="relative">
              <select
                value={roleFilter}
                onChange={(
                  event,
                ) =>
                  setRoleFilter(
                    event.target
                      .value,
                  )
                }
                className="h-11 w-full appearance-none rounded-xl border border-slate-200 bg-slate-50 px-4 pr-10 text-sm text-slate-700 outline-none transition focus:border-emerald-500 dark:border-slate-700 dark:bg-slate-950 dark:text-slate-300 dark:focus:border-emerald-400"
              >
                <option value="all">
                  Semua Role
                </option>

                {roles.map(
                  (role) => (
                    <option
                      key={role.id}
                      value={
                        role.code
                      }
                    >
                      {role.name}
                    </option>
                  ),
                )}
              </select>

              <ChevronDown className="pointer-events-none absolute right-3 top-1/2 h-4 w-4 -translate-y-1/2 text-slate-400" />
            </div>

            <div className="relative">
              <select
                value={
                  statusFilter
                }
                onChange={(
                  event,
                ) =>
                  setStatusFilter(
                    event.target
                      .value as
                      | 'all'
                      | 'active'
                      | 'inactive',
                  )
                }
                className="h-11 w-full appearance-none rounded-xl border border-slate-200 bg-slate-50 px-4 pr-10 text-sm text-slate-700 outline-none transition focus:border-emerald-500 dark:border-slate-700 dark:bg-slate-950 dark:text-slate-300 dark:focus:border-emerald-400"
              >
                <option value="all">
                  Semua Status
                </option>

                <option value="active">
                  Aktif
                </option>

                <option value="inactive">
                  Nonaktif
                </option>
              </select>

              <ChevronDown className="pointer-events-none absolute right-3 top-1/2 h-4 w-4 -translate-y-1/2 text-slate-400" />
            </div>
          </div>
        </div>

        <div className="overflow-hidden rounded-2xl border border-slate-200 bg-white shadow-sm dark:border-slate-800 dark:bg-slate-900">
          {isLoading ? (
            <div className="flex min-h-64 items-center justify-center">
              <div className="flex flex-col items-center gap-3">
                <div className="h-7 w-7 animate-spin rounded-full border-2 border-slate-200 border-t-emerald-600 dark:border-slate-700 dark:border-t-emerald-400" />

                <p className="text-sm text-slate-500 dark:text-slate-400">
                  Memuat pengguna...
                </p>
              </div>
            </div>
          ) : filteredUsers.length ===
            0 ? (
            <div className="flex min-h-64 flex-col items-center justify-center px-6 text-center">
              <div className="flex h-12 w-12 items-center justify-center rounded-xl bg-slate-100 text-slate-500 dark:bg-slate-800 dark:text-slate-400">
                <Users className="h-5 w-5" />
              </div>

              <h2 className="mt-4 text-sm font-semibold text-slate-900 dark:text-white">
                Tidak ada pengguna
              </h2>

              <p className="mt-1 max-w-sm text-sm text-slate-500 dark:text-slate-400">
                Tidak ada data yang
                sesuai dengan
                pencarian atau
                filter yang dipilih.
              </p>
            </div>
          ) : (
            <>
              <div className="hidden overflow-x-auto md:block">
                <table className="w-full min-w-[980px]">
                  <thead>
                    <tr className="border-b border-slate-200 bg-slate-50/80 dark:border-slate-800 dark:bg-slate-950/60">
                      <th className="px-6 py-4 text-left text-xs font-semibold uppercase tracking-wide text-slate-500 dark:text-slate-400">
                        Pengguna
                      </th>

                      <th className="px-6 py-4 text-left text-xs font-semibold uppercase tracking-wide text-slate-500 dark:text-slate-400">
                        Role
                      </th>

                      <th className="px-6 py-4 text-left text-xs font-semibold uppercase tracking-wide text-slate-500 dark:text-slate-400">
                        Status
                      </th>

                      <th className="px-6 py-4 text-left text-xs font-semibold uppercase tracking-wide text-slate-500 dark:text-slate-400">
                        Dibuat
                      </th>

                      <th className="px-6 py-4 text-right text-xs font-semibold uppercase tracking-wide text-slate-500 dark:text-slate-400">
                        Aksi
                      </th>
                    </tr>
                  </thead>

                  <tbody className="divide-y divide-slate-100 dark:divide-slate-800">
                    {filteredUsers.map(
                      (user) => {
                        const role =
                          getPrimaryRole(
                            user,
                          )

                        const isProcessing =
                          processingStatusUserId ===
                          user.id

                        const isSuperAdmin =
                          role?.code ===
                          'super_admin'

                        return (
                          <tr
                            key={
                              user.id
                            }
                            className="transition hover:bg-slate-50/70 dark:hover:bg-slate-800/30"
                          >
                            <td className="px-6 py-4">
                              <div className="flex items-center gap-3">
                                <div className="flex h-10 w-10 shrink-0 items-center justify-center rounded-xl bg-slate-100 text-sm font-semibold text-slate-600 dark:bg-slate-800 dark:text-slate-300">
                                  {getInitials(
                                    user.full_name,
                                  )}
                                </div>

                                <div className="min-w-0">
                                  <p className="truncate text-sm font-semibold text-slate-900 dark:text-white">
                                    {
                                      user.full_name
                                    }
                                  </p>

                                  <div className="mt-1 flex items-center gap-1.5 text-xs text-slate-500 dark:text-slate-400">
                                    <Mail className="h-3.5 w-3.5" />

                                    <span className="truncate">
                                      {
                                        user.email
                                      }
                                    </span>
                                  </div>
                                </div>
                              </div>
                            </td>

                            <td className="px-6 py-4">
                              {role ? (
                                <span
                                  className={`inline-flex items-center rounded-full px-2.5 py-1 text-xs font-medium ${roleBadgeClasses[role.code]}`}
                                >
                                  {
                                    roleLabels[
                                      role.code
                                    ]
                                  }
                                </span>
                              ) : (
                                <span className="text-xs text-slate-400">
                                  Belum ada
                                </span>
                              )}
                            </td>

                            <td className="px-6 py-4">
                              <span
                                className={`inline-flex items-center gap-1.5 rounded-full px-2.5 py-1 text-xs font-medium ${
                                  user.is_active
                                    ? 'bg-emerald-50 text-emerald-700 dark:bg-emerald-950/40 dark:text-emerald-300'
                                    : 'bg-slate-100 text-slate-600 dark:bg-slate-800 dark:text-slate-300'
                                }`}
                              >
                                <span
                                  className={`h-1.5 w-1.5 rounded-full ${
                                    user.is_active
                                      ? 'bg-emerald-500'
                                      : 'bg-slate-400'
                                  }`}
                                />

                                {user.is_active
                                  ? 'Aktif'
                                  : 'Nonaktif'}
                              </span>
                            </td>

                            <td className="px-6 py-4 text-sm text-slate-500 dark:text-slate-400">
                              {formatDate(
                                user.created_at,
                              )}
                            </td>

                            <td className="px-6 py-4">
                              <div className="flex justify-end gap-2">
                                <button
                                  type="button"
                                  onClick={() =>
                                    openEditModal(
                                      user,
                                    )
                                  }
                                  className="inline-flex h-9 items-center justify-center gap-2 rounded-lg border border-slate-200 bg-white px-3 text-xs font-semibold text-slate-700 transition hover:border-slate-300 hover:bg-slate-50 dark:border-slate-700 dark:bg-slate-900 dark:text-slate-300 dark:hover:bg-slate-800"
                                >
                                  <Pencil className="h-3.5 w-3.5" />

                                  Edit
                                </button>

                                {!isSuperAdmin && (
                                  <button
                                    type="button"
                                    onClick={() =>
                                      requestStatusChange(
                                        user,
                                      )
                                    }
                                    disabled={
                                      isProcessing
                                    }
                                    className={`inline-flex h-9 items-center justify-center gap-2 rounded-lg px-3 text-xs font-semibold transition disabled:cursor-not-allowed disabled:opacity-60 ${
                                      user.is_active
                                        ? 'border border-red-200 bg-white text-red-600 hover:bg-red-50 dark:border-red-900/60 dark:bg-slate-900 dark:text-red-400 dark:hover:bg-red-950/30'
                                        : 'border border-emerald-200 bg-white text-emerald-700 hover:bg-emerald-50 dark:border-emerald-900/60 dark:bg-slate-900 dark:text-emerald-400 dark:hover:bg-emerald-950/30'
                                    }`}
                                  >
                                    {isProcessing ? (
                                      <span className="h-3.5 w-3.5 animate-spin rounded-full border-2 border-slate-300 border-t-current" />
                                    ) : (
                                      <Power className="h-3.5 w-3.5" />
                                    )}

                                    {user.is_active
                                      ? 'Nonaktifkan'
                                      : 'Aktifkan'}
                                  </button>
                                )}
                              </div>
                            </td>
                          </tr>
                        )
                      },
                    )}
                  </tbody>
                </table>
              </div>

              <div className="divide-y divide-slate-100 md:hidden dark:divide-slate-800">
                {filteredUsers.map(
                  (user) => {
                    const role =
                      getPrimaryRole(
                        user,
                      )

                    const isProcessing =
                      processingStatusUserId ===
                      user.id

                    const isSuperAdmin =
                      role?.code ===
                      'super_admin'

                    return (
                      <div
                        key={
                          user.id
                        }
                        className="p-4"
                      >
                        <div className="flex items-start justify-between gap-3">
                          <div className="flex min-w-0 items-center gap-3">
                            <div className="flex h-10 w-10 shrink-0 items-center justify-center rounded-xl bg-slate-100 text-sm font-semibold text-slate-600 dark:bg-slate-800 dark:text-slate-300">
                              {getInitials(
                                user.full_name,
                              )}
                            </div>

                            <div className="min-w-0">
                              <p className="truncate text-sm font-semibold text-slate-900 dark:text-white">
                                {
                                  user.full_name
                                }
                              </p>

                              <p className="mt-1 truncate text-xs text-slate-500 dark:text-slate-400">
                                {
                                  user.email
                                }
                              </p>
                            </div>
                          </div>

                          <button
                            type="button"
                            onClick={() =>
                              openEditModal(
                                user,
                              )
                            }
                            className="inline-flex h-9 shrink-0 items-center justify-center gap-2 rounded-lg border border-slate-200 px-3 text-xs font-semibold text-slate-700 dark:border-slate-700 dark:text-slate-300"
                          >
                            <Pencil className="h-3.5 w-3.5" />

                            Edit
                          </button>
                        </div>

                        <div className="mt-4 flex flex-wrap items-center gap-2">
                          {role && (
                            <span
                              className={`inline-flex items-center rounded-full px-2.5 py-1 text-xs font-medium ${roleBadgeClasses[role.code]}`}
                            >
                              {
                                roleLabels[
                                  role.code
                                ]
                              }
                            </span>
                          )}

                          <span
                            className={`inline-flex items-center gap-1.5 rounded-full px-2.5 py-1 text-xs font-medium ${
                              user.is_active
                                ? 'bg-emerald-50 text-emerald-700 dark:bg-emerald-950/40 dark:text-emerald-300'
                                : 'bg-slate-100 text-slate-600 dark:bg-slate-800 dark:text-slate-300'
                            }`}
                          >
                            <span
                              className={`h-1.5 w-1.5 rounded-full ${
                                user.is_active
                                  ? 'bg-emerald-500'
                                  : 'bg-slate-400'
                              }`}
                            />

                            {user.is_active
                              ? 'Aktif'
                              : 'Nonaktif'}
                          </span>

                          <span className="text-xs text-slate-400 dark:text-slate-500">
                            {formatDate(
                              user.created_at,
                            )}
                          </span>
                        </div>

                        {!isSuperAdmin && (
                          <button
                            type="button"
                            onClick={() =>
                              requestStatusChange(
                                user,
                              )
                            }
                            disabled={
                              isProcessing
                            }
                            className={`mt-4 inline-flex h-10 w-full items-center justify-center gap-2 rounded-xl text-sm font-semibold transition disabled:cursor-not-allowed disabled:opacity-60 ${
                              user.is_active
                                ? 'border border-red-200 bg-white text-red-600 hover:bg-red-50 dark:border-red-900/60 dark:bg-slate-900 dark:text-red-400 dark:hover:bg-red-950/30'
                                : 'border border-emerald-200 bg-white text-emerald-700 hover:bg-emerald-50 dark:border-emerald-900/60 dark:bg-slate-900 dark:text-emerald-400 dark:hover:bg-emerald-950/30'
                            }`}
                          >
                            {isProcessing ? (
                              <span className="h-4 w-4 animate-spin rounded-full border-2 border-slate-300 border-t-current" />
                            ) : (
                              <Power className="h-4 w-4" />
                            )}

                            {user.is_active
                              ? 'Nonaktifkan Pengguna'
                              : 'Aktifkan Pengguna'}
                          </button>
                        )}
                      </div>
                    )
                  },
                )}
              </div>
            </>
          )}
        </div>
      </div>

      {isModalOpen && (
        <div className="fixed inset-0 z-50 flex items-center justify-center overflow-y-auto bg-slate-950/50 p-4 backdrop-blur-sm">
          <div
            role="dialog"
            aria-modal="true"
            aria-labelledby="user-modal-title"
            className="w-full max-w-lg rounded-2xl border border-slate-200 bg-white shadow-2xl dark:border-slate-800 dark:bg-slate-900"
          >
            <div className="flex items-start justify-between border-b border-slate-200 px-6 py-5 dark:border-slate-800">
              <div>
                <div className="flex items-center gap-2">
                  {editingUser ? (
                    <Pencil className="h-4 w-4 text-emerald-600 dark:text-emerald-400" />
                  ) : (
                    <ShieldCheck className="h-4 w-4 text-emerald-600 dark:text-emerald-400" />
                  )}

                  <h2
                    id="user-modal-title"
                    className="text-lg font-semibold text-slate-950 dark:text-white"
                  >
                    {editingUser
                      ? 'Edit Pengguna'
                      : 'Tambah Pengguna'}
                  </h2>
                </div>

                <p className="mt-1 text-sm text-slate-500 dark:text-slate-400">
                  {editingUser
                    ? 'Perbarui informasi akun dan role pengguna.'
                    : 'Buat akun baru untuk pengguna sistem sekolah.'}
                </p>
              </div>

              <button
                type="button"
                onClick={
                  closeModal
                }
                disabled={
                  isSubmitting
                }
                className="flex h-9 w-9 items-center justify-center rounded-lg text-slate-400 transition hover:bg-slate-100 hover:text-slate-600 disabled:cursor-not-allowed disabled:opacity-50 dark:hover:bg-slate-800 dark:hover:text-slate-200"
                aria-label="Tutup"
              >
                <X className="h-5 w-5" />
              </button>
            </div>

            <form
              onSubmit={
                handleSubmit
              }
            >
              <div className="space-y-5 px-6 py-6">
                {error && (
                  <div className="rounded-xl border border-red-200 bg-red-50 px-4 py-3 text-sm leading-5 text-red-700 dark:border-red-900/60 dark:bg-red-950/30 dark:text-red-300">
                    {error}
                  </div>
                )}

                <div>
                  <label
                    htmlFor="fullName"
                    className="mb-2 block text-sm font-medium text-slate-700 dark:text-slate-300"
                  >
                    Nama Lengkap
                  </label>

                  <div className="relative">
                    <User className="pointer-events-none absolute left-3 top-1/2 h-4 w-4 -translate-y-1/2 text-slate-400" />

                    <input
                      id="fullName"
                      type="text"
                      value={
                        form.fullName
                      }
                      onChange={(
                        event,
                      ) =>
                        setForm(
                          (
                            current,
                          ) => ({
                            ...current,
                            fullName:
                              event
                                .target
                                .value,
                          }),
                        )
                      }
                      placeholder="Masukkan nama lengkap"
                      disabled={
                        isSubmitting
                      }
                      className="h-11 w-full rounded-xl border border-slate-200 bg-white pl-10 pr-4 text-sm text-slate-900 outline-none transition placeholder:text-slate-400 focus:border-emerald-500 focus:ring-2 focus:ring-emerald-500/10 disabled:cursor-not-allowed disabled:bg-slate-50 dark:border-slate-700 dark:bg-slate-950 dark:text-white dark:focus:border-emerald-400 dark:disabled:bg-slate-900"
                    />
                  </div>
                </div>

                <div>
                  <label
                    htmlFor="email"
                    className="mb-2 block text-sm font-medium text-slate-700 dark:text-slate-300"
                  >
                    Email
                  </label>

                  <div className="relative">
                    <Mail className="pointer-events-none absolute left-3 top-1/2 h-4 w-4 -translate-y-1/2 text-slate-400" />

                    <input
                      id="email"
                      type="email"
                      value={
                        form.email
                      }
                      onChange={(
                        event,
                      ) =>
                        setForm(
                          (
                            current,
                          ) => ({
                            ...current,
                            email:
                              event
                                .target
                                .value,
                          }),
                        )
                      }
                      placeholder="nama@sekolah.sch.id"
                      disabled={
                        isSubmitting
                      }
                      className="h-11 w-full rounded-xl border border-slate-200 bg-white pl-10 pr-4 text-sm text-slate-900 outline-none transition placeholder:text-slate-400 focus:border-emerald-500 focus:ring-2 focus:ring-emerald-500/10 disabled:cursor-not-allowed disabled:bg-slate-50 dark:border-slate-700 dark:bg-slate-950 dark:text-white dark:focus:border-emerald-400 dark:disabled:bg-slate-900"
                    />
                  </div>
                </div>

                {!editingUser && (
                  <div className="grid grid-cols-1 gap-5 sm:grid-cols-2">
                    <div>
                      <label
                        htmlFor="password"
                        className="mb-2 block text-sm font-medium text-slate-700 dark:text-slate-300"
                      >
                        Password
                      </label>

                      <div className="relative">
                        <KeyRound className="pointer-events-none absolute left-3 top-1/2 h-4 w-4 -translate-y-1/2 text-slate-400" />

                        <input
                          id="password"
                          type="password"
                          value={
                            form.password
                          }
                          onChange={(
                            event,
                          ) =>
                            setForm(
                              (
                                current,
                              ) => ({
                                ...current,
                                password:
                                  event
                                    .target
                                    .value,
                              }),
                            )
                          }
                          placeholder="Minimal 8 karakter"
                          disabled={
                            isSubmitting
                          }
                          className="h-11 w-full rounded-xl border border-slate-200 bg-white pl-10 pr-4 text-sm text-slate-900 outline-none transition placeholder:text-slate-400 focus:border-emerald-500 focus:ring-2 focus:ring-emerald-500/10 disabled:cursor-not-allowed disabled:bg-slate-50 dark:border-slate-700 dark:bg-slate-950 dark:text-white dark:focus:border-emerald-400 dark:disabled:bg-slate-900"
                        />
                      </div>
                    </div>

                    <div>
                      <label
                        htmlFor="confirmPassword"
                        className="mb-2 block text-sm font-medium text-slate-700 dark:text-slate-300"
                      >
                        Konfirmasi Password
                      </label>

                      <div className="relative">
                        <KeyRound className="pointer-events-none absolute left-3 top-1/2 h-4 w-4 -translate-y-1/2 text-slate-400" />

                        <input
                          id="confirmPassword"
                          type="password"
                          value={
                            form.confirmPassword
                          }
                          onChange={(
                            event,
                          ) =>
                            setForm(
                              (
                                current,
                              ) => ({
                                ...current,
                                confirmPassword:
                                  event
                                    .target
                                    .value,
                              }),
                            )
                          }
                          placeholder="Ulangi password"
                          disabled={
                            isSubmitting
                          }
                          className="h-11 w-full rounded-xl border border-slate-200 bg-white pl-10 pr-4 text-sm text-slate-900 outline-none transition placeholder:text-slate-400 focus:border-emerald-500 focus:ring-2 focus:ring-emerald-500/10 disabled:cursor-not-allowed disabled:bg-slate-50 dark:border-slate-700 dark:bg-slate-950 dark:text-white dark:focus:border-emerald-400 dark:disabled:bg-slate-900"
                        />
                      </div>
                    </div>
                  </div>
                )}

                <div>
                  <label
                    htmlFor="role"
                    className="mb-2 block text-sm font-medium text-slate-700 dark:text-slate-300"
                  >
                    Role Pengguna
                  </label>

                  <div className="relative">
                    <select
                      id="role"
                      value={
                        form.role
                      }
                      onChange={(
                        event,
                      ) =>
                        setForm(
                          (
                            current,
                          ) => ({
                            ...current,
                            role:
                              event
                                .target
                                .value as CreateUserRole,
                          }),
                        )
                      }
                      disabled={
                        isSubmitting ||
                        Boolean(
                          editingUser?.roles.some(
                            (
                              role,
                            ) =>
                              role.code ===
                              'super_admin',
                          ),
                        )
                      }
                      className="h-11 w-full appearance-none rounded-xl border border-slate-200 bg-white px-4 pr-10 text-sm text-slate-900 outline-none transition focus:border-emerald-500 focus:ring-2 focus:ring-emerald-500/10 disabled:cursor-not-allowed disabled:bg-slate-50 dark:border-slate-700 dark:bg-slate-950 dark:text-white dark:focus:border-emerald-400 dark:disabled:bg-slate-900"
                    >
                      {roles.map(
                        (role) => (
                          <option
                            key={
                              role.id
                            }
                            value={
                              role.code
                            }
                          >
                            {
                              role.name
                            }
                          </option>
                        ),
                      )}
                    </select>

                    <ChevronDown className="pointer-events-none absolute right-3 top-1/2 h-4 w-4 -translate-y-1/2 text-slate-400" />
                  </div>

                  {editingUser &&
                    editingUser.roles.some(
                      (
                        role,
                      ) =>
                        role.code ===
                        'super_admin',
                    ) && (
                      <p className="mt-2 text-xs leading-5 text-slate-500 dark:text-slate-400">
                        Role Super Admin
                        dilindungi dan
                        tidak dapat
                        diturunkan melalui
                        form edit biasa.
                      </p>
                    )}
                </div>

                <div className="rounded-xl border border-slate-200 bg-slate-50 px-4 py-3 dark:border-slate-800 dark:bg-slate-950">
                  <div className="flex gap-3">
                    <ShieldCheck className="mt-0.5 h-4 w-4 shrink-0 text-emerald-600 dark:text-emerald-400" />

                    <p className="text-xs leading-5 text-slate-500 dark:text-slate-400">
                      {editingUser
                        ? 'Perubahan role akan langsung memengaruhi hak akses pengguna pada sistem.'
                        : 'Akun akan dibuat sebagai pengguna aktif dan langsung dapat digunakan untuk login. Hak akses mengikuti role yang dipilih.'}
                    </p>
                  </div>
                </div>
              </div>

              <div className="flex flex-col-reverse gap-3 border-t border-slate-200 px-6 py-5 sm:flex-row sm:justify-end dark:border-slate-800">
                <button
                  type="button"
                  onClick={
                    closeModal
                  }
                  disabled={
                    isSubmitting
                  }
                  className="h-11 rounded-xl border border-slate-200 px-4 text-sm font-semibold text-slate-700 transition hover:bg-slate-50 disabled:cursor-not-allowed disabled:opacity-50 dark:border-slate-700 dark:text-slate-300 dark:hover:bg-slate-800"
                >
                  Batal
                </button>

                <button
                  type="submit"
                  disabled={
                    isSubmitting
                  }
                  className="inline-flex h-11 items-center justify-center gap-2 rounded-xl bg-slate-900 px-5 text-sm font-semibold text-white transition hover:bg-slate-800 disabled:cursor-not-allowed disabled:opacity-60 dark:bg-white dark:text-slate-900 dark:hover:bg-slate-200"
                >
                  {isSubmitting ? (
                    <>
                      <span className="h-4 w-4 animate-spin rounded-full border-2 border-white/30 border-t-white dark:border-slate-300 dark:border-t-slate-900" />

                      Menyimpan...
                    </>
                  ) : (
                    <>
                      <Check className="h-4 w-4" />

                      {editingUser
                        ? 'Simpan Perubahan'
                        : 'Buat Akun'}
                    </>
                  )}
                </button>
              </div>
            </form>
          </div>
        </div>
      )}

      {statusConfirmation && (
        <div className="fixed inset-0 z-[60] flex items-center justify-center bg-slate-950/50 p-4 backdrop-blur-sm">
          <div
            role="dialog"
            aria-modal="true"
            aria-labelledby="status-dialog-title"
            className="w-full max-w-md rounded-2xl border border-slate-200 bg-white p-6 shadow-2xl dark:border-slate-800 dark:bg-slate-900"
          >
            <div className="flex items-start gap-4">
              <div
                className={`flex h-11 w-11 shrink-0 items-center justify-center rounded-xl ${
                  statusConfirmation.nextStatus
                    ? 'bg-emerald-50 text-emerald-600 dark:bg-emerald-950/30 dark:text-emerald-400'
                    : 'bg-amber-50 text-amber-600 dark:bg-amber-950/30 dark:text-amber-400'
                }`}
              >
                {statusConfirmation.nextStatus ? (
                  <Power className="h-5 w-5" />
                ) : (
                  <AlertTriangle className="h-5 w-5" />
                )}
              </div>

              <div className="min-w-0 flex-1">
                <h2
                  id="status-dialog-title"
                  className="text-lg font-semibold text-slate-950 dark:text-white"
                >
                  {statusConfirmation.nextStatus
                    ? 'Aktifkan pengguna?'
                    : 'Nonaktifkan pengguna?'}
                </h2>

                <p className="mt-2 text-sm leading-6 text-slate-500 dark:text-slate-400">
                  {statusConfirmation.nextStatus
                    ? `Akun ${statusConfirmation.user.full_name} akan dapat digunakan kembali untuk mengakses sistem.`
                    : `Akun ${statusConfirmation.user.full_name} tidak dapat digunakan untuk mengakses sistem sampai diaktifkan kembali. Data dan riwayat pengguna tetap tersimpan.`}
                </p>
              </div>

              <button
                type="button"
                onClick={
                  closeStatusConfirmation
                }
                disabled={
                  Boolean(
                    processingStatusUserId,
                  )
                }
                className="flex h-8 w-8 shrink-0 items-center justify-center rounded-lg text-slate-400 transition hover:bg-slate-100 hover:text-slate-600 disabled:cursor-not-allowed disabled:opacity-50 dark:hover:bg-slate-800 dark:hover:text-slate-200"
                aria-label="Tutup"
              >
                <X className="h-4 w-4" />
              </button>
            </div>

            <div className="mt-6 flex flex-col-reverse gap-3 sm:flex-row sm:justify-end">
              <button
                type="button"
                onClick={
                  closeStatusConfirmation
                }
                disabled={
                  Boolean(
                    processingStatusUserId,
                  )
                }
                className="h-11 rounded-xl border border-slate-200 px-4 text-sm font-semibold text-slate-700 transition hover:bg-slate-50 disabled:cursor-not-allowed disabled:opacity-50 dark:border-slate-700 dark:text-slate-300 dark:hover:bg-slate-800"
              >
                Batal
              </button>

              <button
                type="button"
                onClick={
                  handleStatusChange
                }
                disabled={
                  Boolean(
                    processingStatusUserId,
                  )
                }
                className={`inline-flex h-11 items-center justify-center gap-2 rounded-xl px-5 text-sm font-semibold text-white transition disabled:cursor-not-allowed disabled:opacity-60 ${
                  statusConfirmation.nextStatus
                    ? 'bg-emerald-600 hover:bg-emerald-700'
                    : 'bg-slate-900 hover:bg-slate-800 dark:bg-white dark:text-slate-900 dark:hover:bg-slate-200'
                }`}
              >
                {processingStatusUserId ? (
                  <span className="h-4 w-4 animate-spin rounded-full border-2 border-white/30 border-t-white dark:border-slate-300 dark:border-t-slate-900" />
                ) : (
                  <Power className="h-4 w-4" />
                )}

                {statusConfirmation.nextStatus
                  ? 'Aktifkan'
                  : 'Nonaktifkan'}
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  )
}