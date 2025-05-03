import 'package:flutter/material.dart';

class TermsOfServiceScreen extends StatelessWidget {
  const TermsOfServiceScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ketentuan Layanan'),
        backgroundColor: Colors.teal,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Ketentuan Layanan',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Terakhir diperbarui: 30 Januari 2025',
              style: TextStyle(fontStyle: FontStyle.italic),
            ),
            const SizedBox(height: 24),
            _buildSection(
              title: '1. Informasi Registrasi',
              body:
                  'Anda harus memberikan informasi yang benar saat registrasi. Kami memerlukan data Anda untuk memverifikasi akun dan memastikan keakuratan informasi.',
            ),
            _buildSection(
              title: '2. Penggunaan Data',
              body:
                  'Data Anda akan kami gunakan hanya untuk keperluan aplikasi. Kami tidak akan membagikan data Anda ke pihak ketiga tanpa izin.',
            ),
            _buildSection(
              title: '3. Kebijakan Donasi',
              body:
                  'Setiap transaksi donasi bersifat final dan tidak dapat dibatalkan. Mohon periksa kembali sebelum melakukan donasi.',
            ),
            _buildSection(
              title: '4. Penggunaan Aplikasi',
              body:
                  'Anda tidak diperbolehkan menyalahgunakan aplikasi untuk aktivitas ilegal. Kami berhak menonaktifkan akun yang melanggar aturan.',
            ),
            _buildSection(
              title: '5. Perubahan Ketentuan',
              body:
                  'Kami berhak mengubah Ketentuan Layanan sewaktu-waktu. Kami akan memberi tahu Anda jika ada perubahan kebijakan.',
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Widget _buildSection({required String title, required String body}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Text(
            body,
            style: const TextStyle(fontSize: 14),
            textAlign: TextAlign.justify,
          ),
        ],
      ),
    );
  }
}
