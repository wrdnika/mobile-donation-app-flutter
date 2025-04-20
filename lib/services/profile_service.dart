import 'package:supabase_flutter/supabase_flutter.dart';

class ProfileService {
  static Future<Map<String, dynamic>> getUserProfile() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) {
        throw Exception('User not logged in');
      }

      final response = await Supabase.instance.client
          .from('profiles')
          .select('*')
          .eq('id', user.id)
          .single();

      return Map<String, dynamic>.from(response);
    } catch (e) {
      print('Error fetching profile: $e');
      return {};
    }
  }

  static Future<bool> updateUserProfile(String? fullName, String? phone) async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) {
        throw Exception('User not logged in');
      }

      await Supabase.instance.client
          .from('profiles')
          .update({
            'full_name': fullName,
            'phone': phone,
          })
          .eq('id', user.id);

      return true;
    } catch (e) {
      print('Error updating profile: $e');
      return false;
    }
  }
}
