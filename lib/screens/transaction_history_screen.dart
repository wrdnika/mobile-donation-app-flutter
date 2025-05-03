import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/transaction_service.dart';
import 'dart:async';

// Class to hold status-related information
class StatusInfo {
  final Color color;
  final IconData icon;
  final String text;

  StatusInfo(this.color, this.icon, this.text);
}

class TransactionHistoryScreen extends StatefulWidget {
  const TransactionHistoryScreen({Key? key}) : super(key: key);
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
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFE8F5E9),
              Color.fromARGB(255, 247, 247, 247),
            ],
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
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Memuat transaksi...'),
          ],
        ),
      );
    } else if (_hasError) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 48, color: Colors.red[300]),
              SizedBox(height: 16),
              Text(
                'Gagal memuat transaksi',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Text(_errorMessage, textAlign: TextAlign.center),
              SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _loadTransactions,
                icon: Icon(Icons.refresh),
                label: Text('Coba Lagi'),
                style: ElevatedButton.styleFrom(
                  padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    } else if (_transactions == null || _transactions!.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.receipt_long_rounded,
                size: 56,
                color: Colors.grey[400],
              ),
            ),
            SizedBox(height: 24),
            Text(
              'Belum Ada Transaksi',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.grey[800],
              ),
            ),
            SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                'Transaksi yang Anda lakukan akan muncul di sini',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[600],
                ),
              ),
            ),
          ],
        ),
      );
    } else {
      // Group transactions by date
      Map<String, List<Map<String, dynamic>>> groupedTransactions = {};

      for (var transaction in _transactions!) {
        DateTime transactionTime =
            DateTime.parse(transaction['transaction_time']);
        String dateKey = DateFormat('yyyy-MM-dd').format(transactionTime);

        if (!groupedTransactions.containsKey(dateKey)) {
          groupedTransactions[dateKey] = [];
        }

        groupedTransactions[dateKey]!.add(transaction);
      }

      // Sort dates from newest to oldest
      List<String> sortedDates = groupedTransactions.keys.toList()
        ..sort((a, b) => b.compareTo(a));

      return ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
        itemCount: sortedDates.length,
        itemBuilder: (context, dateIndex) {
          String dateKey = sortedDates[dateIndex];
          List<Map<String, dynamic>> dayTransactions =
              groupedTransactions[dateKey]!;
          DateTime date = DateTime.parse(dateKey);

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding:
                    const EdgeInsets.symmetric(vertical: 12.0, horizontal: 8.0),
                child: Row(
                  children: [
                    Container(
                      padding:
                          EdgeInsets.symmetric(vertical: 4, horizontal: 12),
                      decoration: BoxDecoration(
                        color: Theme.of(context).primaryColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        DateFormat('dd MMMM yyyy').format(date),
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).primaryColor,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              ...dayTransactions
                  .map((transaction) => _buildTransactionCard(transaction))
                  .toList(),
              if (dateIndex < sortedDates.length - 1) Divider(),
            ],
          );
        },
      );
    }
  }

  Widget _buildTransactionCard(Map<String, dynamic> transaction) {
    final amount = transaction['amount'];
    final campaignTitle = transaction['campaign_title'] ?? 'Unknown';
    final transactionTime = DateTime.parse(transaction['transaction_time']);
    final status = transaction['status'] ?? 'Tidak Diketahui';

    // For pending transactions, show remaining time
    String? remainingTime;
    if (status == 'pending') {
      remainingTime = TransactionService.getRemainingTime(transaction);
    }

    // Determine status info
    StatusInfo statusInfo = _getStatusInfo(status);

    return Card(
      margin: const EdgeInsets.only(bottom: 12.0),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16.0),
      ),
      elevation: 2,
      child: InkWell(
        borderRadius: BorderRadius.circular(16.0),
        onTap: () {
          // Show transaction details when tapped
          _showTransactionDetails(transaction);
        },
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: statusInfo.color.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      statusInfo.icon,
                      color: statusInfo.color,
                      size: 24,
                    ),
                  ),
                  SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          campaignTitle,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        SizedBox(height: 4),
                        Text(
                          DateFormat('HH:mm').format(transactionTime),
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: statusInfo.color.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      statusInfo.text,
                      style: TextStyle(
                        color: statusInfo.color,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Rp ${NumberFormat('#,###').format(amount)}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      color: Colors.green[700],
                    ),
                  ),
                  if (remainingTime != null)
                    Row(
                      children: [
                        Icon(
                          Icons.timer_outlined,
                          size: 16,
                          color: Colors.orange[700],
                        ),
                        SizedBox(width: 4),
                        Text(
                          remainingTime,
                          style: TextStyle(
                            color: Colors.orange[700],
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  StatusInfo _getStatusInfo(String status) {
    switch (status) {
      case 'success':
        return StatusInfo(Colors.green, Icons.check_circle_rounded, 'Berhasil');
      case 'pending':
        return StatusInfo(Colors.orange, Icons.pending_rounded, 'Menunggu');
      case 'failed':
        return StatusInfo(Colors.red, Icons.cancel_rounded, 'Gagal');
      case 'replaced':
        return StatusInfo(Colors.blue, Icons.swap_horiz_rounded, 'Diganti');
      default:
        return StatusInfo(Colors.grey, Icons.help_outline_rounded, status);
    }
  }

  void _showTransactionDetails(Map<String, dynamic> transaction) {
    final amount = transaction['amount'];
    final campaignTitle = transaction['campaign_title'] ?? 'Unknown';
    final transactionTime = DateTime.parse(transaction['transaction_time']);
    final status = transaction['status'] ?? 'Tidak Diketahui';
    final transactionId = transaction['id'] ?? 'Unknown';
    final paymentMethod = transaction['payment_method'] ?? 'Tidak Diketahui';

    StatusInfo statusInfo = _getStatusInfo(status);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) => SingleChildScrollView(
          controller: scrollController,
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: EdgeInsets.only(bottom: 24),
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: statusInfo.color.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        statusInfo.icon,
                        size: 32,
                        color: statusInfo.color,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 16),
                Center(
                  child: Text(
                    'Rp ${NumberFormat('#,###').format(amount)}',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.green[700],
                    ),
                  ),
                ),
                Center(
                  child: Container(
                    margin: EdgeInsets.symmetric(vertical: 16),
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: statusInfo.color.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      statusInfo.text,
                      style: TextStyle(
                        color: statusInfo.color,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                SizedBox(height: 24),
                _detailItem('Kampanye', campaignTitle),
                _detailItem('ID Transaksi', transactionId),
                _detailItem('Tanggal',
                    DateFormat('dd MMMM yyyy').format(transactionTime)),
                _detailItem(
                    'Waktu', DateFormat('HH:mm:ss').format(transactionTime)),
                _detailItem('Metode Pembayaran', paymentMethod),
                SizedBox(height: 32),
                if (status == 'pending')
                  Container(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        // Handle payment continuation
                        Navigator.pop(context);
                      },
                      child: Text('Lanjutkan Pembayaran'),
                      style: ElevatedButton.styleFrom(
                        padding: EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  child: TextButton(
                    onPressed: () {
                      Navigator.pop(context);
                    },
                    child: Text('Tutup'),
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _detailItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 15,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              value,
              style: TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: 15,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
