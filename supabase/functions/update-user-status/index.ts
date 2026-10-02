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

type UpdateUserStatusPayload = {
  userId?: string
  isActive?: boolean
}

type UserRoleRecord = {
  role: {
    code: string
  } | null
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

Deno.serve(async (request) => {
  if (request.method === 'OPTIONS') {
    return new Response(
      'ok',
      {
        status: 200,
        headers: corsHeaders,
      },
    )
  }

  if (request.method !== 'POST') {
    return jsonResponse(
      {
        success: false,
        message:
          'Method request tidak didukung.',
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
        'SUPABASE_URL belum dikonfigurasi.',
      )
    }

    if (!supabaseAnonKey) {
      throw new Error(
        'SUPABASE_ANON_KEY belum dikonfigurasi.',
      )
    }

    if (!supabaseServiceRoleKey) {
      throw new Error(
        'SUPABASE_SERVICE_ROLE_KEY belum dikonfigurasi.',
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

    const {
      data: authData,
      error: authError,
    } =
      await userClient.auth.getUser()

    if (
      authError ||
      !authData.user
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

    const currentUser =
      authData.user

    const {
      data: currentUserRoles,
      error:
        currentUserRolesError,
    } =
      await adminClient
        .from('user_roles')
        .select(
          `
            role:roles (
              code
            )
          `,
        )
        .eq(
          'user_id',
          currentUser.id,
        )

    if (currentUserRolesError) {
      throw new Error(
        `Gagal memeriksa role pengguna: ${currentUserRolesError.message}`,
      )
    }

    const isSuperAdmin =
      (
        currentUserRoles as UserRoleRecord[] ??
        []
      ).some(
        (record) =>
          record.role?.code ===
          'super_admin',
      )

    if (!isSuperAdmin) {
      return jsonResponse(
        {
          success: false,
          message:
            'Hanya Super Admin yang dapat mengubah status pengguna.',
        },
        403,
      )
    }

    let payload:
      UpdateUserStatusPayload

    try {
      payload =
        (await request.json()) as UpdateUserStatusPayload
    } catch {
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
      typeof payload.userId ===
      'string'
        ? payload.userId.trim()
        : ''

    const isActive =
      payload.isActive

    if (!userId) {
      return jsonResponse(
        {
          success: false,
          message:
            'User ID wajib diisi.',
        },
        400,
      )
    }

    if (
      typeof isActive !==
      'boolean'
    ) {
      return jsonResponse(
        {
          success: false,
          message:
            'Status pengguna tidak valid.',
        },
        400,
      )
    }

    if (
      userId === currentUser.id &&
      !isActive
    ) {
      return jsonResponse(
        {
          success: false,
          message:
            'Akun yang sedang digunakan tidak dapat dinonaktifkan.',
        },
        400,
      )
    }

    const {
      data: targetUser,
      error:
        targetUserError,
    } =
      await adminClient
        .from('users')
        .select(
          'id, email, full_name, is_active',
        )
        .eq('id', userId)
        .maybeSingle()

    if (targetUserError) {
      throw new Error(
        `Gagal mengambil data pengguna: ${targetUserError.message}`,
      )
    }

    if (!targetUser) {
      return jsonResponse(
        {
          success: false,
          message:
            'Pengguna tidak ditemukan.',
        },
        404,
      )
    }

    const {
      data: targetRoles,
      error:
        targetRolesError,
    } =
      await adminClient
        .from('user_roles')
        .select(
          `
            role:roles (
              code
            )
          `,
        )
        .eq(
          'user_id',
          userId,
        )

    if (targetRolesError) {
      throw new Error(
        `Gagal memeriksa role pengguna target: ${targetRolesError.message}`,
      )
    }

    const targetIsSuperAdmin =
      (
        targetRoles as UserRoleRecord[] ??
        []
      ).some(
        (record) =>
          record.role?.code ===
          'super_admin',
      )

    if (
      targetIsSuperAdmin &&
      !isActive
    ) {
      return jsonResponse(
        {
          success: false,
          message:
            'Akun Super Admin tidak dapat dinonaktifkan melalui fitur ini.',
        },
        400,
      )
    }

    if (
      targetUser.is_active ===
      isActive
    ) {
      return jsonResponse(
        {
          success: true,
          message: isActive
            ? 'Pengguna sudah dalam status aktif.'
            : 'Pengguna sudah dalam status nonaktif.',
          data: {
            id: targetUser.id,
            email:
              targetUser.email,
            fullName:
              targetUser.full_name,
            isActive:
              targetUser.is_active,
          },
        },
      )
    }

    const {
      data: updatedUser,
      error:
        updateError,
    } =
      await adminClient
        .from('users')
        .update({
          is_active:
            isActive,
        })
        .eq(
          'id',
          userId,
        )
        .select(
          'id, email, full_name, is_active',
        )
        .single()

    if (updateError) {
      throw new Error(
        `Gagal memperbarui status pengguna: ${updateError.message}`,
      )
    }

    const action =
      isActive
        ? 'ACTIVATE_USER'
        : 'DEACTIVATE_USER'

    const statusLabel =
      isActive
        ? 'mengaktifkan'
        : 'menonaktifkan'

    const {
      error:
        auditError,
    } =
      await adminClient
        .from('activity_logs')
        .insert({
          user_id:
            currentUser.id,
          action,
          module:
            'pengguna',
          description:
            `Super Admin ${statusLabel} akun ${targetUser.full_name ?? targetUser.email}.`,
          metadata: {
            target_user_id:
              targetUser.id,
            target_email:
              targetUser.email,
            previous_is_active:
              targetUser.is_active,
            new_is_active:
              isActive,
          },
        })

    if (auditError) {
      console.error(
        'Gagal mencatat audit log:',
        auditError,
      )
    }

    return jsonResponse({
      success: true,
      message: isActive
        ? 'Pengguna berhasil diaktifkan.'
        : 'Pengguna berhasil dinonaktifkan.',
      data: {
        id:
          updatedUser.id,
        email:
          updatedUser.email,
        fullName:
          updatedUser.full_name,
        isActive:
          updatedUser.is_active,
      },
    })
  } catch (error) {
    console.error(
      'update-user-status error:',
      error,
    )

    const message =
      error instanceof Error
        ? error.message
        : 'Terjadi kesalahan pada server.'

    return jsonResponse(
      {
        success: false,
        message,
      },
      500,
    )
  }
})