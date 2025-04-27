import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:async';

class TransactionService {
  static final int paymentExpiryMinutes = 15;
  static final _transactionsController =
      StreamController<List<Map<String, dynamic>>>.broadcast();
  static Stream<List<Map<String, dynamic>>> get transactionsStream =>
      _transactionsController.stream;
  static RealtimeChannel? _supabaseChannel;

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
          .not('status', 'in', ['replaced', 'replaced-success']).order(
              'transaction_time',
              ascending: false);

      final transactions =
          List<Map<String, dynamic>>.from(response).map((transaction) {
        return {
          'amount': transaction['amount'],
          'transaction_time': transaction['transaction_time'],
          'status': transaction['status'],
          'campaign_title': transaction['campaigns']['title'],
        };
      }).toList();

      // Update the stream with the new data
      _transactionsController.add(transactions);

      return transactions;
    } catch (e) {
      print('Error fetching transactions: $e');
      return [];
    }
  }

  // Subscribe to realtime changes in transactions
  static StreamSubscription subscribeToTransactions({
    required Function(List<Map<String, dynamic>>) onData,
    required Function(dynamic) onError,
  }) {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) {
        throw Exception('User not logged in');
      }

      // Remove any existing subscription
      _supabaseChannel?.unsubscribe();

      // Set up Supabase realtime subscription - use a simpler approach without filter
      // We'll filter the data when we process it
      _supabaseChannel = Supabase.instance.client
          .channel('public:transactions')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'transactions',
            callback: (payload) {
              // When a change is detected, fetch the latest transactions
              // This will automatically filter by user_id in getTransactionsByUser()
              getTransactionsByUser().then(onData).catchError(onError);
            },
          )
          .subscribe();

      // Also subscribe to our StreamController
      return transactionsStream.listen(onData, onError: onError);
    } catch (e) {
      print('Error setting up realtime subscription: $e');
      // Return an empty subscription that can be safely canceled
      return Stream<List<Map<String, dynamic>>>.empty().listen((_) {});
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

  static Future<bool> cancelTransaction(String transactionId) async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return false;

      await Supabase.instance.client
          .from('transactions')
          .update({'status': 'failed'})
          .eq('id', transactionId)
          .eq('user_id', user.id)
          .eq('status', 'pending');

      // Refresh transactions after cancellation
      getTransactionsByUser();

      return true;
    } catch (e) {
      print('Error canceling transaction: $e');
      return false;
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
      bool updatedAny = false;

      // Update each expired transaction individually
      for (var transaction in pendingTransactions) {
        final transactionTime = DateTime.parse(transaction['transaction_time']);
        final difference = now.difference(transactionTime);

        if (difference.inMinutes > paymentExpiryMinutes) {
          // Update expired transaction to failed status
          await Supabase.instance.client
              .from('transactions')
              .update({'status': 'failed'}).eq('id', transaction['id']);
          updatedAny = true;
        }
      }

      // If any transactions were updated, refresh the transactions list
      if (updatedAny) {
        getTransactionsByUser();
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
      return Future.value(true);
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

  // Clean up resources when no longer needed
  static void dispose() {
    _supabaseChannel?.unsubscribe();
    _transactionsController.close();
  }
}
