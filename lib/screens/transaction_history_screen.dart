import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/transaction_service.dart';
import 'dart:async';

class TransactionHistoryScreen extends StatefulWidget {
  @override
  _TransactionHistoryScreenState createState() =>
      _TransactionHistoryScreenState();
}

class _TransactionHistoryScreenState extends State<TransactionHistoryScreen> {
  List<Map<String, dynamic>>? _transactions;
  bool _isLoading = true;
  bool _hasError = false;
  String _errorMessage = '';
  Timer? _refreshTimer;
  StreamSubscription? _transactionSubscription;
  Timer? _expiryCheckTimer;

  @override
  void initState() {
    super.initState();
    _loadTransactions();

    // Set up periodic refresh every 15 seconds as a fallback
    _refreshTimer = Timer.periodic(Duration(seconds: 15), (timer) {
      if (mounted) {
        _loadTransactions();
      }
    });

    // Set up timer to check for expired transactions every minute
    _expiryCheckTimer = Timer.periodic(Duration(minutes: 1), (timer) {
      TransactionService.checkAndUpdateExpiredTransactions();
    });

    // Check for expired transactions immediately on load
    TransactionService.checkAndUpdateExpiredTransactions();

    // Listen for real-time updates
    _setupRealtimeSubscription();
  }

  void _setupRealtimeSubscription() {
    try {
      // Subscribe to changes in the transactions table for the current user
      _transactionSubscription =
          TransactionService.subscribeToTransactions(onData: (transactions) {
        if (mounted) {
          setState(() {
            _transactions = transactions;
            _isLoading = false;
          });
        }
      }, onError: (error) {
        if (mounted) {
          setState(() {
            _hasError = true;
            _errorMessage = error.toString();
            _isLoading = false;
          });
        }
      });
    } catch (e) {
      print('Error setting up realtime subscription: $e');
      // Fall back to regular fetching if subscription fails
      _loadTransactions();
    }
  }

  @override
  void dispose() {
    // Cancel all timers and subscriptions when the widget is disposed
    _refreshTimer?.cancel();
    _expiryCheckTimer?.cancel();
    _transactionSubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadTransactions() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _hasError = false;
    });

    try {
      final transactions = await TransactionService.getTransactionsByUser();

      if (mounted) {
        setState(() {
          _transactions = transactions;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _hasError = true;
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          image: DecorationImage(
            image: AssetImage(
                "assets/images/—Pngtree—luxury mandala golden transparent background_5996759.png"),
            fit: BoxFit.cover,
          ),
        ),
        child: RefreshIndicator(
          onRefresh: () async {
            await _loadTransactions();
          },
          child: _buildContent(),
        ),
      ),
    );
  }

  Widget _buildContent() {
    if (_isLoading) {
      return Center(child: CircularProgressIndicator());
    } else if (_hasError) {
      return Center(child: Text('Error: $_errorMessage'));
    } else if (_transactions == null || _transactions!.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.receipt_long,
              size: 70,
              color: Colors.grey[600],
            ),
            SizedBox(height: 16),
            Text(
              'Belum ada transaksi.',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey[700],
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Transaksi Anda akan muncul di sini',
              style: TextStyle(
                color: Colors.grey[500],
              ),
            ),
          ],
        ),
      );
    } else {
      return ListView.builder(
        padding: const EdgeInsets.all(8.0),
        itemCount: _transactions!.length,
        itemBuilder: (context, index) {
          final transaction = _transactions![index];
          final amount = transaction['amount'];
          final campaignTitle = transaction['campaign_title'] ?? 'Unknown';
          final transactionTime =
              DateTime.parse(transaction['transaction_time']);
          final status = transaction['status'] ?? 'Tidak Diketahui';

          // For pending transactions, show remaining time
          String? remainingTime;
          if (status == 'pending') {
            remainingTime = TransactionService.getRemainingTime(transaction);
          }

          // Determine status color and text
          Color statusColor;
          String statusText;

          switch (status) {
            case 'success':
              statusColor = Colors.green;
              statusText = 'Berhasil';
              break;
            case 'pending':
              statusColor = Colors.orange;
              statusText = 'Menunggu Pembayaran';
              break;
            case 'failed':
              statusColor = Colors.red;
              statusText = 'Gagal';
              break;
            case 'replaced':
              statusColor = Colors.blue;
              statusText = 'Diganti';
              break;
            default:
              statusColor = Colors.grey;
              statusText = status;
          }

          return Card(
            margin: const EdgeInsets.symmetric(vertical: 8.0),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12.0),
            ),
            elevation: 6,
            child: ListTile(
              contentPadding: const EdgeInsets.all(16.0),
              title: Text(
                'Rp ${NumberFormat('#,###').format(amount)}',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.green[800],
                ),
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Kampanye: $campaignTitle'),
                  Row(
                    children: [
                      Container(
                        padding:
                            EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: statusColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: statusColor),
                        ),
                        child: Text(
                          statusText,
                          style: TextStyle(
                            color: statusColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Tanggal: ${DateFormat('dd MMM yyyy').format(transactionTime)}',
                  ),
                  Text(
                    'Jam: ${DateFormat('HH:mm').format(transactionTime)}',
                  ),
                  if (remainingTime != null)
                    Text(
                      'Sisa waktu: $remainingTime',
                      style: TextStyle(
                        color: Colors.orange[700],
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                ],
              ),
              trailing: Icon(
                _getIconForStatus(status),
                color: statusColor,
              ),
            ),
          );
        },
      );
    }
  }

  IconData _getIconForStatus(String status) {
    switch (status) {
      case 'success':
        return Icons.check_circle;
      case 'pending':
        return Icons.pending;
      case 'failed':
        return Icons.cancel;
      case 'replaced':
        return Icons.swap_horiz;
      default:
        return Icons.help_outline;
    }
  }
}
