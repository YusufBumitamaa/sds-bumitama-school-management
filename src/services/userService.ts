import { supabase } from '../lib/supabase'

export type CreateUserRole =
  | 'super_admin'
  | 'admin'
  | 'kepala_sekolah'
  | 'guru'
  | 'bendahara'

export interface CreateUserPayload {
  email: string
  password: string
  fullName: string
  role: CreateUserRole
}

export interface UpdateUserPayload {
  userId: string
  email: string
  fullName: string
  role: CreateUserRole
}

export interface CreatedUser {
  id: string
  email: string
  fullName: string
  role: CreateUserRole
  roleName: string
  isActive: boolean
}

export interface UpdatedUser {
  id: string
  email: string
  fullName: string
  role: CreateUserRole
  roleName: string
  isActive: boolean
}

export interface CreateUserResponse {
  success: boolean
  message: string
  data?: CreatedUser
}

export interface UpdateUserResponse {
  success: boolean
  message: string
  data?: UpdatedUser
}

async function getAuthenticatedSession() {
  const {
    data: sessionData,
    error: sessionError,
  } = await supabase.auth.getSession()

  if (sessionError) {
    throw new Error(
      'Gagal mengambil session pengguna.',
    )
  }

  if (!sessionData.session) {
    throw new Error(
      'Session login tidak ditemukan. Silakan login kembali.',
    )
  }

  return sessionData.session
}

/**
 * Mengambil pesan error asli dari Supabase Edge Function.
 *
 * FunctionsHttpError biasanya menyediakan `context`
 * berupa Response HTTP. Response tersebut dapat berisi
 * JSON seperti:
 *
 * {
 *   success: false,
 *   message: "..."
 * }
 *
 * Dengan helper ini, pesan tersebut tidak lagi tertutup
 * oleh pesan umum "Edge Function returned a non-2xx status code".
 */
async function getFunctionErrorMessage(
  error: unknown,
  fallbackMessage: string,
): Promise<string> {
  if (
    error &&
    typeof error === 'object'
  ) {
    const functionError =
      error as {
        message?: string
        context?: unknown
      }

    const context =
      functionError.context

    if (context instanceof Response) {
      try {
        const response = context.clone()

        const contentType =
          response.headers.get(
            'content-type',
          ) ?? ''

        if (
          contentType.includes(
            'application/json',
          )
        ) {
          const body =
            await response.json()

          if (
            body &&
            typeof body.message ===
              'string' &&
            body.message.trim()
          ) {
            return body.message
          }

          if (
            body &&
            typeof body.error ===
              'string' &&
            body.error.trim()
          ) {
            return body.error
          }
        } else {
          const text =
            await response.text()

          if (text.trim()) {
            return text.trim()
          }
        }
      } catch {
        // Jika response body tidak dapat dibaca,
        // lanjutkan ke fallback di bawah.
      }
    }

    if (
      typeof functionError.message ===
        'string' &&
      functionError.message.trim()
    ) {
      return functionError.message
    }
  }

  return fallbackMessage
}

export async function createUser(
  payload: CreateUserPayload,
): Promise<CreateUserResponse> {
  await getAuthenticatedSession()

  const {
    data,
    error,
  } = await supabase.functions.invoke(
    'create-user',
    {
      body: {
        email: payload.email
          .trim()
          .toLowerCase(),
        password: payload.password,
        fullName: payload.fullName.trim(),
        role: payload.role,
      },
    },
  )

  if (error) {
    console.error(
      'create-user function error:',
      error,
    )

    const errorMessage =
      await getFunctionErrorMessage(
        error,
        'Gagal menghubungi layanan pembuatan akun.',
      )

    throw new Error(errorMessage)
  }

  const response =
    data as CreateUserResponse

  if (!response?.success) {
    throw new Error(
      response?.message ||
        'Akun pengguna gagal dibuat.',
    )
  }

  return response
}

export async function updateUser(
  payload: UpdateUserPayload,
): Promise<UpdateUserResponse> {
  await getAuthenticatedSession()

  const {
    data,
    error,
  } = await supabase.functions.invoke(
    'update-user',
    {
      body: {
        userId: payload.userId,
        email: payload.email
          .trim()
          .toLowerCase(),
        fullName: payload.fullName.trim(),
        role: payload.role,
      },
    },
  )

  if (error) {
    console.error(
      'update-user function error:',
      error,
    )

    const errorMessage =
      await getFunctionErrorMessage(
        error,
        'Gagal menghubungi layanan perubahan akun.',
      )

    throw new Error(errorMessage)
  }

  const response =
    data as UpdateUserResponse

  if (!response?.success) {
    throw new Error(
      response?.message ||
        'Data pengguna gagal diperbarui.',
    )
  }

  return response
}