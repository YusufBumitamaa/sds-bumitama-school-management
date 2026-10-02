import { useMemo, useState } from 'react'
import {
  NavLink,
  Outlet,
  useLocation,
  useNavigate,
} from 'react-router-dom'
import { navigationItems } from '../config/navigation'
import type { NavigationItem } from '../types'
import { useAuth } from '../contexts/AuthContext'
import { usePermissions } from '../hooks/usePermissions'

function SidebarItem({
  item,
  isChild = false,
}: {
  item: NavigationItem
  isChild?: boolean
}) {
  const location = useLocation()

  const hasChildren = Boolean(item.children?.length)

  const isParentActive =
    location.pathname === item.path ||
    location.pathname.startsWith(`${item.path}/`)

  const [isOpen, setIsOpen] = useState(isParentActive)

  if (hasChildren) {
    return (
      <div>
        <button
          type="button"
          onClick={() => setIsOpen((current) => !current)}
          className={[
            'flex w-full items-center justify-between rounded-xl px-3 py-2.5 text-sm transition',
            isParentActive
              ? 'bg-emerald-50 font-medium text-emerald-700 dark:bg-emerald-500/10 dark:text-emerald-400'
              : 'text-slate-600 hover:bg-slate-50 hover:text-slate-900 dark:text-slate-400 dark:hover:bg-slate-800 dark:hover:text-slate-100',
            isChild ? 'pl-8' : '',
          ].join(' ')}
        >
          <span className="flex min-w-0 items-center gap-3">
            <span
              className={[
                'flex h-5 w-5 shrink-0 items-center justify-center text-xs',
                isParentActive
                  ? 'text-emerald-700 dark:text-emerald-400'
                  : 'text-slate-400',
              ].join(' ')}
            >
              {isChild ? '•' : '□'}
            </span>

            <span className="truncate">{item.label}</span>
          </span>

          <span
            className={[
              'ml-3 text-xs text-slate-400 transition-transform',
              isOpen ? 'rotate-90' : '',
            ].join(' ')}
          >
            ›
          </span>
        </button>

        {isOpen && (
          <div className="mt-1 space-y-1">
            {item.children?.map((child) => (
              <SidebarItem
                key={child.path}
                item={child}
                isChild
              />
            ))}
          </div>
        )}
      </div>
    )
  }

  return (
    <NavLink
      to={item.path}
      className={({ isActive }) =>
        [
          'flex items-center gap-3 rounded-xl px-3 py-2.5 text-sm transition',
          isActive
            ? 'bg-emerald-50 font-medium text-emerald-700 dark:bg-emerald-500/10 dark:text-emerald-400'
            : 'text-slate-600 hover:bg-slate-50 hover:text-slate-900 dark:text-slate-400 dark:hover:bg-slate-800 dark:hover:text-slate-100',
          isChild ? 'pl-8' : '',
        ].join(' ')
      }
    >
      {({ isActive }) => (
        <>
          <span
            className={[
              'flex h-5 w-5 shrink-0 items-center justify-center text-xs',
              isActive
                ? 'text-emerald-700 dark:text-emerald-400'
                : 'text-slate-400',
            ].join(' ')}
          >
            {isChild ? '•' : '□'}
          </span>

          <span className="truncate">{item.label}</span>
        </>
      )}
    </NavLink>
  )
}

function getInitials(fullName: string) {
  const nameParts = fullName
    .trim()
    .split(/\s+/)
    .filter(Boolean)

  if (nameParts.length === 0) {
    return 'U'
  }

  if (nameParts.length === 1) {
    return nameParts[0].slice(0, 2).toUpperCase()
  }

  return `${nameParts[0][0]}${
    nameParts[nameParts.length - 1][0]
  }`.toUpperCase()
}

function formatRole(role: string | undefined) {
  if (!role) {
    return 'Pengguna'
  }

  const roleLabels: Record<string, string> = {
    super_admin: 'Super Admin',
    admin: 'Admin / TU',
    kepala_sekolah: 'Kepala Sekolah',
    guru: 'Guru',
    bendahara: 'Bendahara',
  }

  return (
    roleLabels[role] ??
    role
      .replace(/\_/g, ' ')
      .replace(/\b\w/g, (character) =>
        character.toUpperCase(),
      )
  )
}

function AppLayout() {
  const navigate = useNavigate()
  const { profile, signOut } = useAuth()

  const {
    hasPermission,
    isLoading: isPermissionLoading,
  } = usePermissions()

  const [isSigningOut, setIsSigningOut] = useState(false)
  const [logoutError, setLogoutError] = useState('')

  const fullName = profile?.fullName || 'Pengguna'
  const primaryRole = profile?.roles?.[0]
  const roleLabel = formatRole(primaryRole)
  const initials = getInitials(fullName)

  const visibleNavigationItems = useMemo(() => {
    if (isPermissionLoading) {
      return []
    }

    return navigationItems.filter((item) => {
      if (!item.permission) {
        return true
      }

      return hasPermission(item.permission, 'view')
    })
  }, [hasPermission, isPermissionLoading])

  const handleSignOut = async () => {
    if (isSigningOut) {
      return
    }

    setLogoutError('')
    setIsSigningOut(true)

    try {
      await signOut()
      navigate('/login', { replace: true })
    } catch (error) {
      setLogoutError(
        error instanceof Error
          ? error.message
          : 'Gagal keluar dari sistem.',
      )
    } finally {
      setIsSigningOut(false)
    }
  }

  return (
    <div className="min-h-screen bg-slate-50 text-slate-900 dark:bg-slate-950 dark:text-slate-100">
      <div className="flex min-h-screen">
        <aside className="hidden w-72 shrink-0 border-r border-slate-200 bg-white lg:flex lg:flex-col dark:border-slate-800 dark:bg-slate-900">
          <div className="flex h-16 items-center border-b border-slate-100 px-5 dark:border-slate-800">
            <div className="flex items-center gap-3">
              <div className="flex h-9 w-9 items-center justify-center rounded-xl bg-emerald-50 text-sm font-semibold text-emerald-700 dark:bg-emerald-500/10 dark:text-emerald-400">
                S
              </div>

              <div>
                <p className="text-sm font-semibold text-slate-900 dark:text-slate-100">
                  SDS Bumitama
                </p>

                <p className="text-xs text-slate-500 dark:text-slate-400">
                  Administrasi Sekolah
                </p>
              </div>
            </div>
          </div>

          <nav className="flex-1 overflow-y-auto px-3 py-4">
            <p className="mb-2 px-3 text-[11px] font-semibold uppercase tracking-wider text-slate-400">
              Menu Utama
            </p>

            <div className="space-y-1">
              {visibleNavigationItems.map((item) => (
                <SidebarItem
                  key={item.path}
                  item={item}
                />
              ))}
            </div>
          </nav>

          <div className="border-t border-slate-100 p-4 dark:border-slate-800">
            <div className="rounded-xl bg-slate-50 p-3 dark:bg-slate-800">
              <p className="text-xs font-medium text-slate-700 dark:text-slate-200">
                Sistem Administrasi
              </p>

              <p className="mt-1 text-xs text-slate-500 dark:text-slate-400">
                SDS Bumitama
              </p>
            </div>
          </div>
        </aside>

        <div className="flex min-w-0 flex-1 flex-col">
          <header className="sticky top-0 z-20 flex h-16 items-center justify-between border-b border-slate-200 bg-white/90 px-4 backdrop-blur-md sm:px-6 dark:border-slate-800 dark:bg-slate-900/90">
            <div>
              <p className="text-xs font-medium text-slate-500 dark:text-slate-400">
                Sistem Administrasi Sekolah
              </p>

              <h1 className="text-sm font-semibold text-slate-900 sm:text-base dark:text-slate-100">
                SDS Bumitama
              </h1>
            </div>

            <div className="flex items-center gap-3">
              <button
                type="button"
                className="flex h-9 w-9 items-center justify-center rounded-xl border border-slate-200 text-sm text-slate-600 transition hover:bg-slate-50 dark:border-slate-700 dark:text-slate-300 dark:hover:bg-slate-800"
                aria-label="Notifikasi"
              >
                ♧
              </button>

              <div className="hidden items-center gap-2 sm:flex">
                <div className="flex h-9 w-9 items-center justify-center rounded-full bg-slate-100 text-xs font-semibold text-slate-600 dark:bg-slate-800 dark:text-slate-300">
                  {initials}
                </div>

                <div className="leading-tight">
                  <p className="max-w-40 truncate text-xs font-semibold text-slate-800 dark:text-slate-100">
                    {fullName}
                  </p>

                  <p className="text-[11px] text-slate-500 dark:text-slate-400">
                    {roleLabel}
                  </p>
                </div>

                <button
                  type="button"
                  onClick={handleSignOut}
                  disabled={isSigningOut}
                  className="ml-2 rounded-lg px-2.5 py-1.5 text-xs font-medium text-slate-500 transition hover:bg-slate-100 hover:text-slate-800 disabled:cursor-not-allowed disabled:opacity-50 dark:text-slate-400 dark:hover:bg-slate-800 dark:hover:text-slate-100"
                  title="Keluar"
                >
                  {isSigningOut ? 'Keluar...' : 'Keluar'}
                </button>
              </div>
            </div>
          </header>

          {logoutError && (
            <div className="border-b border-red-200 bg-red-50 px-4 py-3 sm:px-6 dark:border-red-900/50 dark:bg-red-950/30">
              <div className="mx-auto max-w-7xl">
                <p className="text-sm text-red-700 dark:text-red-300">
                  {logoutError}
                </p>
              </div>
            </div>
          )}

          <main className="flex-1 p-4 sm:p-6 lg:p-8">
            <div className="mx-auto max-w-7xl">
              <Outlet />
            </div>
          </main>
        </div>
      </div>
    </div>
  )
}

export default AppLayout