import 'package:supabase_flutter/supabase_flutter.dart';

class CampaignService {
  static final _client = Supabase.instance.client;

  // API untuk mendapatkan daftar kampanye
  static Future<List<Map<String, dynamic>>> getCampaigns() async {
    try {
      final response = await _client.from('campaigns').select('''
            id,
            title,
            description,
            goal_amount,
            collected_amount,
            created_at
          ''').order('created_at', ascending: false);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('Error fetching campaigns: $e');
      return [];
    }
  }

  // // API untuk melihat donasi terakhir
  // static Future<List<Map<String, dynamic>>> getRecentDonors(String campaignId) async {
  //   try {
  //     final response = await _client
  //         .from('donations')
  //         .select('''
  //           amount,
  //           created_at,
  //           profiles!donations_user_id_fkey (
  //             full_name,
  //             email
  //           )
  //         ''')
  //         .eq('campaign_id', campaignId)
  //         .order('created_at', ascending: false)
  //         .limit(10);

  //     return List<Map<String, dynamic>>.from(response);
  //   } catch (e) {
  //     print('Error fetching recent donors: $e');
  //     return [];
  //   }
  // }
}
