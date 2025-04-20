import 'package:supabase_flutter/supabase_flutter.dart';

class TransactionService {
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
}
