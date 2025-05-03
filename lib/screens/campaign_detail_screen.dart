import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/payment_service.dart';
import 'snap_payment_screen.dart';
import 'package:intl/intl.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../services/transaction_service.dart';
import 'dart:async';

class CampaignDetailScreen extends StatefulWidget {
  final Map<String, dynamic> campaign;

  const CampaignDetailScreen({Key? key, required this.campaign})
      : super(key: key);

  @override
  _CampaignDetailScreenState createState() => _CampaignDetailScreenState();
}

class _CampaignDetailScreenState extends State<CampaignDetailScreen> {
  List<Map<String, dynamic>> _recentDonors = [];
  Map<String, dynamic>? _pendingTransaction;
  bool _isLoading = true;
  bool _isProcessingPayment = false;
  bool _isCancelingTransaction = false;
  final int _paymentExpiryMinutes = 15;
  Timer? _refreshTimer;
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _fetchDonors();
    _checkPendingTransaction();

    // Set up periodic refresh every 10 seconds
    _refreshTimer = Timer.periodic(Duration(seconds: 10), (timer) {
      if (mounted) {
        _checkPendingTransaction();
        _fetchDonors();
      }
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _fetchDonors() async {
    try {
      final response = await Supabase.instance.client
          .from('transactions')
          .select('user_id, amount, created_at')
          .eq('campaign_id', widget.campaign['id'])
          .eq('status', 'success')
          .order('created_at', ascending: false);

      if (mounted) {
        setState(() {
          _recentDonors = List<Map<String, dynamic>>.from(response);
          _isLoading = false;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        _showSnackBar('Gagal memuat data donatur', isError: true);
      }
    }
  }

  Future<void> _checkPendingTransaction() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;

      final response = await Supabase.instance.client
          .from('transactions')
          .select('*')
          .eq('campaign_id', widget.campaign['id'])
          .eq('user_id', user.id)
          .eq('status', 'pending')
          .order('transaction_time', ascending: false)
          .limit(1)
          .maybeSingle();

      if (mounted) {
        if (response != null) {
          // Check if transaction is expired (15 minutes)
          final transactionTime = DateTime.parse(response['transaction_time']);
          final now = DateTime.now();
          final difference = now.difference(transactionTime);

          if (difference.inMinutes > _paymentExpiryMinutes) {
            // Transaction expired, update status to failed
            await Supabase.instance.client
                .from('transactions')
                .update({'status': 'failed'}).eq('id', response['id']);

            setState(() {
              _pendingTransaction = null;
            });
          } else {
            setState(() {
              _pendingTransaction = response;
            });
          }
        } else {
          setState(() {
            _pendingTransaction = null;
          });
        }
      }
    } catch (error) {
      print('Error checking pending transactions: $error');
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        margin: EdgeInsets.all(10),
        duration: Duration(seconds: isError ? 4 : 2),
      ),
    );
  }

  Future<Map<String, dynamic>?> _fetchUserProfile(String userId) async {
    try {
      final response = await Supabase.instance.client
          .from('profiles')
          .select('full_name, phone')
          .eq('id', userId)
          .single();

      return response;
    } catch (e) {
      _showSnackBar('Gagal memuat profil pengguna', isError: true);
      return null;
    }
  }

  Future<void> _continuePendingPayment() async {
    if (_isProcessingPayment || _pendingTransaction == null) return;

    setState(() {
      _isProcessingPayment = true;
    });

    try {
      final transactionTime =
          DateTime.parse(_pendingTransaction!['transaction_time']);
      final now = DateTime.now();
      final difference = now.difference(transactionTime);

      // Check if transaction is still valid (not expired)
      if (difference.inMinutes > _paymentExpiryMinutes) {
        await Supabase.instance.client
            .from('transactions')
            .update({'status': 'failed'}).eq('id', _pendingTransaction!['id']);

        setState(() {
          _pendingTransaction = null;
        });

        _showSnackBar('Transaksi telah kedaluwarsa. Silakan buat donasi baru.',
            isError: true);
        return;
      }

      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) {
        _showSnackBar('Harap login untuk berdonasi', isError: true);
        return;
      }

      final profile = await _fetchUserProfile(user.id);
      if (profile == null) return;

      // Original transaction details
      final originalTransactionId = _pendingTransaction!['id'];
      final intAmount = _pendingTransaction!['amount'];

      // Generate a new order ID for Midtrans while keeping a reference to the original
      final String newOrderId =
          'ORD-CONT-${DateTime.now().millisecondsSinceEpoch}';

      final transactionData = {
        "transaction_details": {
          "order_id": newOrderId, // New order ID to avoid conflict
          "gross_amount": intAmount,
        },
        "customer_details": {
          "first_name": profile['full_name']?.split(' ').first ?? 'Hamba Allah',
          "last_name": profile['full_name']?.split(' ').length > 1
              ? profile['full_name'].split(' ').last
              : "",
          "email": user.email,
          "phone": profile['phone'] ?? "0000000000",
        },
        "item_details": [
          {
            "id": widget.campaign['id'].toString(),
            "price": intAmount,
            "quantity": 1,
            "name": "Donation for ${widget.campaign['title']}",
          }
        ],
        "enabled_payments": [
          "gopay",
          "shopeepay",
          "qris",
          "ovo",
          "dana",
          "other_qris",
        ],
        "credit_card": {
          "secure": true,
        }
      };

      final snapUrl = await PaymentService.createTransaction(transactionData);

      if (snapUrl == null) {
        throw Exception('Failed to get Snap URL');
      }

      if (!snapUrl.startsWith('https://')) {
        throw Exception('Invalid Snap URL format: $snapUrl');
      }

      // Create a new transaction entry that links to the original
      await Supabase.instance.client.from('transactions').insert({
        'order_id': newOrderId,
        'user_id': user.id,
        'campaign_id': widget.campaign['id'],
        'amount': intAmount,
        'status': 'pending',
        'transaction_time': DateTime.now().toIso8601String(),
        'original_transaction_id': originalTransactionId,
      });

      // Mark the original transaction as 'replaced'
      await Supabase.instance.client
          .from('transactions')
          .update({'status': 'replaced'}).eq('id', originalTransactionId);

      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => SnapPaymentScreen(
              snapUrl: snapUrl,
              onPaymentComplete: () async {
                try {
                  // Update the new transaction to success
                  await Supabase.instance.client
                      .from('transactions')
                      .update({'status': 'success'}).eq('order_id', newOrderId);

                  // Also mark the original as replaced-success for better tracking
                  await Supabase.instance.client
                      .from('transactions')
                      .update({'status': 'replaced-success'}).eq(
                          'id', originalTransactionId);
                } catch (e) {
                  print('Error updating transaction status: $e');
                }
                _fetchDonors();
                _checkPendingTransaction();
              },
            ),
          ),
        );
      }
    } catch (e) {
      print('Payment Error: $e');
      _showSnackBar('Pembayaran gagal. Silakan coba lagi.', isError: true);
    } finally {
      if (mounted) {
        setState(() {
          _isProcessingPayment = false;
        });
      }
    }
  }

  Future<void> _startPayment(int amount) async {
    if (_isProcessingPayment) return;

    setState(() {
      _isProcessingPayment = true;
    });

    final String orderId = 'ORD-${DateTime.now().millisecondsSinceEpoch}';

    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) {
        _showSnackBar('Harap login untuk berdonasi', isError: true);
        return;
      }

      final profile = await _fetchUserProfile(user.id);
      if (profile == null) return;

      final int intAmount = amount;

      await Supabase.instance.client.from('transactions').insert({
        'order_id': orderId,
        'user_id': user.id,
        'campaign_id': widget.campaign['id'],
        'amount': intAmount,
        'status': 'pending',
        'transaction_time': DateTime.now().toIso8601String(),
      });

      final transactionData = {
        "transaction_details": {
          "order_id": orderId,
          "gross_amount": intAmount,
        },
        "customer_details": {
          "first_name": profile['full_name']?.split(' ').first ?? 'Hamba Allah',
          "last_name": profile['full_name']?.split(' ').length > 1
              ? profile['full_name'].split(' ').last
              : "",
          "email": user.email,
          "phone": profile['phone'] ?? "0000000000",
        },
        "item_details": [
          {
            "id": widget.campaign['id'].toString(),
            "price": intAmount,
            "quantity": 1,
            "name": "Donation for ${widget.campaign['title']}",
          }
        ],
        "enabled_payments": [
          "gopay",
          "shopeepay",
          "qris",
          "ovo",
          "dana",
          "other_qris",
        ],
        "credit_card": {
          "secure": true,
        }
      };

      final snapUrl = await PaymentService.createTransaction(transactionData);

      if (snapUrl == null) {
        throw Exception('Failed to get Snap URL');
      }

      if (!snapUrl.startsWith('https://')) {
        throw Exception('Invalid Snap URL format: $snapUrl');
      }

      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => SnapPaymentScreen(
              snapUrl: snapUrl,
              onPaymentComplete: () async {
                try {
                  await Supabase.instance.client
                      .from('transactions')
                      .update({'status': 'success'}).eq('order_id', orderId);

                  // Show success message
                  _showSnackBar(
                      'Donasi berhasil! Terima kasih atas kebaikan Anda.');
                } catch (e) {
                  print('Error updating transaction status: $e');
                }
                _fetchDonors();
                _checkPendingTransaction();
              },
            ),
          ),
        );
      }
    } catch (e) {
      print('Payment Error: $e');
      _showSnackBar('Pembayaran gagal. Silakan coba lagi.', isError: true);

      try {
        await Supabase.instance.client
            .from('transactions')
            .update({'status': 'failed'}).eq('order_id', orderId);
      } catch (updateError) {
        print('Error updating transaction status: $updateError');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isProcessingPayment = false;
        });
      }
    }
  }

  void _showDonateDialog(BuildContext context) {
    final TextEditingController amountController = TextEditingController();
    // Preset donation amounts
    final List<int> presetAmounts = [10000, 50000, 100000, 500000];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
          left: 20,
          right: 20,
          top: 20,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Pilih Jumlah Donasi',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              SizedBox(height: 16),

              // Preset amount buttons
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: presetAmounts.map((amount) {
                  return ElevatedButton(
                    onPressed: () {
                      amountController.text = amount.toString();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey.shade200,
                      foregroundColor: Colors.black87,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: Text(
                      'Rp ${NumberFormat('#,###').format(amount)}',
                      style: TextStyle(fontWeight: FontWeight.w500),
                    ),
                  );
                }).toList(),
              ),

              SizedBox(height: 20),
              Text(
                'Atau masukkan jumlah lain:',
                style: TextStyle(
                  fontWeight: FontWeight.w500,
                ),
              ),
              SizedBox(height: 10),

              // Custom amount input
              TextField(
                controller: amountController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Jumlah Donasi',
                  hintText: 'Contoh: 100000',
                  prefixText: 'Rp ',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: Colors.green, width: 2),
                  ),
                  filled: true,
                  fillColor: Colors.grey.shade100,
                ),
              ),

              SizedBox(height: 24),

              // Donation button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isProcessingPayment
                      ? null
                      : () async {
                          final amount = int.tryParse(amountController.text
                                  .replaceAll(RegExp(r'[^0-9]'), '')) ??
                              0;

                          // if (amount < 10000) {
                          //   _showSnackBar('Minimal donasi Rp 10.000', isError: true);
                          //   return;
                          // }

                          Navigator.of(context).pop();
                          await _startPayment(amount);
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green.shade100,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    elevation: 0,
                  ),
                  child: _isProcessingPayment
                      ? SizedBox(
                          height: 24,
                          width: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          'Donasi Sekarang',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.green,
                          ),
                        ),
                ),
              ),
              SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _cancelTransaction(String transactionId) async {
    setState(() {
      _isCancelingTransaction = true;
    });

    try {
      final success = await TransactionService.cancelTransaction(transactionId);

      if (success) {
        _showSnackBar('Transaksi berhasil dibatalkan');

        // Refresh the page or clear the pending transaction
        setState(() {
          _pendingTransaction = null;
        });

        // Refresh donors data
        await _fetchDonors();
      } else {
        _showSnackBar('Gagal membatalkan transaksi', isError: true);
      }
    } catch (e) {
      _showSnackBar('Error: $e', isError: true);
    } finally {
      setState(() {
        _isCancelingTransaction = false;
      });
    }
  }

  String _getRemainingTime() {
    if (_pendingTransaction == null) return '';

    final transactionTime =
        DateTime.parse(_pendingTransaction!['transaction_time']);
    final expiryTime =
        transactionTime.add(Duration(minutes: _paymentExpiryMinutes));
    final now = DateTime.now();

    if (now.isAfter(expiryTime)) {
      return 'Transaksi kedaluwarsa';
    }

    final difference = expiryTime.difference(now);
    final minutes = difference.inMinutes;
    final seconds = difference.inSeconds % 60;

    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  // Method to manually refresh data
  Future<void> _refreshData() async {
    await Future.wait([
      _fetchDonors(),
      _checkPendingTransaction(),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final campaign = widget.campaign;
    final goalAmount = int.parse(campaign['goal_amount']?.toString() ?? '0');
    final collectedAmount =
        int.parse(campaign['collected_amount']?.toString() ?? '0');
    final progressPercentage =
        goalAmount > 0 ? (collectedAmount / goalAmount) : 0.0;
    final formatCurrency = NumberFormat('#,###', 'id_ID');

    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: Text(
          campaign['title'] ?? 'Campaign Detail',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        elevation: 0,
        backgroundColor: Colors.white,
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _refreshData,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _refreshData,
              child: ListView(
                controller: _scrollController,
                padding: EdgeInsets.zero,
                children: [
                  // Campaign header with progress
                  Container(
                    color: Colors.white,
                    padding: EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          campaign['description'] ?? 'No Description',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.black87,
                            height: 1.5,
                          ),
                        ),
                        SizedBox(height: 24),

                        // Progress section
                        Container(
                          padding: EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 4),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Terkumpul',
                                      style: TextStyle(
                                        color: Colors.grey.shade700,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    Text(
                                      'Target',
                                      style: TextStyle(
                                        color: Colors.grey.shade700,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Padding(
                                padding: EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 4),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Rp ${formatCurrency.format(collectedAmount)}',
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.green.shade700,
                                      ),
                                    ),
                                    Text(
                                      'Rp ${formatCurrency.format(goalAmount)}',
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              SizedBox(height: 12),

                              // Progress bar
                              Stack(
                                children: [
                                  Container(
                                    height: 12,
                                    decoration: BoxDecoration(
                                      color: Colors.grey.shade200,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                  ),
                                  Container(
                                    height: 12,
                                    width: MediaQuery.of(context).size.width *
                                        progressPercentage *
                                        0.85,
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [
                                          Colors.green.shade100,
                                          Colors.green
                                        ],
                                        begin: Alignment.centerLeft,
                                        end: Alignment.centerRight,
                                      ),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: 12),

                              // Percentage indicator
                              Padding(
                                padding: EdgeInsets.symmetric(horizontal: 10),
                                child: Text(
                                  '${(progressPercentage * 100).toStringAsFixed(1)}% tercapai',
                                  style: TextStyle(
                                    color: Colors.grey.shade700,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  SizedBox(height: 8),

                  // Pending transaction card
                  if (_pendingTransaction != null)
                    Container(
                      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.amber.shade50,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 10,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.amber.shade100,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    Icons.pending_actions,
                                    color: Colors.amber.shade800,
                                    size: 20,
                                  ),
                                ),
                                SizedBox(width: 12),
                                Text(
                                  'Transaksi Tertunda',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                              ],
                            ),
                            Padding(
                              padding: const EdgeInsets.only(left: 40),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  SizedBox(height: 8),
                                  Text(
                                    'Rp ${formatCurrency.format(_pendingTransaction!['amount'])}',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 18,
                                    ),
                                  ),
                                  SizedBox(height: 8),
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.timer,
                                        size: 16,
                                        color: Colors.red,
                                      ),
                                      SizedBox(width: 4),
                                      Text(
                                        'Kedaluwarsa dalam: ${_getRemainingTime()}',
                                        style: TextStyle(
                                          color: Colors.red,
                                          fontWeight: FontWeight.w500,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            SizedBox(height: 16),
                            Row(
                              children: [
                                Expanded(
                                  flex: 3,
                                  child: ElevatedButton(
                                    onPressed: _isProcessingPayment
                                        ? null
                                        : _continuePendingPayment,
                                    style: ElevatedButton.styleFrom(
                                      padding:
                                          EdgeInsets.symmetric(vertical: 12),
                                      backgroundColor: Colors.amber.shade600,
                                      foregroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      elevation: 0,
                                    ),
                                    child: _isProcessingPayment
                                        ? SizedBox(
                                            height: 20,
                                            width: 20,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: Colors.white,
                                            ),
                                          )
                                        : Text(
                                            'Lanjutkan Pembayaran',
                                            style: TextStyle(
                                                fontWeight: FontWeight.bold),
                                          ),
                                  ),
                                ),
                                SizedBox(width: 8),
                                Expanded(
                                  flex: 1,
                                  child: ElevatedButton(
                                    onPressed: _isCancelingTransaction
                                        ? null
                                        : () => _cancelTransaction(
                                            _pendingTransaction!['id']),
                                    style: ElevatedButton.styleFrom(
                                      padding:
                                          EdgeInsets.symmetric(vertical: 12),
                                      backgroundColor: Colors.white,
                                      foregroundColor: Colors.red,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                        side: BorderSide(
                                            color: Colors.red.shade300),
                                      ),
                                      elevation: 0,
                                    ),
                                    child: _isCancelingTransaction
                                        ? SizedBox(
                                            height: 20,
                                            width: 20,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: Colors.red,
                                            ),
                                          )
                                        : Text(
                                            'Batal',
                                            style: TextStyle(
                                                fontWeight: FontWeight.bold),
                                          ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),

                  SizedBox(height: 10),

                  // Donate button
                  Container(
                    margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: ElevatedButton(
                      onPressed:
                          (_isProcessingPayment || _pendingTransaction != null)
                              ? null
                              : () => _showDonateDialog(context),
                      style: ElevatedButton.styleFrom(
                        padding: EdgeInsets.symmetric(vertical: 16),
                        backgroundColor: Colors.green.shade100,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        elevation: 2,
                        shadowColor: Colors.green.withOpacity(0.3),
                      ),
                      child: _isProcessingPayment
                          ? SizedBox(
                              height: 24,
                              width: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.favorite, color: Colors.green),
                                SizedBox(width: 8),
                                Text(
                                  'Donasi Sekarang',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.green,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),

                  SizedBox(height: 16),

                  // Recent donors section
                  Container(
                    color: Colors.white,
                    padding: EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.people, color: Colors.green.shade600),
                            SizedBox(width: 8),
                            Text(
                              'Donatur Terbaru',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 16),
                        _recentDonors.isEmpty
                            ? Center(
                                child: Column(
                                  children: [
                                    Icon(
                                      Icons.volunteer_activism,
                                      size: 48,
                                      color: Colors.grey.shade400,
                                    ),
                                    SizedBox(height: 16),
                                    Text(
                                      'Jadilah donatur pertama!',
                                      style: TextStyle(
                                        fontSize: 16,
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
                                    SizedBox(height: 8),
                                    Text(
                                      'Setiap donasi akan sangat berarti',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.grey.shade500,
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            : ListView.separated(
                                shrinkWrap: true,
                                physics: NeverScrollableScrollPhysics(),
                                itemCount: _recentDonors.length,
                                separatorBuilder: (context, index) =>
                                    Divider(height: 1),
                                itemBuilder: (context, index) {
                                  final donor = _recentDonors[index];
                                  final donorTime =
                                      DateTime.parse(donor['created_at']);

                                  return Padding(
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 12),
                                    child: Row(
                                      children: [
                                        Container(
                                          width: 40,
                                          height: 40,
                                          decoration: BoxDecoration(
                                            color: Colors.green.shade100,
                                            shape: BoxShape.circle,
                                          ),
                                          child: Center(
                                            child: Icon(
                                              Icons.person,
                                              color: Colors.green.shade700,
                                              size: 20,
                                            ),
                                          ),
                                        ),
                                        SizedBox(width: 16),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                donor['user_email'] ??
                                                    'Hamba Allah',
                                                style: TextStyle(
                                                  fontWeight: FontWeight.w500,
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                              SizedBox(height: 4),
                                              Text(
                                                'Rp ${formatCurrency.format(donor['amount'] ?? 0)}',
                                                style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.green.shade700,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.end,
                                          children: [
                                            Text(
                                              timeago.format(donorTime,
                                                  locale: 'id'),
                                              style: TextStyle(
                                                color: Colors.grey.shade600,
                                                fontSize: 12,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                      ],
                    ),
                  ),

                  // Information section
                  Container(
                    margin: EdgeInsets.all(20),
                    padding: EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.blue.shade100),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.info_outline,
                          color: Colors.blue.shade700,
                        ),
                        SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Informasi Donasi',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                  color: Colors.blue.shade800,
                                ),
                              ),
                              SizedBox(height: 8),
                              Text(
                                'Donasi Anda akan disalurkan secara langsung untuk kampanye ini. Kami tidak memungut biaya admin apapun.',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.blue.shade900,
                                  height: 1.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  SizedBox(height: 30),
                ],
              ),
            ),

      // FAB for direct donation
      floatingActionButton: (_pendingTransaction == null &&
              !_isProcessingPayment)
          ? FloatingActionButton.extended(
              onPressed: () => _showDonateDialog(context),
              label: Text(
                'Donasi',
                style:
                    TextStyle(fontWeight: FontWeight.bold, color: Colors.green),
              ),
              icon: Icon(Icons.favorite, color: Colors.green),
              backgroundColor: Colors.green.shade100,
              elevation: 4,
            )
          : null,
    );
  }
}
