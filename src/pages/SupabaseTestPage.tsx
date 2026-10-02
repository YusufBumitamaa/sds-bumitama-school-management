import { useEffect, useState } from 'react'
import { supabase } from '../lib/supabase'

type CheckStatus = 'checking' | 'success' | 'error'

type TableCheck = {
  name: string
  description: string
  status: CheckStatus
  count: number | null
  message: string
}

function SupabaseTestPage() {
  const [connectionStatus, setConnectionStatus] =
    useState<CheckStatus>('checking')

  const [connectionMessage, setConnectionMessage] = useState(
    'Memeriksa koneksi ke Supabase...',
  )

  const [checks, setChecks] = useState<TableCheck[]>([
    {
      name: 'roles',
      description: 'Role pengguna sistem',
      status: 'checking',
      count: null,
      message: 'Memeriksa tabel...',
    },
    {
      name: 'permissions',
      description: 'Hak akses sistem',
      status: 'checking',
      count: null,
      message: 'Memeriksa tabel...',
    },
    {
      name: 'role_permissions',
      description: 'Relasi role dan hak akses',
      status: 'checking',
      count: null,
      message: 'Memeriksa tabel...',
    },
  ])

  useEffect(() => {
    let isMounted = true

    const checkDatabase = async () => {
      const tableNames = [
        'roles',
        'permissions',
        'role_permissions',
      ] as const

      try {
        const results = await Promise.all(
          tableNames.map(async (tableName) => {
            const { count, error } = await supabase
              .from(tableName)
              .select('id', { count: 'exact', head: true })

            if (error) {
              return {
                tableName,
                status: 'error' as const,
                count: null,
                message: error.message,
              }
            }

            return {
              tableName,
              status: 'success' as const,
              count: count ?? 0,
              message: 'Tabel dapat diakses.',
            }
          }),
        )

        if (!isMounted) {
          return
        }

        const hasError = results.some(
          (result) => result.status === 'error',
        )

        setConnectionStatus(
          hasError ? 'error' : 'success',
        )

        setConnectionMessage(
          hasError
            ? 'Supabase terhubung, tetapi terdapat tabel Identity & Security yang belum dapat diakses.'
            : 'Koneksi Supabase berhasil dan tabel Identity & Security dapat diakses.',
        )

        setChecks(
          results.map((result) => {
            const description =
              result.tableName === 'roles'
                ? 'Role pengguna sistem'
                : result.tableName === 'permissions'
                  ? 'Hak akses sistem'
                  : 'Relasi role dan hak akses'

            return {
              name: result.tableName,
              description,
              status: result.status,
              count: result.count,
              message: result.message,
            }
          }),
        )
      } catch (error) {
        if (!isMounted) {
          return
        }

        setConnectionStatus('error')

        setConnectionMessage(
          error instanceof Error
            ? error.message
            : 'Terjadi kesalahan saat menghubungkan ke Supabase.',
        )

        setChecks((currentChecks) =>
          currentChecks.map((check) => ({
            ...check,
            status: 'error',
            count: null,
            message: 'Pemeriksaan gagal.',
          })),
        )
      }
    }

    void checkDatabase()

    return () => {
      isMounted = false
    }
  }, [])

  const successCount = checks.filter(
    (check) => check.status === 'success',
  ).length

  const statusLabel =
    connectionStatus === 'checking'
      ? 'Memeriksa koneksi'
      : connectionStatus === 'success'
        ? 'Database siap'
        : 'Perlu diperiksa'

  const statusDescription =
    connectionStatus === 'checking'
      ? 'Sedang memeriksa struktur Identity & Security.'
      : connectionMessage

  const statusClasses =
    connectionStatus === 'success'
      ? 'border-emerald-200 bg-emerald-50 text-emerald-800 dark:border-emerald-900/60 dark:bg-emerald-950/30 dark:text-emerald-300'
      : connectionStatus === 'error'
        ? 'border-amber-200 bg-amber-50 text-amber-800 dark:border-amber-900/60 dark:bg-amber-950/30 dark:text-amber-300'
        : 'border-slate-200 bg-white text-slate-700 dark:border-slate-800 dark:bg-slate-900 dark:text-slate-200'

  const dotClasses =
    connectionStatus === 'success'
      ? 'bg-emerald-500'
      : connectionStatus === 'error'
        ? 'bg-amber-500'
        : 'bg-slate-400'

  return (
    <div className="min-h-[60vh]">
      <div className="mx-auto max-w-3xl">
        <div className="rounded-2xl border border-slate-200 bg-white p-6 shadow-sm dark:border-slate-800 dark:bg-slate-900 sm:p-8">
          <div className="mb-7">
            <div className="flex items-center gap-3">
              <div className="flex h-10 w-10 items-center justify-center rounded-xl bg-emerald-50 text-emerald-700 dark:bg-emerald-950/40 dark:text-emerald-400">
                <svg
                  viewBox="0 0 24 24"
                  fill="none"
                  stroke="currentColor"
                  strokeWidth="1.8"
                  className="h-5 w-5"
                  aria-hidden="true"
                >
                  <path
                    strokeLinecap="round"
                    strokeLinejoin="round"
                    d="M12 3v18M3 12h18"
                  />
                </svg>
              </div>

              <div>
                <p className="text-sm font-medium text-emerald-700 dark:text-emerald-400">
                  SDS Bumitama
                </p>

                <h1 className="text-2xl font-semibold tracking-tight text-slate-900 dark:text-white">
                  Verifikasi Database
                </h1>
              </div>
            </div>

            <p className="mt-4 max-w-2xl text-sm leading-6 text-slate-500 dark:text-slate-400">
              Halaman sementara untuk memastikan migration
              Identity & Security berhasil diterapkan dan dapat
              diakses oleh aplikasi.
            </p>
          </div>

          <div
            className={[
              'rounded-xl border p-4',
              statusClasses,
            ].join(' ')}
          >
            <div className="flex items-start gap-3">
              <span
                className={[
                  'mt-1.5 h-2.5 w-2.5 shrink-0 rounded-full',
                  dotClasses,
                ].join(' ')}
              />

              <div className="min-w-0">
                <p className="text-sm font-semibold">
                  {statusLabel}
                </p>

                <p className="mt-1 text-sm leading-6">
                  {statusDescription}
                </p>
              </div>
            </div>
          </div>

          <div className="mt-6 grid grid-cols-1 gap-3 sm:grid-cols-3">
            <div className="rounded-xl border border-slate-200 bg-slate-50 p-4 dark:border-slate-800 dark:bg-slate-950/50">
              <p className="text-xs font-medium uppercase tracking-wider text-slate-400">
                Pemeriksaan
              </p>

              <p className="mt-2 text-2xl font-semibold text-slate-900 dark:text-white">
                {checks.length}
              </p>

              <p className="mt-1 text-xs text-slate-500 dark:text-slate-400">
                tabel Identity & Security
              </p>
            </div>

            <div className="rounded-xl border border-slate-200 bg-slate-50 p-4 dark:border-slate-800 dark:bg-slate-950/50">
              <p className="text-xs font-medium uppercase tracking-wider text-slate-400">
                Berhasil
              </p>

              <p className="mt-2 text-2xl font-semibold text-slate-900 dark:text-white">
                {successCount}
              </p>

              <p className="mt-1 text-xs text-slate-500 dark:text-slate-400">
                tabel dapat diakses
              </p>
            </div>

            <div className="rounded-xl border border-slate-200 bg-slate-50 p-4 dark:border-slate-800 dark:bg-slate-950/50">
              <p className="text-xs font-medium uppercase tracking-wider text-slate-400">
                Migration
              </p>

              <p className="mt-2 text-lg font-semibold text-slate-900 dark:text-white">
                001
              </p>

              <p className="mt-1 text-xs text-slate-500 dark:text-slate-400">
                Identity & Security
              </p>
            </div>
          </div>

          <div className="mt-6 overflow-hidden rounded-xl border border-slate-200 dark:border-slate-800">
            <div className="border-b border-slate-200 bg-slate-50 px-4 py-3 dark:border-slate-800 dark:bg-slate-950/50">
              <p className="text-sm font-semibold text-slate-900 dark:text-white">
                Pemeriksaan Struktur Database
              </p>
            </div>

            <div className="divide-y divide-slate-200 dark:divide-slate-800">
              {checks.map((check) => (
                <div
                  key={check.name}
                  className="flex flex-col gap-3 px-4 py-4 sm:flex-row sm:items-center sm:justify-between"
                >
                  <div className="flex min-w-0 items-start gap-3">
                    <div
                      className={[
                        'mt-0.5 flex h-8 w-8 shrink-0 items-center justify-center rounded-lg',
                        check.status === 'success'
                          ? 'bg-emerald-50 text-emerald-600 dark:bg-emerald-950/40 dark:text-emerald-400'
                          : check.status === 'error'
                            ? 'bg-amber-50 text-amber-600 dark:bg-amber-950/40 dark:text-amber-400'
                            : 'bg-slate-100 text-slate-500 dark:bg-slate-800 dark:text-slate-400',
                      ].join(' ')}
                    >
                      {check.status === 'success' ? (
                        <svg
                          viewBox="0 0 24 24"
                          fill="none"
                          stroke="currentColor"
                          strokeWidth="2"
                          className="h-4 w-4"
                          aria-hidden="true"
                        >
                          <path
                            strokeLinecap="round"
                            strokeLinejoin="round"
                            d="m5 12 4 4L19 6"
                          />
                        </svg>
                      ) : check.status === 'error' ? (
                        <svg
                          viewBox="0 0 24 24"
                          fill="none"
                          stroke="currentColor"
                          strokeWidth="2"
                          className="h-4 w-4"
                          aria-hidden="true"
                        >
                          <path
                            strokeLinecap="round"
                            strokeLinejoin="round"
                            d="M12 9v4m0 4h.01M10.3 3.6 2.9 18a2 2 0 0 0 1.8 3h14.6a2 2 0 0 0 1.8-3L13.7 3.6a2 2 0 0 0-3.4 0Z"
                          />
                        </svg>
                      ) : (
                        <span className="h-2 w-2 rounded-full bg-slate-400" />
                      )}
                    </div>

                    <div className="min-w-0">
                      <p className="text-sm font-semibold text-slate-900 dark:text-white">
                        {check.name}
                      </p>

                      <p className="mt-0.5 text-xs text-slate-500 dark:text-slate-400">
                        {check.description}
                      </p>

                      <p className="mt-1 break-words text-xs text-slate-400 dark:text-slate-500">
                        {check.message}
                      </p>
                    </div>
                  </div>

                  <div className="shrink-0 pl-11 sm:pl-0 sm:text-right">
                    <p className="text-xs font-medium uppercase tracking-wider text-slate-400">
                      Record
                    </p>

                    <p className="mt-1 text-lg font-semibold text-slate-900 dark:text-white">
                      {check.count === null
                        ? '—'
                        : check.count}
                    </p>
                  </div>
                </div>
              ))}
            </div>
          </div>

          <div className="mt-6 rounded-xl border border-slate-200 bg-slate-50 p-4 dark:border-slate-800 dark:bg-slate-950/50">
            <p className="text-xs font-medium uppercase tracking-wider text-slate-400">
              Supabase Project
            </p>

            <p className="mt-2 break-all font-mono text-xs leading-5 text-slate-600 dark:text-slate-400">
              {import.meta.env.VITE_SUPABASE_URL}
            </p>
          </div>

          <div className="mt-6 flex items-start gap-3 rounded-xl border border-slate-200 p-4 dark:border-slate-800">
            <svg
              viewBox="0 0 24 24"
              fill="none"
              stroke="currentColor"
              strokeWidth="1.8"
              className="mt-0.5 h-5 w-5 shrink-0 text-slate-400"
              aria-hidden="true"
            >
              <circle cx="12" cy="12" r="9" />
              <path
                strokeLinecap="round"
                d="M12 10v6m0-9h.01"
              />
            </svg>

            <p className="text-xs leading-5 text-slate-500 dark:text-slate-400">
              Halaman ini hanya digunakan untuk verifikasi
              sementara selama tahap pembangunan aplikasi. Setelah
              seluruh database siap, halaman ini dapat dihapus dari
              menu aplikasi.
            </p>
          </div>
        </div>
      </div>
    </div>
  )
}

export default SupabaseTestPage