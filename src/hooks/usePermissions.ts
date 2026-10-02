import { useCallback, useEffect, useMemo, useState } from 'react'
import { supabase } from '../lib/supabase'
import { useAuth } from '../contexts/AuthContext'

export type PermissionAction =
  | 'view'
  | 'create'
  | 'update'
  | 'delete'
  | 'approve'
  | 'export'
  | 'print'
  | 'upload'

export interface UserPermission {
  id: string
  module: string
  action: PermissionAction
}

interface UsePermissionsResult {
  permissions: UserPermission[]
  isLoading: boolean
  error: string | null
  hasPermission: (
    module: string,
    action?: PermissionAction,
  ) => boolean
  refreshPermissions: () => Promise<void>
}

const VALID_ACTIONS: PermissionAction[] = [
  'view',
  'create',
  'update',
  'delete',
  'approve',
  'export',
  'print',
  'upload',
]

function isValidAction(
  action: string,
): action is PermissionAction {
  return VALID_ACTIONS.includes(
    action as PermissionAction,
  )
}

export function usePermissions(): UsePermissionsResult {
  const { authUser, profile } = useAuth()

  const [permissions, setPermissions] = useState<
    UserPermission[]
  >([])

  const [isLoading, setIsLoading] = useState(true)

  const [error, setError] = useState<string | null>(
    null,
  )

  const refreshPermissions = useCallback(async () => {
    if (!authUser || !profile) {
      setPermissions([])
      setError(null)
      setIsLoading(false)
      return
    }

    setIsLoading(true)
    setError(null)

    try {
      /*
       * 1. Ambil seluruh role yang dimiliki user.
       */
      const { data: userRoles, error: userRolesError } =
        await supabase
          .from('user_roles')
          .select('role_id')
          .eq('user_id', authUser.id)

      if (userRolesError) {
        throw userRolesError
      }

      if (!userRoles || userRoles.length === 0) {
        setPermissions([])
        return
      }

      const roleIds = userRoles.map(
        (userRole) => userRole.role_id,
      )

      /*
       * 2. Ambil permission_id dari seluruh role user.
       */
      const {
        data: rolePermissions,
        error: rolePermissionsError,
      } = await supabase
        .from('role_permissions')
        .select('permission_id')
        .in('role_id', roleIds)

      if (rolePermissionsError) {
        throw rolePermissionsError
      }

      if (
        !rolePermissions ||
        rolePermissions.length === 0
      ) {
        setPermissions([])
        return
      }

      /*
       * Hilangkan permission_id duplikat apabila
       * user memiliki lebih dari satu role.
       */
      const permissionIds = Array.from(
        new Set(
          rolePermissions.map(
            (rolePermission) =>
              rolePermission.permission_id,
          ),
        ),
      )

      /*
       * 3. Ambil detail permission dari database.
       *
       * Struktur tabel permissions:
       * - id
       * - module
       * - action
       */
      const {
        data: permissionRecords,
        error: permissionsError,
      } = await supabase
        .from('permissions')
        .select('id, module, action')
        .in('id', permissionIds)

      if (permissionsError) {
        throw permissionsError
      }

      /*
       * 4. Normalisasi hasil permission.
       */
      const normalizedPermissions: UserPermission[] =
        (permissionRecords ?? [])
          .filter(
            (
              permission,
            ): permission is {
              id: string
              module: string
              action: string
            } =>
              typeof permission.id === 'string' &&
              typeof permission.module === 'string' &&
              typeof permission.action === 'string' &&
              isValidAction(permission.action),
          )
          .map((permission) => ({
            id: permission.id,
            module: permission.module,
            action:
              permission.action as PermissionAction,
          }))

      setPermissions(normalizedPermissions)
    } catch (permissionError) {
      console.error(
        'Gagal mengambil permission pengguna:',
        permissionError,
      )

      setPermissions([])

      setError(
        permissionError instanceof Error
          ? permissionError.message
          : 'Gagal mengambil hak akses pengguna.',
      )
    } finally {
      setIsLoading(false)
    }
  }, [authUser, profile])

  useEffect(() => {
    void refreshPermissions()
  }, [refreshPermissions])

  /*
   * Memeriksa permission berdasarkan module dan action.
   *
   * Contoh:
   *
   * hasPermission('dashboard', 'view')
   * hasPermission('kesiswaan', 'view')
   * hasPermission('kesiswaan', 'create')
   * hasPermission('keuangan', 'approve')
   */
  const hasPermission = useCallback(
    (
      module: string,
      action?: PermissionAction,
    ) => {
      if (!module) {
        return false
      }

      return permissions.some((permission) => {
        if (permission.module !== module) {
          return false
        }

        if (!action) {
          return true
        }

        return permission.action === action
      })
    },
    [permissions],
  )

  const result = useMemo<UsePermissionsResult>(
    () => ({
      permissions,
      isLoading,
      error,
      hasPermission,
      refreshPermissions,
    }),
    [
      permissions,
      isLoading,
      error,
      hasPermission,
      refreshPermissions,
    ],
  )

  return result
}