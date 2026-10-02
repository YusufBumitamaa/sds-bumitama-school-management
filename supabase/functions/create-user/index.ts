import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers':
    'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods':
    'POST, OPTIONS',
}

type CreateUserRequest = {
  email?: string
  password?: string
  fullName?: string
  role?: string
}

const allowedRoles = [
  'super_admin',
  'admin',
  'kepala_sekolah',
  'guru',
  'bendahara',
] as const

type AllowedRole = (typeof allowedRoles)[number]

function isAllowedRole(
  value: string,
): value is AllowedRole {
  return allowedRoles.includes(
    value as AllowedRole,
  )
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
        'Content-Type': 'application/json',
      },
    },
  )
}

Deno.serve(async (request) => {
  if (request.method === 'OPTIONS') {
    return new Response('ok', {
      headers: corsHeaders,
    })
  }

  if (request.method !== 'POST') {
    return jsonResponse(
      {
        success: false,
        message: 'Method tidak diizinkan.',
      },
      405,
    )
  }

  const supabaseUrl =
    Deno.env.get('SUPABASE_URL')

  const supabaseAnonKey =
    Deno.env.get('SUPABASE_ANON_KEY')

  const supabaseServiceRoleKey =
    Deno.env.get(
      'SUPABASE_SERVICE_ROLE_KEY',
    )

  if (
    !supabaseUrl ||
    !supabaseAnonKey ||
    !supabaseServiceRoleKey
  ) {
    return jsonResponse(
      {
        success: false,
        message:
          'Konfigurasi environment Supabase belum lengkap.',
      },
      500,
    )
  }

  const authorization =
    request.headers.get('Authorization')

  if (!authorization) {
    return jsonResponse(
      {
        success: false,
        message:
          'Authorization diperlukan.',
      },
      401,
    )
  }

  /*
   * Client dengan token pengguna.
   * Digunakan untuk memastikan request benar-benar
   * berasal dari pengguna yang sedang login.
   */
  const userClient = createClient(
    supabaseUrl,
    supabaseAnonKey,
    {
      global: {
        headers: {
          Authorization: authorization,
        },
      },
    },
  )

  /*
   * Client Service Role.
   * Hanya digunakan di server/Edge Function.
   * Tidak pernah dikirim ke browser.
   */
  const adminClient = createClient(
    supabaseUrl,
    supabaseServiceRoleKey,
    {
      auth: {
        autoRefreshToken: false,
        persistSession: false,
      },
    },
  )

  try {
    /*
     * ========================================================
     * 1. Verifikasi pengguna yang sedang login
     * ========================================================
     */
    const {
      data: {
        user: currentUser,
      },
      error: currentUserError,
    } = await userClient.auth.getUser()

    if (
      currentUserError ||
      !currentUser
    ) {
      return jsonResponse(
        {
          success: false,
          message:
            'Session pengguna tidak valid atau sudah berakhir.',
        },
        401,
      )
    }

    /*
     * ========================================================
     * 2. Pastikan pengguna adalah Super Admin
     * ========================================================
     */
    const {
      data: currentUserRoles,
      error: currentUserRolesError,
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

    if (currentUserRolesError) {
      throw currentUserRolesError
    }

    const isSuperAdmin =
      currentUserRoles?.some(
        (item) => {
          const role = Array.isArray(item.roles)
            ? item.roles[0]
            : item.roles

          return (
            role?.code ===
            'super_admin'
          )
        },
      ) ?? false

    if (!isSuperAdmin) {
      return jsonResponse(
        {
          success: false,
          message:
            'Hanya Super Admin yang dapat membuat akun pengguna.',
        },
        403,
      )
    }

    /*
     * ========================================================
     * 3. Ambil request body
     * ========================================================
     */
    let body: CreateUserRequest

    try {
      body = await request.json()
    } catch {
      return jsonResponse(
        {
          success: false,
          message:
            'Format request tidak valid.',
        },
        400,
      )
    }

    const email =
      body.email
        ?.trim()
        .toLowerCase() ?? ''

    const password =
      body.password ?? ''

    const fullName =
      body.fullName?.trim() ?? ''

    const role =
      body.role?.trim() ?? ''

    /*
     * ========================================================
     * 4. Validasi data
     * ========================================================
     */
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

    if (!password) {
      return jsonResponse(
        {
          success: false,
          message:
            'Password wajib diisi.',
        },
        400,
      )
    }

    if (password.length < 8) {
      return jsonResponse(
        {
          success: false,
          message:
            'Password minimal 8 karakter.',
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
            'Role wajib dipilih.',
        },
        400,
      )
    }

    if (!isAllowedRole(role)) {
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
     * ========================================================
     * 5. Cari role di database
     * ========================================================
     */
    const {
      data: roleRecord,
      error: roleError,
    } = await adminClient
      .from('roles')
      .select('id, code, name')
      .eq('code', role)
      .maybeSingle()

    if (roleError) {
      throw roleError
    }

    if (!roleRecord) {
      return jsonResponse(
        {
          success: false,
          message:
            'Role yang dipilih belum tersedia di database.',
        },
        400,
      )
    }

    /*
     * ========================================================
     * 6. Buat user di Supabase Auth
     * ========================================================
     */
    const {
      data: createdAuthUser,
      error: createAuthUserError,
    } =
      await adminClient.auth.admin.createUser({
        email,
        password,
        email_confirm: true,
        user_metadata: {
          full_name: fullName,
        },
      })

    if (createAuthUserError) {
      const message =
        createAuthUserError.message

      if (
        message
          .toLowerCase()
          .includes('already')
      ) {
        return jsonResponse(
          {
            success: false,
            message:
              'Email tersebut sudah digunakan.',
          },
          409,
        )
      }

      throw createAuthUserError
    }

    const createdUser =
      createdAuthUser.user

    if (!createdUser) {
      throw new Error(
        'User Auth berhasil diproses tetapi data user tidak ditemukan.',
      )
    }

    /*
     * ========================================================
     * 7. Buat profile di public.users
     * ========================================================
     */
    const {
      error: insertProfileError,
    } = await adminClient
      .from('users')
      .insert({
        id: createdUser.id,
        email,
        full_name: fullName,
        is_active: true,
      })

    if (insertProfileError) {
      /*
       * Rollback user Auth jika profile database gagal dibuat.
       */
      await adminClient.auth.admin.deleteUser(
        createdUser.id,
      )

      throw insertProfileError
    }

    /*
     * ========================================================
     * 8. Assign role
     * ========================================================
     */
    const {
      error: insertRoleError,
    } = await adminClient
      .from('user_roles')
      .insert({
        user_id: createdUser.id,
        role_id: roleRecord.id,
      })

    if (insertRoleError) {
      /*
       * Rollback:
       * - hapus profile
       * - hapus user Auth
       */
      await adminClient
        .from('users')
        .delete()
        .eq(
          'id',
          createdUser.id,
        )

      await adminClient.auth.admin.deleteUser(
        createdUser.id,
      )

      throw insertRoleError
    }

    /*
     * ========================================================
     * 9. Activity Log
     * ========================================================
     */
    await adminClient
      .from('activity_logs')
      .insert({
        user_id: currentUser.id,
        action: 'create',
        module: 'pengguna',
        description:
          `Membuat akun pengguna ${fullName} (${email}) dengan role ${roleRecord.name}.`,
      })

    /*
     * ========================================================
     * 10. Response
     * ========================================================
     */
    return jsonResponse(
      {
        success: true,
        message:
          'Akun pengguna berhasil dibuat.',
        data: {
          id: createdUser.id,
          email,
          fullName,
          role: roleRecord.code,
          roleName: roleRecord.name,
          isActive: true,
        },
      },
      201,
    )
  } catch (error) {
    console.error(
      'create-user error:',
      error,
    )

    return jsonResponse(
      {
        success: false,
        message:
          error instanceof Error
            ? error.message
            : 'Terjadi kesalahan saat membuat akun pengguna.',
      },
      500,
    )
  }
})