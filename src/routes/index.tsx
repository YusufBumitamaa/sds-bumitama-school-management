import {
  useEffect,
  useState,
} from 'react'
import type { ReactNode } from 'react'
import type { Session } from '@supabase/supabase-js'
import {
  Navigate,
  Route,
  Routes,
  useLocation,
} from 'react-router-dom'
import AppLayout from '../layouts/AppLayout'
import { useAuth } from '../contexts/AuthContext'
import { usePermissions } from '../hooks/usePermissions'
import { supabase } from '../lib/supabase'
import LoginPage from '../pages/auth/LoginPage'
import UsersPage from '../pages/settings/UsersPage'

function PlaceholderPage({
  title,
}: {
  title: string
}) {
  return (
    <div className="min-h-full bg-slate-50 px-4 py-6 dark:bg-slate-950 sm:px-6 lg:px-8">
      <div className="mx-auto max-w-7xl">
        <div className="rounded-2xl border border-slate-200 bg-white p-6 shadow-sm dark:border-slate-800 dark:bg-slate-900">
          <h1 className="text-xl font-semibold text-slate-950 dark:text-white">
            {title}
          </h1>

          <p className="mt-2 text-sm text-slate-500 dark:text-slate-400">
            Halaman ini sedang dalam tahap
            pengembangan.
          </p>
        </div>
      </div>
    </div>
  )
}

function AccessDeniedPage() {
  const location = useLocation()

  return (
    <div className="flex min-h-screen items-center justify-center bg-slate-50 px-4 dark:bg-slate-950">
      <div className="w-full max-w-md rounded-2xl border border-slate-200 bg-white p-8 text-center shadow-sm dark:border-slate-800 dark:bg-slate-900">
        <div className="mx-auto flex h-14 w-14 items-center justify-center rounded-2xl bg-red-50 text-red-600 dark:bg-red-950/30 dark:text-red-400">
          <span className="text-xl font-bold">
            403
          </span>
        </div>

        <h1 className="mt-5 text-xl font-semibold text-slate-950 dark:text-white">
          Akses Ditolak
        </h1>

        <p className="mt-2 text-sm leading-6 text-slate-500 dark:text-slate-400">
          Anda tidak memiliki hak akses
          untuk membuka halaman ini.
        </p>

        <p className="mt-3 break-all text-xs text-slate-400 dark:text-slate-500">
          {location.pathname}
        </p>

        <button
          type="button"
          onClick={() =>
            window.history.back()
          }
          className="mt-6 inline-flex h-10 items-center justify-center rounded-xl bg-slate-900 px-4 text-sm font-semibold text-white transition hover:bg-slate-800 dark:bg-white dark:text-slate-900 dark:hover:bg-slate-200"
        >
          Kembali
        </button>
      </div>
    </div>
  )
}

function AuthLoadingScreen() {
  return (
    <div className="flex min-h-screen items-center justify-center bg-slate-50 dark:bg-slate-950">
      <div className="flex flex-col items-center gap-4">
        <div className="h-8 w-8 animate-spin rounded-full border-2 border-slate-200 border-t-emerald-600 dark:border-slate-700 dark:border-t-emerald-400" />

        <p className="text-sm text-slate-500 dark:text-slate-400">
          Memeriksa autentikasi...
        </p>
      </div>
    </div>
  )
}

function ProtectedRoutes({
  children,
}: {
  children: ReactNode
}) {
  const [session, setSession] =
    useState<Session | null>(null)

  const [isLoading, setIsLoading] =
    useState(true)

  useEffect(() => {
    let isMounted = true

    const loadSession = async () => {
      try {
        const {
          data,
          error,
        } = await supabase.auth.getSession()

        if (error) {
          throw error
        }

        if (!isMounted) {
          return
        }

        setSession(data.session)
      } catch (error) {
        console.error(
          'Gagal memeriksa session:',
          error,
        )

        if (isMounted) {
          setSession(null)
        }
      } finally {
        if (isMounted) {
          setIsLoading(false)
        }
      }
    }

    void loadSession()

    const {
      data: { subscription },
    } = supabase.auth.onAuthStateChange(
      (_event, nextSession) => {
        if (!isMounted) {
          return
        }

        setSession(nextSession)
        setIsLoading(false)
      },
    )

    return () => {
      isMounted = false
      subscription.unsubscribe()
    }
  }, [])

  if (isLoading) {
    return <AuthLoadingScreen />
  }

  if (!session) {
    return (
      <Navigate
        to="/login"
        replace
      />
    )
  }

  return <>{children}</>
}

function PublicLoginRoute() {
  const [session, setSession] =
    useState<Session | null>(null)

  const [isLoading, setIsLoading] =
    useState(true)

  useEffect(() => {
    let isMounted = true

    const loadSession = async () => {
      try {
        const {
          data,
          error,
        } = await supabase.auth.getSession()

        if (error) {
          throw error
        }

        if (!isMounted) {
          return
        }

        setSession(data.session)
      } catch (error) {
        console.error(
          'Gagal memeriksa session login:',
          error,
        )

        if (isMounted) {
          setSession(null)
        }
      } finally {
        if (isMounted) {
          setIsLoading(false)
        }
      }
    }

    void loadSession()

    const {
      data: { subscription },
    } = supabase.auth.onAuthStateChange(
      (_event, nextSession) => {
        if (!isMounted) {
          return
        }

        setSession(nextSession)
        setIsLoading(false)
      },
    )

    return () => {
      isMounted = false
      subscription.unsubscribe()
    }
  }, [])

  if (isLoading) {
    return <AuthLoadingScreen />
  }

  if (session) {
    return (
      <Navigate
        to="/dashboard"
        replace
      />
    )
  }

  return <LoginPage />
}

function getPermissionModule(
  pathname: string,
) {
  if (
    pathname === '/supabase-test' ||
    pathname.startsWith(
      '/supabase-test/',
    )
  ) {
    return null
  }

  const segments = pathname
    .split('/')
    .filter(Boolean)

  if (segments.length === 0) {
    return 'dashboard'
  }

  const firstSegment =
    segments[0]

  const moduleMap: Record<
    string,
    string
  > = {
    dashboard: 'dashboard',
    'profil-sekolah':
      'profil_sekolah',
    kesiswaan: 'kesiswaan',
    kurikulum: 'kurikulum',
    akademik: 'akademik',
    gtk: 'gtk',
    sarpras: 'sarpras',
    keuangan: 'keuangan',
    persuratan: 'persuratan',
    laporan: 'laporan',
    pengguna: 'pengguna',
    pengaturan: 'pengaturan',
  }

  return (
    moduleMap[firstSegment] ??
    null
  )
}

function PermissionGuard({
  children,
}: {
  children: ReactNode
}) {
  const location = useLocation()
  const { profile } = useAuth()

  const {
    isLoading,
    hasPermission,
  } = usePermissions()

  const permissionModule =
    getPermissionModule(
      location.pathname,
    )

  if (
    location.pathname ===
      '/supabase-test' ||
    location.pathname.startsWith(
      '/supabase-test/',
    )
  ) {
    return <>{children}</>
  }

  if (!profile) {
    if (isLoading) {
      return <AuthLoadingScreen />
    }

    return <AccessDeniedPage />
  }

  if (!permissionModule) {
    return <AccessDeniedPage />
  }

  if (isLoading) {
    return <AuthLoadingScreen />
  }

  if (
    !hasPermission(
      permissionModule,
      'view',
    )
  ) {
    return <AccessDeniedPage />
  }

  return <>{children}</>
}

export function AppRoutes() {
  return (
    <Routes>
      {/* Public */}
      <Route
        path="/login"
        element={
          <PublicLoginRoute />
        }
      />

      {/* Protected application */}
      <Route
        element={
          <ProtectedRoutes>
            <PermissionGuard>
              <AppLayout />
            </PermissionGuard>
          </ProtectedRoutes>
        }
      >
        <Route
          path="/"
          element={
            <Navigate
              to="/dashboard"
              replace
            />
          }
        />

        {/* Dashboard */}
        <Route
          path="/dashboard"
          element={
            <PlaceholderPage
              title="Dashboard"
            />
          }
        />

        {/* Profil Sekolah */}
        <Route
          path="/profil-sekolah"
          element={
            <PlaceholderPage
              title="Profil Sekolah"
            />
          }
        />

        {/* Kesiswaan */}
        <Route
          path="/kesiswaan/siswa"
          element={
            <PlaceholderPage
              title="Data Siswa"
            />
          }
        />

        <Route
          path="/kesiswaan/orang-tua-wali"
          element={
            <PlaceholderPage
              title="Orang Tua/Wali"
            />
          }
        />

        <Route
          path="/kesiswaan/ppdb"
          element={
            <PlaceholderPage
              title="PPDB"
            />
          }
        />

        <Route
          path="/kesiswaan/mutasi"
          element={
            <PlaceholderPage
              title="Mutasi Siswa"
            />
          }
        />

        <Route
          path="/kesiswaan/prestasi"
          element={
            <PlaceholderPage
              title="Prestasi Siswa"
            />
          }
        />

        <Route
          path="/kesiswaan/pelanggaran"
          element={
            <PlaceholderPage
              title="Pelanggaran Siswa"
            />
          }
        />

        <Route
          path="/kesiswaan/kegiatan"
          element={
            <PlaceholderPage
              title="Kegiatan Kesiswaan"
            />
          }
        />

        <Route
          path="/kesiswaan/alumni"
          element={
            <PlaceholderPage
              title="Alumni"
            />
          }
        />

        {/* Kurikulum */}
        <Route
          path="/kurikulum/tahun-ajaran"
          element={
            <PlaceholderPage
              title="Tahun Ajaran"
            />
          }
        />

        <Route
          path="/kurikulum/struktur"
          element={
            <PlaceholderPage
              title="Struktur Kurikulum"
            />
          }
        />

        <Route
          path="/kurikulum/mata-pelajaran"
          element={
            <PlaceholderPage
              title="Mata Pelajaran"
            />
          }
        />

        <Route
          path="/kurikulum/jadwal"
          element={
            <PlaceholderPage
              title="Jadwal Pelajaran"
            />
          }
        />

        <Route
          path="/kurikulum/kalender"
          element={
            <PlaceholderPage
              title="Kalender Pendidikan"
            />
          }
        />

        <Route
          path="/kurikulum/perangkat"
          element={
            <PlaceholderPage
              title="Perangkat Pembelajaran"
            />
          }
        />

        <Route
          path="/kurikulum/evaluasi"
          element={
            <PlaceholderPage
              title="Evaluasi Kurikulum"
            />
          }
        />

        {/* Akademik */}
        <Route
          path="/akademik/rombel"
          element={
            <PlaceholderPage
              title="Rombongan Belajar"
            />
          }
        />

        <Route
          path="/akademik/wali-kelas"
          element={
            <PlaceholderPage
              title="Wali Kelas"
            />
          }
        />

        <Route
          path="/akademik/absensi"
          element={
            <PlaceholderPage
              title="Absensi"
            />
          }
        />

        <Route
          path="/akademik/penilaian"
          element={
            <PlaceholderPage
              title="Penilaian"
            />
          }
        />

        <Route
          path="/akademik/rapor"
          element={
            <PlaceholderPage
              title="Rapor"
            />
          }
        />

        <Route
          path="/akademik/kenaikan-kelas"
          element={
            <PlaceholderPage
              title="Kenaikan Kelas"
            />
          }
        />

        <Route
          path="/akademik/kelulusan"
          element={
            <PlaceholderPage
              title="Kelulusan"
            />
          }
        />

        {/* GTK */}
        <Route
          path="/gtk/guru"
          element={
            <PlaceholderPage
              title="Data Guru"
            />
          }
        />

        <Route
          path="/gtk/tendik"
          element={
            <PlaceholderPage
              title="Data Tendik"
            />
          }
        />

        <Route
          path="/gtk/pendidikan"
          element={
            <PlaceholderPage
              title="Pendidikan GTK"
            />
          }
        />

        <Route
          path="/gtk/sertifikasi"
          element={
            <PlaceholderPage
              title="Sertifikasi"
            />
          }
        />

        <Route
          path="/gtk/tugas-tambahan"
          element={
            <PlaceholderPage
              title="Tugas Tambahan"
            />
          }
        />

        <Route
          path="/gtk/kehadiran"
          element={
            <PlaceholderPage
              title="Kehadiran GTK"
            />
          }
        />

        {/* Sarpras */}
        <Route
          path="/sarpras/ruangan"
          element={
            <PlaceholderPage
              title="Ruangan"
            />
          }
        />

        <Route
          path="/sarpras/inventaris"
          element={
            <PlaceholderPage
              title="Inventaris"
            />
          }
        />

        <Route
          path="/sarpras/kondisi"
          element={
            <PlaceholderPage
              title="Kondisi Sarpras"
            />
          }
        />

        <Route
          path="/sarpras/pengadaan"
          element={
            <PlaceholderPage
              title="Pengadaan Sarpras"
            />
          }
        />

        <Route
          path="/sarpras/pemeliharaan"
          element={
            <PlaceholderPage
              title="Pemeliharaan"
            />
          }
        />

        <Route
          path="/sarpras/penghapusan-aset"
          element={
            <PlaceholderPage
              title="Penghapusan Aset"
            />
          }
        />

        {/* Keuangan */}
        <Route
          path="/keuangan/dashboard"
          element={
            <PlaceholderPage
              title="Dashboard Keuangan"
            />
          }
        />

        <Route
          path="/keuangan/anggaran"
          element={
            <PlaceholderPage
              title="Anggaran"
            />
          }
        />

        <Route
          path="/keuangan/pemasukan"
          element={
            <PlaceholderPage
              title="Pemasukan"
            />
          }
        />

        <Route
          path="/keuangan/pengeluaran"
          element={
            <PlaceholderPage
              title="Pengeluaran"
            />
          }
        />

        <Route
          path="/keuangan/kas"
          element={
            <PlaceholderPage
              title="Kas"
            />
          }
        />

        <Route
          path="/keuangan/pengadaan"
          element={
            <PlaceholderPage
              title="Pengadaan Keuangan"
            />
          }
        />

        <Route
          path="/keuangan/bukti-transaksi"
          element={
            <PlaceholderPage
              title="Bukti Transaksi"
            />
          }
        />

        <Route
          path="/keuangan/laporan"
          element={
            <PlaceholderPage
              title="Laporan Keuangan"
            />
          }
        />

        {/* Persuratan */}
        <Route
          path="/persuratan/surat-masuk"
          element={
            <PlaceholderPage
              title="Surat Masuk"
            />
          }
        />

        <Route
          path="/persuratan/surat-keluar"
          element={
            <PlaceholderPage
              title="Surat Keluar"
            />
          }
        />

        <Route
          path="/persuratan/sk"
          element={
            <PlaceholderPage
              title="SK"
            />
          }
        />

        <Route
          path="/persuratan/dokumen-sekolah"
          element={
            <PlaceholderPage
              title="Dokumen Sekolah"
            />
          }
        />

        <Route
          path="/persuratan/arsip-digital"
          element={
            <PlaceholderPage
              title="Arsip Digital"
            />
          }
        />

        {/* Laporan */}
        <Route
          path="/laporan"
          element={
            <PlaceholderPage
              title="Laporan"
            />
          }
        />

        {/* Pengguna & Hak Akses */}
        <Route
          path="/pengguna"
          element={<UsersPage />}
        />

        {/* Pengaturan */}
        <Route
          path="/pengaturan"
          element={
            <PlaceholderPage
              title="Pengaturan"
            />
          }
        />

        {/* Development */}
        <Route
          path="/supabase-test"
          element={
            <PlaceholderPage
              title="Supabase Test"
            />
          }
        />

        {/* Fallback */}
        <Route
          path="*"
          element={
            <Navigate
              to="/dashboard"
              replace
            />
          }
        />
      </Route>
    </Routes>
  )
}