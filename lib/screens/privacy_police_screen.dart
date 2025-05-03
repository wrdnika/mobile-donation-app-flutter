import 'package:flutter/material.dart';

class PrivacyPoliceScreen extends StatelessWidget {
  const PrivacyPoliceScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Kebijakan Privasi'),
        backgroundColor: Colors.teal,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 12),
            Text(
              'Kami menghargai privasi Anda dan berkomitmen untuk melindungi informasi pribadi Anda. '
              'Data yang dikumpulkan hanya digunakan untuk keperluan donasi dan tidak akan dibagikan tanpa izin.',
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.justify,
            ),
            const SizedBox(height: 24),
            _buildSectionTitle('1. Data yang Kami Kumpulkan'),
            _buildBulletList([
              'Nama lengkap',
              'Email',
              'Nomor telepon',
              'Riwayat transaksi donasi',
            ]),
            const SizedBox(height: 16),
            _buildSectionTitle('2. Penggunaan Data'),
            _buildSectionBody(
              'Kami menggunakan data Anda hanya untuk keperluan operasional aplikasi, '
              'seperti pencatatan donasi, mengirim notifikasi, dan verifikasi akun.',
            ),
            const SizedBox(height: 16),
            _buildSectionTitle('3. Keamanan Data'),
            _buildSectionBody(
              'Kami menjaga keamanan data Anda dengan teknologi enkripsi dan prosedur keamanan ketat.',
            ),
            const SizedBox(height: 16),
            _buildSectionTitle('4. Hak Pengguna'),
            _buildSectionBody(
              'Anda dapat meminta penghapusan akun atau perubahan data pribadi dengan menghubungi kami.',
            ),
            const SizedBox(height: 24),
            const Text(
              'Jika Anda memiliki pertanyaan, silakan hubungi kami di:',
              style: TextStyle(fontStyle: FontStyle.italic),
              textAlign: TextAlign.justify,
            ),
            const SizedBox(height: 8),
            SelectableText(
              '📧 muhamadandikawardana@gmail.com\n📱 +62 877-8123-5333',
              style: TextStyle(color: Colors.teal.shade700),
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
    );
  }

  Widget _buildSectionBody(String content) {
    return Text(
      content,
      style: const TextStyle(fontSize: 14),
      textAlign: TextAlign.justify,
    );
  }

  Widget _buildBulletList(List<String> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: items
          .map((item) => Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('• ', style: TextStyle(fontSize: 14)),
                    Expanded(
                        child:
                            Text(item, style: const TextStyle(fontSize: 14))),
                  ],
                ),
              ))
          .toList(),
    );
  }
}
