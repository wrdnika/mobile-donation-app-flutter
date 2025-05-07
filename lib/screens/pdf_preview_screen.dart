import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

class PdfPreviewScreen extends StatefulWidget {
  final String url;
  const PdfPreviewScreen({Key? key, required this.url}) : super(key: key);

  @override
  _PdfPreviewScreenState createState() => _PdfPreviewScreenState();
}

class _PdfPreviewScreenState extends State<PdfPreviewScreen> {
  String? localPath;
  bool downloading = false;
  double progress = 0;

  @override
  void initState() {
    super.initState();
    _preparePdf(); // unduh ke cache agar bisa tampil cepat
  }

  Future<void> _preparePdf() async {
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/preview.pdf');
    if (!file.existsSync()) {
      await Dio().download(
        widget.url,
        file.path,
        onReceiveProgress: (rec, total) {
          setState(() {
            downloading = true;
            progress = rec / total;
          });
        },
      );
    }
    setState(() {
      localPath = file.path;
      downloading = false;
    });
  }

  Future<void> _downloadToDevice() async {
    // Minta izin storage
    final status = await Permission.storage.request();
    if (!status.isGranted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Izin penyimpanan dibutuhkan untuk download.')),
      );
      return;
    }

    // Path folder Download publik
    final downloadPath = '/storage/emulated/0/Download';
    final fileName = 'laporan_${DateTime.now().millisecondsSinceEpoch}.pdf';
    final savePath = '$downloadPath/$fileName';

    setState(() {
      downloading = true;
      progress = 0;
    });

    // Download dengan Dio
    try {
      await Dio().download(
        widget.url,
        savePath,
        onReceiveProgress: (rec, total) {
          setState(() {
            progress = rec / total;
          });
        },
      );

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Berhasil disimpan di Download/$fileName')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal download: $e')),
      );
    } finally {
      setState(() {
        downloading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Preview PDF'),
        backgroundColor: Colors.green.shade700,
        actions: [
          if (localPath != null && !downloading)
            IconButton(
              icon: const Icon(Icons.download),
              onPressed: _downloadToDevice,
            )
        ],
      ),
      body: downloading
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 8),
                  Text('${(progress * 100).toStringAsFixed(0)}%'),
                ],
              ),
            )
          : localPath != null
              ? PDFView(filePath: localPath!)
              : const Center(child: CircularProgressIndicator()),
    );
  }
}
