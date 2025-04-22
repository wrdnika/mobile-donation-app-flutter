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
  bool _isLoading = true;
  bool _isProcessingPayment = false;

  @override
  void initState() {
    super.initState();
    _fetchDonors();
  }

  Future<void> _fetchDonors() async {
    try {
      final response = await Supabase.instance.client
          .from('transactions')
          .select('user_id, amount, created_at')
          .eq('campaign_id', widget.campaign['id'])
          .eq('status', 'success')
          .order('created_at', ascending: false);
      // .limit(10);

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
              onRefresh: _fetchDonors,
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
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _isProcessingPayment
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
