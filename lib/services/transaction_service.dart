import 'package:supabase_flutter/supabase_flutter.dart';

class TransactionService {
  static final int paymentExpiryMinutes =
      15; // Transaction expires after 15 minutes

  static Future<List<Map<String, dynamic>>> getTransactionsByUser() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) {
        throw Exception('User not logged in');
      }

      final response = await Supabase.instance.client
          .from('transactions')
          .select('*, campaigns(title)')
          .eq('user_id', user.id)
          .order('transaction_time', ascending: false);

      return List<Map<String, dynamic>>.from(response).map((transaction) {
        return {
          'amount': transaction['amount'],
          'transaction_time': transaction['transaction_time'],
          'status': transaction['status'],
          'campaign_title': transaction['campaigns']['title'],
        };
      }).toList();
    } catch (e) {
      print('Error fetching transactions: $e');
      return [];
    }
  }

  static Future<Map<String, dynamic>?> getPendingTransactionForCampaign(
      String campaignId) async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return null;

      final response = await Supabase.instance.client
          .from('transactions')
          .select('*')
          .eq('campaign_id', campaignId)
          .eq('user_id', user.id)
          .eq('status', 'pending')
          .order('transaction_time', ascending: false)
          .limit(1)
          .maybeSingle();

      return response;
    } catch (e) {
      print('Error fetching pending transaction: $e');
      return null;
    }
  }

  static Future<void> checkAndUpdateExpiredTransactions() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;

      // Get all pending transactions for the current user
      final response = await Supabase.instance.client
          .from('transactions')
          .select('id, transaction_time')
          .eq('user_id', user.id)
          .eq('status', 'pending');

      final now = DateTime.now();
      final pendingTransactions = List<Map<String, dynamic>>.from(response);

      // Update each expired transaction individually
      for (var transaction in pendingTransactions) {
        final transactionTime = DateTime.parse(transaction['transaction_time']);
        final difference = now.difference(transactionTime);

        if (difference.inMinutes > paymentExpiryMinutes) {
          // Update expired transaction to failed status
          await Supabase.instance.client
              .from('transactions')
              .update({'status': 'failed'}).eq('id', transaction['id']);
        }
      }
    } catch (e) {
      print('Error checking expired transactions: $e');
    }
  }

  static Future<bool> isTransactionExpired(Map<String, dynamic> transaction) {
    try {
      final transactionTime = DateTime.parse(transaction['transaction_time']);
      final now = DateTime.now();
      final difference = now.difference(transactionTime);

      return Future.value(difference.inMinutes > paymentExpiryMinutes);
    } catch (e) {
      print('Error checking if transaction expired: $e');
      return Future.value(true); // Assume expired on error
    }
  }

  static String getRemainingTime(Map<String, dynamic> transaction) {
    try {
      final transactionTime = DateTime.parse(transaction['transaction_time']);
      final expiryTime =
          transactionTime.add(Duration(minutes: paymentExpiryMinutes));
      final now = DateTime.now();

      if (now.isAfter(expiryTime)) {
        return 'Transaksi kedaluwarsa';
      }

      final difference = expiryTime.difference(now);
      final minutes = difference.inMinutes;
      final seconds = difference.inSeconds % 60;

      return '$minutes menit $seconds detik';
    } catch (e) {
      return 'Waktu tidak tersedia';
    }
  }
}
