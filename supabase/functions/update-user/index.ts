import {
  createClient,
} from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers':
    'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods':
    'POST, OPTIONS',
}

type AppRole =
  | 'super_admin'
  | 'admin'
  | 'kepala_sekolah'
  | 'guru'
  | 'bendahara'

interface UpdateUserRequest {
  userId?: string
  email?: string
  fullName?: string
  role?: AppRole
}

function jsonResponse(
  body: Record<string, unknown>,
  status = 200,
) {
  return new Response(
    JSON.stringify(body),
    {
      status,
      headers: {
        ...corsHeaders,
        'Content-Type':
          'application/json',
      },
    },
  )
}

function normalizeRole(
  value: unknown,
): AppRole | null {
  if (
    value === 'super_admin' ||
    value === 'admin' ||
    value === 'kepala_sekolah' ||
    value === 'guru' ||
    value === 'bendahara'
  ) {
    return value
  }

  return null
}

Deno.serve(async (request) => {
  if (
    request.method ===
    'OPTIONS'
  ) {
    return new Response(
      'ok',
      {
        status: 200,
        headers: corsHeaders,
      },
    )
  }

  if (
    request.method !==
    'POST'
  ) {
    return jsonResponse(
      {
        success: false,
        message:
          'Method tidak diizinkan.',
      },
      405,
    )
  }

  try {
    const supabaseUrl =
      Deno.env.get(
        'SUPABASE_URL',
      )

    const supabaseAnonKey =
      Deno.env.get(
        'SUPABASE_ANON_KEY',
      )

    const supabaseServiceRoleKey =
      Deno.env.get(
        'SUPABASE_SERVICE_ROLE_KEY',
      )

    if (!supabaseUrl) {
      throw new Error(
        'SUPABASE_URL belum tersedia pada Edge Function.',
      )
    }

    if (!supabaseAnonKey) {
      throw new Error(
        'SUPABASE_ANON_KEY belum tersedia pada Edge Function.',
      )
    }

    if (!supabaseServiceRoleKey) {
      throw new Error(
        'SUPABASE_SERVICE_ROLE_KEY belum tersedia pada Edge Function.',
      )
    }

    const authorization =
      request.headers.get(
        'Authorization',
      )

    if (!authorization) {
      return jsonResponse(
        {
          success: false,
          message:
            'Authorization header tidak ditemukan.',
        },
        401,
      )
    }

    const userClient =
      createClient(
        supabaseUrl,
        supabaseAnonKey,
        {
          global: {
            headers: {
              Authorization:
                authorization,
            },
          },
        },
      )

    const adminClient =
      createClient(
        supabaseUrl,
        supabaseServiceRoleKey,
      )

    /*
     * Verifikasi token pengguna yang sedang login.
     */
    const {
      data: authData,
      error: authError,
    } =
      await userClient.auth.getUser()

    if (authError) {
      console.error(
        'update-user auth.getUser error:',
        authError,
      )

      return jsonResponse(
        {
          success: false,
          message:
            'Session pengguna tidak valid atau sudah berakhir.',
        },
        401,
      )
    }

    const currentUser =
      authData.user

    if (!currentUser) {
      return jsonResponse(
        {
          success: false,
          message:
            'Pengguna yang sedang login tidak ditemukan.',
        },
        401,
      )
    }

    /*
     * Pastikan pengguna yang sedang login
     * adalah Super Admin.
     */
    const {
      data: currentRoleRecords,
      error:
        currentRoleError,
    } = await adminClient
      .from('user_roles')
      .select(
        `
          role_id,
          roles (
            code
          )
        `,
      )
      .eq(
        'user_id',
        currentUser.id,
      )

    if (currentRoleError) {
      console.error(
        'update-user current role query error:',
        currentRoleError,
      )

      return jsonResponse(
        {
          success: false,
          message:
            'Gagal memeriksa hak akses pengguna.',
        },
        500,
      )
    }

    const currentRoles =
      (currentRoleRecords ??
        []).map(
          (record) => {
            const role =
              Array.isArray(
                record.roles,
              )
                ? record
                    .roles[0]
                : record.roles

            return role?.code
          },
        )

    if (
      !currentRoles.includes(
        'super_admin',
      )
    ) {
      return jsonResponse(
        {
          success: false,
          message:
            'Hanya Super Admin yang dapat mengubah data pengguna.',
        },
        403,
      )
    }

    /*
     * Parse request body.
     */
    let payload:
      | UpdateUserRequest
      | null = null

    try {
      payload =
        (await request.json()) as UpdateUserRequest
    } catch (bodyError) {
      console.error(
        'update-user request body error:',
        bodyError,
      )

      return jsonResponse(
        {
          success: false,
          message:
            'Body request tidak valid.',
        },
        400,
      )
    }

    const userId =
      typeof payload?.userId ===
      'string'
        ? payload.userId.trim()
        : ''

    const email =
      typeof payload?.email ===
      'string'
        ? payload.email
            .trim()
            .toLowerCase()
        : ''

    const fullName =
      typeof payload?.fullName ===
      'string'
        ? payload.fullName.trim()
        : ''

    const role =
      normalizeRole(
        payload?.role,
      )

    if (!userId) {
      return jsonResponse(
        {
          success: false,
          message:
            'ID pengguna wajib diisi.',
        },
        400,
      )
    }

    if (!email) {
      return jsonResponse(
        {
          success: false,
          message:
            'Email wajib diisi.',
        },
        400,
      )
    }

    if (!fullName) {
      return jsonResponse(
        {
          success: false,
          message:
            'Nama lengkap wajib diisi.',
        },
        400,
      )
    }

    if (!role) {
      return jsonResponse(
        {
          success: false,
          message:
            'Role pengguna tidak valid.',
        },
        400,
      )
    }

    /*
     * Ambil data pengguna target.
     */
    const {
      data: targetUser,
      error:
        targetUserError,
    } =
      await adminClient
        .from('users')
        .select(
          `
            id,
            email,
            full_name,
            is_active
          `,
        )
        .eq(
          'id',
          userId,
        )
        .maybeSingle()

    if (targetUserError) {
      console.error(
        'update-user target user query error:',
        targetUserError,
      )

      return jsonResponse(
        {
          success: false,
          message:
            'Gagal mengambil data pengguna yang akan diperbarui.',
        },
        500,
      )
    }

    if (!targetUser) {
      return jsonResponse(
        {
          success: false,
          message:
            'Pengguna yang akan diperbarui tidak ditemukan.',
        },
        404,
      )
    }

    /*
     * Ambil role pengguna target.
     */
    const {
      data: targetRoleRecords,
      error:
        targetRoleError,
    } = await adminClient
      .from('user_roles')
      .select(
        `
          role_id,
          roles (
            id,
            code,
            name
          )
        `,
      )
      .eq(
        'user_id',
        userId,
      )

    if (targetRoleError) {
      console.error(
        'update-user target role query error:',
        targetRoleError,
      )

      return jsonResponse(
        {
          success: false,
          message:
            'Gagal mengambil role pengguna.',
        },
        500,
      )
    }

    const targetRoles =
      (targetRoleRecords ??
        []).map(
          (record) => {
            const targetRole =
              Array.isArray(
                record.roles,
              )
                ? record
                    .roles[0]
                : record.roles

            return {
              roleId:
                record.role_id,
              code:
                targetRole?.code ??
                null,
              name:
                targetRole?.name ??
                null,
            }
          },
        )

    const targetIsSuperAdmin =
      targetRoles.some(
        (item) =>
          item.code ===
          'super_admin',
      )

    /*
     * Proteksi Super Admin.
     *
     * Super Admin hanya boleh mengedit
     * data dasar dirinya sendiri dan tetap
     * harus menggunakan role super_admin.
     *
     * Super Admin lain tidak boleh diedit.
     */
    if (
      targetIsSuperAdmin &&
      userId !==
        currentUser.id
    ) {
      return jsonResponse(
        {
          success: false,
          message:
            'Akun Super Admin lain tidak dapat diedit melalui menu ini.',
        },
        403,
      )
    }

    if (
      targetIsSuperAdmin &&
      role !==
        'super_admin'
    ) {
      return jsonResponse(
        {
          success: false,
          message:
            'Role Super Admin tidak dapat diturunkan.',
        },
        400,
      )
    }

    /*
     * Pastikan role tujuan tersedia.
     */
    const {
      data: newRole,
      error:
        newRoleError,
    } =
      await adminClient
        .from('roles')
        .select(
          'id, code, name',
        )
        .eq(
          'code',
          role,
        )
        .maybeSingle()

    if (newRoleError) {
      console.error(
        'update-user new role query error:',
        newRoleError,
      )

      return jsonResponse(
        {
          success: false,
          message:
            'Gagal mengambil role tujuan.',
        },
        500,
      )
    }

    if (!newRole) {
      return jsonResponse(
        {
          success: false,
          message:
            'Role tujuan tidak ditemukan.',
        },
        400,
      )
    }

    /*
     * Cek email duplikat.
     *
     * Gunakan listUsers lalu cari email
     * yang sama. Untuk tahap awal jumlah
     * pengguna masih kecil.
     */
    const {
      data: authUsersData,
      error:
        authUsersError,
    } =
      await adminClient.auth.admin.listUsers({
        page: 1,
        perPage: 1000,
      })

    if (authUsersError) {
      console.error(
        'update-user list auth users error:',
        authUsersError,
      )

      return jsonResponse(
        {
          success: false,
          message:
            'Gagal memeriksa email pengguna.',
        },
        500,
      )
    }

    const duplicateEmail =
      authUsersData.users.find(
        (authUser) =>
          authUser.email
            ?.trim()
            .toLowerCase() ===
            email &&
          authUser.id !==
            userId,
      )

    if (duplicateEmail) {
      return jsonResponse(
        {
          success: false,
          message:
            'Email tersebut sudah digunakan oleh pengguna lain.',
        },
        409,
      )
    }

    /*
     * Ambil data Auth sebelum perubahan
     * untuk kebutuhan rollback.
     */
    const {
      data: currentAuthData,
      error:
        currentAuthError,
    } =
      await adminClient.auth.admin.getUserById(
        userId,
      )

    if (currentAuthError) {
      console.error(
        'update-user get auth user error:',
        currentAuthError,
      )

      return jsonResponse(
        {
          success: false,
          message:
            'Gagal mengambil akun autentikasi pengguna.',
        },
        500,
      )
    }

    if (!currentAuthData.user) {
      return jsonResponse(
        {
          success: false,
          message:
            'Akun autentikasi pengguna tidak ditemukan.',
        },
        404,
      )
    }

    const oldAuthEmail =
      currentAuthData.user.email ??
      targetUser.email

    const oldMetadata =
      currentAuthData.user
        .user_metadata ?? {}

    /*
     * Update Supabase Auth.
     */
    const {
      data: updatedAuthData,
      error:
        updateAuthError,
    } =
      await adminClient.auth.admin.updateUserById(
        userId,
        {
          email,
          user_metadata: {
            ...oldMetadata,
            full_name:
              fullName,
          },
        },
      )

    if (updateAuthError) {
      console.error(
        'update-user auth update error:',
        updateAuthError,
      )

      return jsonResponse(
        {
          success: false,
          message:
            updateAuthError.message ||
            'Gagal memperbarui akun autentikasi pengguna.',
        },
        500,
      )
    }

    /*
     * Update public.users.
     */
    const {
      error:
        updateProfileError,
    } =
      await adminClient
        .from('users')
        .update({
          email,
          full_name:
            fullName,
        })
        .eq(
          'id',
          userId,
        )

    if (updateProfileError) {
      console.error(
        'update-user public.users update error:',
        updateProfileError,
      )

      /*
       * Rollback Auth jika profile gagal.
       */
      await adminClient.auth.admin.updateUserById(
        userId,
        {
          email:
            oldAuthEmail,
          user_metadata:
            oldMetadata,
        },
      )

      return jsonResponse(
        {
          success: false,
          message:
            updateProfileError.message ||
            'Gagal memperbarui profil pengguna.',
        },
        500,
      )
    }

    /*
     * Simpan role lama untuk rollback.
     *
     * Aplikasi saat ini menggunakan satu
     * role utama per pengguna.
     */
    const oldRoleId =
      targetRoles[0]
        ?.roleId ?? null

    /*
     * Jika role berubah, perbarui user_roles.
     */
    const currentTargetRole =
      targetRoles[0]?.code ??
      null

    if (
      currentTargetRole !==
      role
    ) {
      const {
        error:
          deleteRoleError,
      } =
        await adminClient
          .from('user_roles')
          .delete()
          .eq(
            'user_id',
            userId,
          )

      if (deleteRoleError) {
        console.error(
          'update-user delete old role error:',
          deleteRoleError,
        )

        /*
         * Rollback profile dan Auth.
         */
        await adminClient
          .from('users')
          .update({
            email:
              targetUser.email,
            full_name:
              targetUser.full_name,
          })
          .eq(
            'id',
            userId,
          )

        await adminClient.auth.admin.updateUserById(
          userId,
          {
            email:
              oldAuthEmail,
            user_metadata:
              oldMetadata,
          },
        )

        return jsonResponse(
          {
            success: false,
            message:
              deleteRoleError.message ||
              'Gagal menghapus role lama pengguna.',
          },
          500,
        )
      }

      const {
        error:
          insertRoleError,
      } =
        await adminClient
          .from('user_roles')
          .insert({
            user_id:
              userId,
            role_id:
              newRole.id,
          })

      if (insertRoleError) {
        console.error(
          'update-user insert new role error:',
          insertRoleError,
        )

        /*
         * Rollback role lama.
         */
        if (oldRoleId) {
          await adminClient
            .from('user_roles')
            .insert({
              user_id:
                userId,
              role_id:
                oldRoleId,
            })
        }

        /*
         * Rollback profile dan Auth.
         */
        await adminClient
          .from('users')
          .update({
            email:
              targetUser.email,
            full_name:
              targetUser.full_name,
          })
          .eq(
            'id',
            userId,
          )

        await adminClient.auth.admin.updateUserById(
          userId,
          {
            email:
              oldAuthEmail,
            user_metadata:
              oldMetadata,
          },
        )

        return jsonResponse(
          {
            success: false,
            message:
              insertRoleError.message ||
              'Gagal menyimpan role baru pengguna.',
          },
          500,
        )
      }
    }

    /*
     * Catat activity log.
     *
     * Jika activity log gagal, perubahan
     * utama tetap dipertahankan karena
     * logging bukan bagian dari transaksi
     * utama pengguna.
     */
    const {
      error:
        activityLogError,
    } =
      await adminClient
        .from('activity_logs')
        .insert({
          user_id:
            currentUser.id,
          action:
            'update',
          module:
            'users',
          description:
            `Memperbarui pengguna ${fullName} (${email}) dengan role ${role}.`,
        })

    if (activityLogError) {
      console.error(
        'update-user activity log error:',
        activityLogError,
      )
    }

    return jsonResponse(
      {
        success: true,
        message:
          'Data pengguna berhasil diperbarui.',
        data: {
          id: userId,
          email:
            updatedAuthData.user
              ?.email ?? email,
          fullName,
          role,
          roleName:
            newRole.name,
          isActive:
            targetUser.is_active,
        },
      },
      200,
    )
  } catch (error) {
    console.error(
      'update-user unexpected error:',
      error,
    )

    const message =
      error instanceof Error
        ? error.message
        : 'Terjadi kesalahan internal pada Edge Function update-user.'

    return jsonResponse(
      {
        success: false,
        message:
          `Update pengguna gagal: ${message}`,
      },
      500,
    )
  }
})