import 'package:flutter/material.dart';

class TermsOfServiceScreen extends StatelessWidget {
  const TermsOfServiceScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Terms of Service')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Text(
                'Terms of Service',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Text(
                'Terakhir diperbarui: 30 Januari 2025',
                style: TextStyle(fontStyle: FontStyle.italic),
              ),
              SizedBox(height: 16),
              Text(
                '1. Anda harus memberikan informasi yang benar saat registrasi.',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              Text(
                'Kami memerlukan data Anda untuk memverifikasi akun dan memastikan keakuratan informasi.',
              ),
              SizedBox(height: 10),
              Text(
                '2. Data Anda akan kami gunakan hanya untuk keperluan aplikasi.',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              Text(
                'Kami tidak akan membagikan data Anda ke pihak ketiga tanpa izin.',
              ),
              SizedBox(height: 10),
              Text(
                '3. Setiap transaksi donasi bersifat final dan tidak dapat dibatalkan.',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              Text(
                'Mohon periksa kembali sebelum melakukan donasi.',
              ),
              SizedBox(height: 10),
              Text(
                '4. Anda tidak diperbolehkan menyalahgunakan aplikasi untuk aktivitas ilegal.',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              Text(
                'Kami berhak menonaktifkan akun yang melanggar aturan.',
              ),
              SizedBox(height: 10),
              Text(
                '5. Kami berhak mengubah Terms of Service sewaktu-waktu.',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              Text(
                'Kami akan memberi tahu Anda jika ada perubahan kebijakan.',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
