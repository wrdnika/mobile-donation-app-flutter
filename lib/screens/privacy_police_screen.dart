import 'package:flutter/material.dart';

class PrivacyPoliceScreen extends StatelessWidget {
  const PrivacyPoliceScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Privacy Police')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Text(
                'Privacy Police',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 10),
              Text(
                'Kami menghargai privasi Anda dan berkomitmen untuk melindungi informasi pribadi Anda. '
                'Data yang dikumpulkan hanya digunakan untuk keperluan donasi dan tidak akan dibagikan tanpa izin.',
                style: TextStyle(fontSize: 16),
              ),
              SizedBox(height: 20),
              Text(
                '1. Data yang Kami Kumpulkan:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              Text(
                  '- Nama lengkap\n- Email\n- Nomor telepon\n- Riwayat transaksi donasi'),
              SizedBox(height: 10),
              Text(
                '2. Penggunaan Data:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              Text(
                  'Kami menggunakan data Anda hanya untuk keperluan operasional aplikasi, '
                  'seperti pencatatan donasi, mengirim notifikasi, dan verifikasi akun.'),
              SizedBox(height: 10),
              Text(
                '3. Keamanan Data:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              Text(
                  'Kami menjaga keamanan data Anda dengan teknologi enkripsi dan prosedur keamanan ketat.'),
              SizedBox(height: 10),
              Text(
                '4. Hak Pengguna:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              Text(
                  'Anda dapat meminta penghapusan akun atau perubahan data pribadi dengan menghubungi kami.'),
              SizedBox(height: 20),
              Text(
                'Jika Anda memiliki pertanyaan, silakan hubungi kami di muhamadandikawardana@gmail.com (+6287781235333)',
                style: TextStyle(fontStyle: FontStyle.italic),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
