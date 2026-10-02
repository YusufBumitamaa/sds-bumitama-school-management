import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers':
    'authorization, x-client-info, apikey, content-type, x-bootstrap-secret',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
}

type BootstrapRequest = {
  email?: string
  password?: string
  full_name?: string
}

function jsonResponse(
  body: Record<string, unknown>,
  status = 200,
) {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      ...corsHeaders,
      'Content-Type': 'application/json',
    },
  })
}

function serializeError(error: unknown) {
  if (error instanceof Error) {
    return {
      name: error.name,
      message: error.message,
      stack: error.stack ?? null,
    }
  }

  if (typeof error === 'object' && error !== null) {
    try {
      return JSON.parse(JSON.stringify(error))
    } catch {
      return {
        value: String(error),
      }
    }
  }

  return {
    value: String(error),
  }
}

function isValidEmail(email: string) {
  return /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)
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
        message: 'Method tidak diizinkan. Gunakan POST.',
      },
      405,
    )
  }

  const bootstrapSecret = Deno.env.get('BOOTSTRAP_SECRET')
  const supabaseUrl = Deno.env.get('SUPABASE_URL')
  const serviceRoleKey = Deno.env.get(
    'SUPABASE_SERVICE_ROLE_KEY',
  )

  if (!bootstrapSecret) {
    return jsonResponse(
      {
        success: false,
        message:
          'BOOTSTRAP_SECRET belum dikonfigurasi pada Edge Function.',
      },
      500,
    )
  }

  if (!supabaseUrl || !serviceRoleKey) {
    return jsonResponse(
      {
        success: false,
        message:
          'Konfigurasi Supabase Edge Function belum lengkap.',
        diagnostics: {
          hasSupabaseUrl: Boolean(supabaseUrl),
          hasServiceRoleKey: Boolean(serviceRoleKey),
        },
      },
      500,
    )
  }

  const providedSecret =
    request.headers.get('x-bootstrap-secret') ?? ''

  if (!providedSecret || providedSecret !== bootstrapSecret) {
    return jsonResponse(
      {
        success: false,
        message: 'Bootstrap secret tidak valid.',
      },
      401,
    )
  }

  let body: BootstrapRequest

  try {
    body = await request.json()
  } catch (error) {
    return jsonResponse(
      {
        success: false,
        message: 'Body request harus berupa JSON yang valid.',
        detail: serializeError(error),
      },
      400,
    )
  }

  const email = body.email?.trim().toLowerCase() ?? ''
  const password = body.password ?? ''
  const fullName = body.full_name?.trim() ?? ''

  if (!email || !password || !fullName) {
    return jsonResponse(
      {
        success: false,
        message:
          'Email, password, dan nama lengkap wajib diisi.',
      },
      400,
    )
  }

  if (!isValidEmail(email)) {
    return jsonResponse(
      {
        success: false,
        message: 'Format email tidak valid.',
      },
      400,
    )
  }

  if (password.length < 12) {
    return jsonResponse(
      {
        success: false,
        message:
          'Password Super Admin minimal 12 karakter.',
      },
      400,
    )
  }

  if (fullName.length < 3) {
    return jsonResponse(
      {
        success: false,
        message:
          'Nama lengkap minimal 3 karakter.',
      },
      400,
    )
  }

  const supabaseAdmin = createClient(
    supabaseUrl,
    serviceRoleKey,
    {
      auth: {
        autoRefreshToken: false,
        persistSession: false,
      },
    },
  )

  try {
    const {
      count: existingUserCount,
      error: usersCheckError,
    } = await supabaseAdmin
      .from('users')
      .select('id', {
        count: 'exact',
        head: true,
      })

    if (usersCheckError) {
      return jsonResponse(
        {
          success: false,
          message:
            'Gagal memeriksa status bootstrap database.',
          detail: serializeError(usersCheckError),
          diagnostics: {
            table: 'users',
            operation: 'select count',
          },
        },
        500,
      )
    }

    if ((existingUserCount ?? 0) > 0) {
      return jsonResponse(
        {
          success: false,
          message:
            'Bootstrap Super Admin sudah pernah dilakukan. Proses ini hanya dapat dilakukan sebelum user pertama dibuat.',
          existing_user_count: existingUserCount,
        },
        409,
      )
    }

    const {
      data: superAdminRole,
      error: roleError,
    } = await supabaseAdmin
      .from('roles')
      .select('id, code, name, is_active')
      .eq('code', 'super_admin')
      .maybeSingle()

    if (roleError) {
      return jsonResponse(
        {
          success: false,
          message:
            'Gagal memeriksa role super_admin.',
          detail: serializeError(roleError),
          diagnostics: {
            table: 'roles',
            operation: 'select super_admin role',
          },
        },
        500,
      )
    }

    if (!superAdminRole) {
      return jsonResponse(
        {
          success: false,
          message:
            'Role super_admin belum tersedia. Pastikan migration 001_identity_security sudah diterapkan.',
        },
        500,
      )
    }

    if (!superAdminRole.is_active) {
      return jsonResponse(
        {
          success: false,
          message:
            'Role super_admin tersedia tetapi sedang tidak aktif.',
        },
        500,
      )
    }

    const {
      data: authUserResult,
      error: authUserError,
    } = await supabaseAdmin.auth.admin.createUser({
      email,
      password,
      email_confirm: true,
      user_metadata: {
        full_name: fullName,
      },
    })

    if (authUserError || !authUserResult.user) {
      return jsonResponse(
        {
          success: false,
          message:
            'Gagal membuat akun autentikasi Super Admin.',
          detail: authUserError
            ? serializeError(authUserError)
            : {
                message:
                  'Supabase Auth tidak mengembalikan user.',
              },
        },
        400,
      )
    }

    const authUserId = authUserResult.user.id

    const { error: profileError } =
      await supabaseAdmin
        .from('users')
        .insert({
          id: authUserId,
          email,
          full_name: fullName,
          is_active: true,
        })

    if (profileError) {
      await supabaseAdmin.auth.admin.deleteUser(
        authUserId,
      )

      return jsonResponse(
        {
          success: false,
          message:
            'Profil Super Admin gagal dibuat. Akun Auth telah dibatalkan.',
          detail: serializeError(profileError),
          diagnostics: {
            table: 'users',
            operation: 'insert profile',
          },
        },
        500,
      )
    }

    const { error: userRoleError } =
      await supabaseAdmin
        .from('user_roles')
        .insert({
          user_id: authUserId,
          role_id: superAdminRole.id,
        })

    if (userRoleError) {
      await supabaseAdmin
        .from('users')
        .delete()
        .eq('id', authUserId)

      await supabaseAdmin.auth.admin.deleteUser(
        authUserId,
      )

      return jsonResponse(
        {
          success: false,
          message:
            'Role Super Admin gagal diberikan. Perubahan telah dibatalkan.',
          detail: serializeError(userRoleError),
          diagnostics: {
            table: 'user_roles',
            operation: 'insert role assignment',
          },
        },
        500,
      )
    }

    return jsonResponse(
      {
        success: true,
        message:
          'Bootstrap Super Admin berhasil.',
        user: {
          id: authUserId,
          email,
          full_name: fullName,
          role: 'super_admin',
        },
      },
      201,
    )
  } catch (error) {
    return jsonResponse(
      {
        success: false,
        message:
          'Terjadi kesalahan tidak terduga pada proses bootstrap.',
        detail: serializeError(error),
      },
      500,
    )
  }
})