import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/payment_service.dart';
import 'snap_payment_screen.dart';
import 'package:intl/intl.dart';
import 'package:timeago/timeago.dart' as timeago;

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
  final int _paymentExpiryMinutes = 15; // Transaction expires after 15 minutes

  @override
  void initState() {
    super.initState();
    _fetchDonors();
    _checkPendingTransaction();
  }

  Future<void> _fetchDonors() async {
    try {
      final response = await Supabase.instance.client
          .from('transactions')
          .select('user_id, amount, created_at')
          .eq('campaign_id', widget.campaign['id'])
          .eq('status', 'success')
          .order('created_at', ascending: false);

      setState(() {
        _recentDonors = List<Map<String, dynamic>>.from(response);
        _isLoading = false;
      });
    } catch (error) {
      setState(() {
        _isLoading = false;
      });
      _showErrorSnackBar('Failed to fetch donors: $error');
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
        } else {
          setState(() {
            _pendingTransaction = response;
          });
        }
      }
    } catch (error) {
      print('Error checking pending transactions: $error');
    }
  }

  void _showErrorSnackBar(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
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
      _showErrorSnackBar('Failed to fetch user profile');
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

        _showErrorSnackBar(
            'Transaksi telah kedaluwarsa. Silakan buat donasi baru.');
        return;
      }

      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) {
        _showErrorSnackBar('Please login to donate');
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

      print("Sending transaction data to Midtrans...");
      final snapUrl = await PaymentService.createTransaction(transactionData);
      print("Received Snap URL: $snapUrl");

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
        'original_transaction_id':
            originalTransactionId, // Reference to original transaction
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
      _showErrorSnackBar('Payment failed. Please try again.');
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
        _showErrorSnackBar('Please login to donate');
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

      print("Sending transaction data to Midtrans...");
      final snapUrl = await PaymentService.createTransaction(transactionData);
      print("Received Snap URL: $snapUrl");

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
      _showErrorSnackBar('Payment failed. Please try again.');

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

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Donasi untuk ${widget.campaign['title']}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: amountController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Jumlah (IDR)',
                border: OutlineInputBorder(),
                prefixText: 'Rp ',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Batalkan'),
          ),
          ElevatedButton(
            onPressed: _isProcessingPayment
                ? null
                : () async {
                    final amount = int.tryParse(amountController.text
                            .replaceAll(RegExp(r'[^0-9]'), '')) ??
                        0;

                    if (amount <= 0) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Masukkan jumlah yang valid')),
                      );
                      return;
                    }

                    Navigator.of(context).pop();
                    await _startPayment(amount);
                  },
            child: _isProcessingPayment
                ? SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text('Donasi'),
          ),
        ],
      ),
    );
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

    return '$minutes menit $seconds detik';
  }

  @override
  Widget build(BuildContext context) {
    final campaign = widget.campaign;
    final goalAmount = (campaign['goal_amount'] ?? 0).toString();
    final collectedAmount = (campaign['collected_amount'] ?? 0).toString();

    return Scaffold(
      appBar: AppBar(
        title: Text(campaign['title'] ?? 'Campaign Detail'),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () async {
                await _fetchDonors();
                await _checkPendingTransaction();
              },
              child: SingleChildScrollView(
                physics: AlwaysScrollableScrollPhysics(),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        campaign['description'] ?? 'No Description',
                        style: TextStyle(fontSize: 16),
                      ),
                      SizedBox(height: 16),
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            children: [
                              LinearProgressIndicator(
                                value: double.parse(collectedAmount) /
                                    double.parse(goalAmount),
                                minHeight: 10,
                                color: Colors.green,
                                backgroundColor: Colors.grey[300],
                              ),
                              SizedBox(height: 8),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Terkumpul: Rp ${NumberFormat('#,###').format(int.parse(collectedAmount))}',
                                    style:
                                        TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                  Text(
                                    'Target: Rp ${NumberFormat('#,###').format(int.parse(goalAmount))}',
                                    style: TextStyle(color: Colors.grey),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      SizedBox(height: 16),

                      // Pending transaction notification
                      if (_pendingTransaction != null)
                        Card(
                          color: Colors.amber.shade50,
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(Icons.pending_actions,
                                        color: Colors.amber),
                                    SizedBox(width: 8),
                                    Text(
                                      'Transaksi Tertunda',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                  ],
                                ),
                                SizedBox(height: 8),
                                Text(
                                  'Rp ${NumberFormat('#,###').format(_pendingTransaction!['amount'])}',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 18,
                                  ),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  'Kedaluwarsa dalam: ${_getRemainingTime()}',
                                  style: TextStyle(
                                    color: Colors.red,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                SizedBox(height: 12),
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton(
                                    onPressed: _isProcessingPayment
                                        ? null
                                        : _continuePendingPayment,
                                    style: ElevatedButton.styleFrom(
                                      padding:
                                          EdgeInsets.symmetric(vertical: 12),
                                      backgroundColor: Colors.amber,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
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
                                        : Text('Lanjutkan Pembayaran'),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                      SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: (_isProcessingPayment ||
                                  _pendingTransaction != null)
                              ? null
                              : () => _showDonateDialog(context),
                          style: ElevatedButton.styleFrom(
                            padding: EdgeInsets.symmetric(vertical: 16),
                            backgroundColor: Colors.green,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
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
                              : Text('Donasi sekarang'),
                        ),
                      ),
                      SizedBox(height: 24),
                      Text(
                        'Donatur terbaru',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      SizedBox(height: 8),
                      _recentDonors.isEmpty
                          ? Center(
                              child: Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Text(
                                  'Jadilah donatur pertama!',
                                  style: TextStyle(
                                      fontSize: 14, color: Colors.grey),
                                ),
                              ),
                            )
                          : ListView.builder(
                              shrinkWrap: true,
                              physics: NeverScrollableScrollPhysics(),
                              itemCount: _recentDonors.length,
                              itemBuilder: (context, index) {
                                final donor = _recentDonors[index];
                                return Card(
                                  elevation: 2,
                                  margin:
                                      const EdgeInsets.symmetric(vertical: 8),
                                  child: ListTile(
                                    leading: CircleAvatar(
                                      child: Icon(Icons.person,
                                          color: Colors.white),
                                      backgroundColor: Colors.green,
                                    ),
                                    title: Text(
                                        donor['user_email'] ?? 'Hamba Allah'),
                                    subtitle: Text(
                                      'Donasi: Rp ${NumberFormat('#,###').format(donor['amount'] ?? 0)}',
                                      style: TextStyle(color: Colors.black87),
                                    ),
                                    trailing: Text(
                                      timeago.format(
                                        DateTime.parse(donor['created_at']),
                                        locale: 'id',
                                      ),
                                      style: TextStyle(color: Colors.grey),
                                    ),
                                  ),
                                );
                              },
                            ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }
}
