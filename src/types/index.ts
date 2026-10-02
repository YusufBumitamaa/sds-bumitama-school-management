export type UserRole =
  | 'super_admin'
  | 'admin'
  | 'kepala_sekolah'
  | 'guru'
  | 'bendahara'

export type StudentStatus =
  | 'aktif'
  | 'lulus'
  | 'pindah'
  | 'keluar'

export type AttendanceStatus =
  | 'hadir'
  | 'sakit'
  | 'izin'
  | 'alpa'

export type FinancialStatus =
  | 'draft'
  | 'menunggu_persetujuan'
  | 'disetujui'
  | 'ditolak'
  | 'dibatalkan'

export interface User {
  id: string
  email: string
  fullName: string
  role: UserRole
  isActive: boolean
}

export interface Student {
  id: string
  nis: string | null
  nisn: string | null
  fullName: string
  gender: 'L' | 'P'
  birthPlace: string | null
  birthDate: string | null
  status: StudentStatus
}

export interface AcademicYear {
  id: string
  name: string
  startYear: number
  endYear: number
  isActive: boolean
}

export interface ClassRoom {
  id: string
  name: string
  grade: number
  group: string
  academicYearId: string
}

export interface TeacherStaff {
  id: string
  fullName: string
  nip: string | null
  role: 'guru' | 'tendik'
  isActive: boolean
}

export interface Subject {
  id: string
  code: string | null
  name: string
  isActive: boolean
}

export interface SchoolProfile {
  id: string
  name: string
  npsn: string | null
  address: string | null
  village: string | null
  district: string | null
  regency: string | null
  province: string | null
  postalCode: string | null
  email: string | null
  phone: string | null
  website: string | null
  vision: string | null
  mission: string | null
}

export interface NavigationItem {
  label: string
  path: string
  icon?: string
  children?: NavigationItem[]
}

export interface Permission {
  id: string
  module: string
  action:
    | 'view'
    | 'create'
    | 'update'
    | 'delete'
    | 'approve'
    | 'export'
    | 'print'
    | 'upload'
}

export interface ActivityLog {
  id: string
  userId: string
  action: string
  module: string
  description: string | null
  createdAt: string
}

export interface Notification {
  id: string
  userId: string
  title: string
  message: string
  isRead: boolean
  createdAt: string
}