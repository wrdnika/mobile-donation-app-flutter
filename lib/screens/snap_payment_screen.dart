import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'dart:async';

class SnapPaymentScreen extends StatefulWidget {
  final String snapUrl;
  final VoidCallback? onPaymentComplete;

  const SnapPaymentScreen({
    Key? key,
    required this.snapUrl,
    this.onPaymentComplete,
  }) : super(key: key);

  @override
  _SnapPaymentScreenState createState() => _SnapPaymentScreenState();
}

class _SnapPaymentScreenState extends State<SnapPaymentScreen> {
  late WebViewController _controller;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    print("Loading Snap URL: ${widget.snapUrl}");

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0x00000000))
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (String url) {
            setState(() {
              _isLoading = true;
            });
            print('Page started loading: $url');
          },
          onPageFinished: (String url) {
            setState(() {
              _isLoading = false;
            });
            print('Page finished loading: $url');

            // Handle payment status
            if (url.contains('status=success') ||
                url.contains('status=settlement') ||
                url.contains('transaction_status=settlement') ||
                url.contains('status=capture')) {
              Timer(const Duration(seconds: 2), () {
                widget.onPaymentComplete?.call();
                Navigator.of(context).pop();
              });
            }
          },
          onWebResourceError: (WebResourceError error) {
            print('Web Resource Error: ${error.description}');
            setState(() {
              _isLoading = false;
            });
            // Tampilkan error ke user
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content:
                    Text('Error loading payment page: ${error.description}'),
                backgroundColor: Colors.red,
              ),
            );
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.snapUrl));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pembayaran'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => _showCancelDialog(),
        ),
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_isLoading)
            const Center(
              child: CircularProgressIndicator(),
            ),
        ],
      ),
    );
  }

  void _showCancelDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Batalkan pembayaran?'),
        content: const Text('Anda yakin ingin membatalkan pembayaran?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Tidak'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).pop();
            },
            child: const Text('Ya'),
          ),
        ],
      ),
    );
  }
}
