export interface NavigationItem {
  label: string
  path: string
  permission?: string
  children?: NavigationItem[]
}

export const navigationItems: NavigationItem[] = [
  {
    label: 'Dashboard',
    path: '/dashboard',
    permission: 'dashboard',
  },

  {
    label: 'Profil Sekolah',
    path: '/profil-sekolah',
    permission: 'profil_sekolah',
  },

  {
    label: 'Kesiswaan',
    path: '/kesiswaan',
    permission: 'kesiswaan',
    children: [
      {
        label: 'Data Siswa',
        path: '/kesiswaan/siswa',
      },
      {
        label: 'Orang Tua/Wali',
        path: '/kesiswaan/orang-tua-wali',
      },
      {
        label: 'PPDB',
        path: '/kesiswaan/ppdb',
      },
      {
        label: 'Mutasi Siswa',
        path: '/kesiswaan/mutasi',
      },
      {
        label: 'Prestasi Siswa',
        path: '/kesiswaan/prestasi',
      },
      {
        label: 'Pelanggaran Siswa',
        path: '/kesiswaan/pelanggaran',
      },
      {
        label: 'Kegiatan Kesiswaan',
        path: '/kesiswaan/kegiatan',
      },
      {
        label: 'Alumni',
        path: '/kesiswaan/alumni',
      },
    ],
  },

  {
    label: 'Kurikulum',
    path: '/kurikulum',
    permission: 'kurikulum',
    children: [
      {
        label: 'Tahun Ajaran',
        path: '/kurikulum/tahun-ajaran',
      },
      {
        label: 'Struktur Kurikulum',
        path: '/kurikulum/struktur',
      },
      {
        label: 'Mata Pelajaran',
        path: '/kurikulum/mata-pelajaran',
      },
      {
        label: 'Jadwal Pelajaran',
        path: '/kurikulum/jadwal',
      },
      {
        label: 'Kalender Pendidikan',
        path: '/kurikulum/kalender',
      },
      {
        label: 'Perangkat Pembelajaran',
        path: '/kurikulum/perangkat',
      },
      {
        label: 'Evaluasi Kurikulum',
        path: '/kurikulum/evaluasi',
      },
    ],
  },

  {
    label: 'Akademik',
    path: '/akademik',
    permission: 'akademik',
    children: [
      {
        label: 'Rombongan Belajar',
        path: '/akademik/rombel',
      },
      {
        label: 'Wali Kelas',
        path: '/akademik/wali-kelas',
      },
      {
        label: 'Absensi',
        path: '/akademik/absensi',
      },
      {
        label: 'Penilaian',
        path: '/akademik/penilaian',
      },
      {
        label: 'Rapor',
        path: '/akademik/rapor',
      },
      {
        label: 'Kenaikan Kelas',
        path: '/akademik/kenaikan-kelas',
      },
      {
        label: 'Kelulusan',
        path: '/akademik/kelulusan',
      },
    ],
  },

  {
    label: 'Pendidik & Tenaga Kependidikan',
    path: '/gtk',
    permission: 'gtk',
    children: [
      {
        label: 'Data Guru',
        path: '/gtk/guru',
      },
      {
        label: 'Data Tendik',
        path: '/gtk/tendik',
      },
      {
        label: 'Pendidikan',
        path: '/gtk/pendidikan',
      },
      {
        label: 'Sertifikasi',
        path: '/gtk/sertifikasi',
      },
      {
        label: 'Tugas Tambahan',
        path: '/gtk/tugas-tambahan',
      },
      {
        label: 'Kehadiran GTK',
        path: '/gtk/kehadiran',
      },
    ],
  },

  {
    label: 'Sarpras',
    path: '/sarpras',
    permission: 'sarpras',
    children: [
      {
        label: 'Ruangan',
        path: '/sarpras/ruangan',
      },
      {
        label: 'Inventaris',
        path: '/sarpras/inventaris',
      },
      {
        label: 'Kondisi Sarpras',
        path: '/sarpras/kondisi',
      },
      {
        label: 'Pengadaan',
        path: '/sarpras/pengadaan',
      },
      {
        label: 'Pemeliharaan',
        path: '/sarpras/pemeliharaan',
      },
      {
        label: 'Penghapusan Aset',
        path: '/sarpras/penghapusan-aset',
      },
    ],
  },

  {
    label: 'Keuangan & Bendahara',
    path: '/keuangan',
    permission: 'keuangan',
    children: [
      {
        label: 'Dashboard Keuangan',
        path: '/keuangan/dashboard',
      },
      {
        label: 'Anggaran',
        path: '/keuangan/anggaran',
      },
      {
        label: 'Pemasukan',
        path: '/keuangan/pemasukan',
      },
      {
        label: 'Pengeluaran',
        path: '/keuangan/pengeluaran',
      },
      {
        label: 'Kas',
        path: '/keuangan/kas',
      },
      {
        label: 'Pengadaan',
        path: '/keuangan/pengadaan',
      },
      {
        label: 'Bukti Transaksi',
        path: '/keuangan/bukti-transaksi',
      },
      {
        label: 'Laporan Keuangan',
        path: '/keuangan/laporan',
      },
    ],
  },

  {
    label: 'Persuratan & Arsip',
    path: '/persuratan',
    permission: 'persuratan',
    children: [
      {
        label: 'Surat Masuk',
        path: '/persuratan/surat-masuk',
      },
      {
        label: 'Surat Keluar',
        path: '/persuratan/surat-keluar',
      },
      {
        label: 'SK',
        path: '/persuratan/sk',
      },
      {
        label: 'Dokumen Sekolah',
        path: '/persuratan/dokumen-sekolah',
      },
      {
        label: 'Arsip Digital',
        path: '/persuratan/arsip-digital',
      },
    ],
  },

  {
    label: 'Laporan',
    path: '/laporan',
    permission: 'laporan',
  },

  {
    label: 'Pengguna & Hak Akses',
    path: '/pengguna',
    permission: 'pengguna',
  },

  {
    label: 'Pengaturan',
    path: '/pengaturan',
    permission: 'pengaturan',
  },
]