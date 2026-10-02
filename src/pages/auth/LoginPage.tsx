import { useState } from 'react'
import type { FormEvent } from 'react'
import { useNavigate } from 'react-router-dom'
import { supabase } from '../../lib/supabase'

function LoginPage() {
  const navigate = useNavigate()

  const [email, setEmail] = useState('')
  const [password, setPassword] = useState('')
  const [showPassword, setShowPassword] = useState(false)
  const [isLoading, setIsLoading] = useState(false)
  const [errorMessage, setErrorMessage] = useState('')

  const handleSubmit = async (event: FormEvent<HTMLFormElement>) => {
    event.preventDefault()

    setErrorMessage('')

    if (!email.trim() || !password) {
      setErrorMessage('Email dan password wajib diisi.')
      return
    }

    setIsLoading(true)

    try {
      const { data, error } = await supabase.auth.signInWithPassword({
        email: email.trim().toLowerCase(),
        password,
      })

      if (error) {
        setErrorMessage(
          error.message === 'Invalid login credentials'
            ? 'Email atau password tidak sesuai.'
            : error.message,
        )
        return
      }

      if (!data.user) {
        setErrorMessage(
          'Login gagal. Data pengguna tidak ditemukan.',
        )
        return
      }

      navigate('/', { replace: true })
    } catch (error) {
      setErrorMessage(
        error instanceof Error
          ? error.message
          : 'Terjadi kesalahan saat proses login.',
      )
    } finally {
      setIsLoading(false)
    }
  }

  return (
    <main className="min-h-screen bg-slate-50 text-slate-900 dark:bg-slate-950 dark:text-slate-100">
      <div className="grid min-h-screen lg:grid-cols-[minmax(0,1fr)_minmax(420px,520px)]">
        <section className="relative hidden overflow-hidden bg-slate-900 lg:flex">
          <div className="absolute inset-0 bg-[radial-gradient(circle_at_20%_20%,rgba(16,185,129,0.12),transparent_32%),radial-gradient(circle_at_80%_80%,rgba(148,163,184,0.10),transparent_30%)]" />

          <div className="relative flex w-full flex-col justify-between p-10 xl:p-14">
            <div>
              <div className="flex items-center gap-3">
                <div className="flex h-11 w-11 items-center justify-center rounded-2xl border border-white/10 bg-white/10 text-emerald-400">
                  <span className="text-lg font-semibold">
                    SB
                  </span>
                </div>

                <div>
                  <p className="text-sm font-semibold text-white">
                    SDS Bumitama
                  </p>

                  <p className="text-xs text-slate-400">
                    Sistem Administrasi Sekolah
                  </p>
                </div>
              </div>
            </div>

            <div className="max-w-xl">
              <p className="mb-4 text-sm font-medium text-emerald-400">
                School Management System
              </p>

              <h1 className="text-4xl font-semibold tracking-tight text-white xl:text-5xl">
                Administrasi sekolah yang terintegrasi.
              </h1>

              <p className="mt-6 max-w-lg text-base leading-7 text-slate-400">
                Kelola data sekolah, kesiswaan, akademik,
                pendidik, sarana prasarana, keuangan, persuratan,
                dan laporan dalam satu sistem.
              </p>
            </div>

            <p className="text-xs text-slate-500">
              SDS Bumitama · Sistem Administrasi Sekolah
            </p>
          </div>
        </section>

        <section className="flex min-h-screen items-center justify-center px-5 py-10 sm:px-8">
          <div className="w-full max-w-md">
            <div className="mb-8 lg:hidden">
              <div className="flex items-center gap-3">
                <div className="flex h-11 w-11 items-center justify-center rounded-2xl bg-emerald-50 text-emerald-700 dark:bg-emerald-500/10 dark:text-emerald-400">
                  <span className="text-lg font-semibold">
                    SB
                  </span>
                </div>

                <div>
                  <p className="text-sm font-semibold">
                    SDS Bumitama
                  </p>

                  <p className="text-xs text-slate-500 dark:text-slate-400">
                    Sistem Administrasi Sekolah
                  </p>
                </div>
              </div>
            </div>

            <div className="rounded-3xl border border-slate-200 bg-white p-6 shadow-sm sm:p-8 dark:border-slate-800 dark:bg-slate-900">
              <div className="mb-8">
                <p className="text-sm font-medium text-emerald-700 dark:text-emerald-400">
                  Selamat datang
                </p>

                <h2 className="mt-2 text-2xl font-semibold tracking-tight">
                  Masuk ke akun Anda
                </h2>

                <p className="mt-2 text-sm leading-6 text-slate-500 dark:text-slate-400">
                  Gunakan akun yang telah terdaftar untuk
                  mengakses sistem administrasi sekolah.
                </p>
              </div>

              <form
                onSubmit={handleSubmit}
                className="space-y-5"
              >
                <div>
                  <label
                    htmlFor="email"
                    className="mb-2 block text-sm font-medium"
                  >
                    Email
                  </label>

                  <input
                    id="email"
                    type="email"
                    autoComplete="email"
                    value={email}
                    onChange={(event) =>
                      setEmail(event.target.value)
                    }
                    placeholder="nama@sekolah.id"
                    disabled={isLoading}
                    className="w-full rounded-xl border border-slate-200 bg-white px-4 py-3 text-sm outline-none transition placeholder:text-slate-400 focus:border-emerald-500 focus:ring-4 focus:ring-emerald-500/10 disabled:cursor-not-allowed disabled:opacity-60 dark:border-slate-700 dark:bg-slate-950 dark:placeholder:text-slate-600"
                  />
                </div>

                <div>
                  <label
                    htmlFor="password"
                    className="mb-2 block text-sm font-medium"
                  >
                    Password
                  </label>

                  <div className="relative">
                    <input
                      id="password"
                      type={
                        showPassword
                          ? 'text'
                          : 'password'
                      }
                      autoComplete="current-password"
                      value={password}
                      onChange={(event) =>
                        setPassword(event.target.value)
                      }
                      placeholder="Masukkan password"
                      disabled={isLoading}
                      className="w-full rounded-xl border border-slate-200 bg-white px-4 py-3 pr-20 text-sm outline-none transition placeholder:text-slate-400 focus:border-emerald-500 focus:ring-4 focus:ring-emerald-500/10 disabled:cursor-not-allowed disabled:opacity-60 dark:border-slate-700 dark:bg-slate-950 dark:placeholder:text-slate-600"
                    />

                    <button
                      type="button"
                      onClick={() =>
                        setShowPassword((current) => !current)
                      }
                      disabled={isLoading}
                      className="absolute right-3 top-1/2 -translate-y-1/2 rounded-lg px-2 py-1 text-xs font-medium text-slate-500 transition hover:bg-slate-100 hover:text-slate-700 disabled:cursor-not-allowed dark:text-slate-400 dark:hover:bg-slate-800 dark:hover:text-slate-200"
                    >
                      {showPassword
                        ? 'Sembunyikan'
                        : 'Tampilkan'}
                    </button>
                  </div>
                </div>

                {errorMessage && (
                  <div
                    role="alert"
                    className="rounded-xl border border-red-200 bg-red-50 px-4 py-3 text-sm leading-6 text-red-700 dark:border-red-900/50 dark:bg-red-950/30 dark:text-red-300"
                  >
                    {errorMessage}
                  </div>
                )}

                <button
                  type="submit"
                  disabled={isLoading}
                  className="flex w-full items-center justify-center rounded-xl bg-slate-900 px-4 py-3 text-sm font-semibold text-white shadow-sm transition hover:bg-slate-800 disabled:cursor-not-allowed disabled:opacity-60 dark:bg-white dark:text-slate-900 dark:hover:bg-slate-100"
                >
                  {isLoading ? (
                    <>
                      <span className="mr-2 h-4 w-4 animate-spin rounded-full border-2 border-current border-t-transparent" />
                      Memproses...
                    </>
                  ) : (
                    'Masuk'
                  )}
                </button>
              </form>

              <div className="mt-8 border-t border-slate-100 pt-5 dark:border-slate-800">
                <p className="text-center text-xs leading-5 text-slate-400">
                  Akses sistem diberikan sesuai hak akses dan
                  peran pengguna.
                </p>
              </div>
            </div>

            <p className="mt-6 text-center text-xs text-slate-400">
              © {new Date().getFullYear()} SDS Bumitama
            </p>
          </div>
        </section>
      </div>
    </main>
  )
}

export default LoginPage