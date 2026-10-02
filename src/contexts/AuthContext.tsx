import {
  createContext,
  useContext,
  useEffect,
  useMemo,
  useState,
} from 'react'
import type { ReactNode } from 'react'
import type {
  Session,
  User as SupabaseUser,
} from '@supabase/supabase-js'
import { supabase } from '../lib/supabase'

export type AppRole =
  | 'super_admin'
  | 'admin'
  | 'kepala_sekolah'
  | 'guru'
  | 'bendahara'

export interface AuthUserProfile {
  id: string
  email: string
  fullName: string
  isActive: boolean
  createdAt: string
  updatedAt: string
  roles: AppRole[]
}

interface AuthContextValue {
  session: Session | null
  authUser: SupabaseUser | null
  profile: AuthUserProfile | null
  isLoading: boolean
  refreshProfile: () => Promise<void>
  signOut: () => Promise<void>
}

const AUTH_ROLES: AppRole[] = [
  'super_admin',
  'admin',
  'kepala_sekolah',
  'guru',
  'bendahara',
]

const AuthContext = createContext<
  AuthContextValue | undefined
>(undefined)

function isAppRole(value: string): value is AppRole {
  return AUTH_ROLES.includes(value as AppRole)
}

function getRolePriority(role: AppRole) {
  const priorities: Record<AppRole, number> = {
    super_admin: 1,
    admin: 2,
    kepala_sekolah: 3,
    bendahara: 4,
    guru: 5,
  }

  return priorities[role]
}

async function loadUserProfile(
  authUser: SupabaseUser,
): Promise<AuthUserProfile | null> {
  const {
    data: userProfile,
    error: userProfileError,
  } = await supabase
    .from('users')
    .select(
      'id, email, full_name, is_active, created_at, updated_at',
    )
    .eq('id', authUser.id)
    .maybeSingle()

  if (userProfileError) {
    throw userProfileError
  }

  if (!userProfile) {
    return null
  }

  const {
    data: userRoles,
    error: userRolesError,
  } = await supabase
    .from('user_roles')
    .select('role_id')
    .eq('user_id', authUser.id)

  if (userRolesError) {
    throw userRolesError
  }

  let roles: AppRole[] = []

  if (userRoles && userRoles.length > 0) {
    const roleIds = userRoles.map(
      (userRole) => userRole.role_id,
    )

    const {
      data: roleRecords,
      error: rolesError,
    } = await supabase
      .from('roles')
      .select('id, code')
      .in('id', roleIds)

    if (rolesError) {
      throw rolesError
    }

    roles =
      roleRecords
        ?.map((role) => role.code)
        .filter(
          (role): role is AppRole =>
            typeof role === 'string' &&
            isAppRole(role),
        )
        .sort(
          (first, second) =>
            getRolePriority(first) -
            getRolePriority(second),
        ) ?? []
  }

  return {
    id: userProfile.id,
    email: userProfile.email,
    fullName: userProfile.full_name,
    isActive: userProfile.is_active,
    createdAt: userProfile.created_at,
    updatedAt: userProfile.updated_at,
    roles,
  }
}

export function AuthProvider({
  children,
}: {
  children: ReactNode
}) {
  const [session, setSession] =
    useState<Session | null>(null)

  const [authUser, setAuthUser] =
    useState<SupabaseUser | null>(null)

  const [profile, setProfile] =
    useState<AuthUserProfile | null>(null)

  const [isLoading, setIsLoading] =
    useState(true)

  const refreshProfile = async () => {
    if (!authUser) {
      setProfile(null)
      return
    }

    try {
      const nextProfile =
        await loadUserProfile(authUser)

      if (!nextProfile) {
        await supabase.auth.signOut()

        setSession(null)
        setAuthUser(null)
        setProfile(null)

        return
      }

      if (!nextProfile.isActive) {
        console.warn(
          'Akun pengguna sedang nonaktif. Session akan diakhiri.',
        )

        await supabase.auth.signOut()

        setSession(null)
        setAuthUser(null)
        setProfile(null)

        return
      }

      setProfile(nextProfile)
    } catch (error) {
      console.error(
        'Gagal mengambil profil pengguna:',
        error,
      )

      setProfile(null)
    }
  }

  useEffect(() => {
    let isMounted = true

    const initializeAuth = async () => {
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

        const currentSession = data.session

        if (!currentSession?.user) {
          setSession(null)
          setAuthUser(null)
          setProfile(null)

          return
        }

        try {
          const nextProfile =
            await loadUserProfile(
              currentSession.user,
            )

          if (!isMounted) {
            return
          }

          if (!nextProfile) {
            await supabase.auth.signOut()

            if (isMounted) {
              setSession(null)
              setAuthUser(null)
              setProfile(null)
            }

            return
          }

          if (!nextProfile.isActive) {
            console.warn(
              'Akun pengguna sedang nonaktif. Session akan diakhiri.',
            )

            await supabase.auth.signOut()

            if (isMounted) {
              setSession(null)
              setAuthUser(null)
              setProfile(null)
            }

            return
          }

          setSession(currentSession)
          setAuthUser(currentSession.user)
          setProfile(nextProfile)
        } catch (profileError) {
          console.error(
            'Gagal mengambil profil pengguna:',
            profileError,
          )

          if (isMounted) {
            setSession(null)
            setAuthUser(null)
            setProfile(null)
          }
        }
      } catch (error) {
        console.error(
          'Gagal menginisialisasi autentikasi:',
          error,
        )

        if (isMounted) {
          setSession(null)
          setAuthUser(null)
          setProfile(null)
        }
      } finally {
        if (isMounted) {
          setIsLoading(false)
        }
      }
    }

    void initializeAuth()

    const {
      data: { subscription },
    } = supabase.auth.onAuthStateChange(
      async (_event, nextSession) => {
        if (!isMounted) {
          return
        }

        if (!nextSession?.user) {
          setSession(null)
          setAuthUser(null)
          setProfile(null)
          setIsLoading(false)

          return
        }

        try {
          const nextProfile =
            await loadUserProfile(
              nextSession.user,
            )

          if (!isMounted) {
            return
          }

          if (!nextProfile) {
            await supabase.auth.signOut()

            if (isMounted) {
              setSession(null)
              setAuthUser(null)
              setProfile(null)
            }

            return
          }

          if (!nextProfile.isActive) {
            console.warn(
              'Akun pengguna sedang nonaktif. Session akan diakhiri.',
            )

            await supabase.auth.signOut()

            if (isMounted) {
              setSession(null)
              setAuthUser(null)
              setProfile(null)
            }

            return
          }

          setSession(nextSession)
          setAuthUser(nextSession.user)
          setProfile(nextProfile)
        } catch (error) {
          console.error(
            'Gagal mengambil profil setelah perubahan session:',
            error,
          )

          if (isMounted) {
            setSession(null)
            setAuthUser(null)
            setProfile(null)
          }
        } finally {
          if (isMounted) {
            setIsLoading(false)
          }
        }
      },
    )

    return () => {
      isMounted = false
      subscription.unsubscribe()
    }
  }, [])

  const signOut = async () => {
    const { error } =
      await supabase.auth.signOut()

    if (error) {
      throw error
    }

    setSession(null)
    setAuthUser(null)
    setProfile(null)
  }

  const value = useMemo<AuthContextValue>(
    () => ({
      session,
      authUser,
      profile,
      isLoading,
      refreshProfile,
      signOut,
    }),
    [
      session,
      authUser,
      profile,
      isLoading,
    ],
  )

  return (
    <AuthContext.Provider value={value}>
      {children}
    </AuthContext.Provider>
  )
}

export function useAuth() {
  const context = useContext(AuthContext)

  if (!context) {
    throw new Error(
      'useAuth harus digunakan di dalam AuthProvider.',
    )
  }

  return context
}