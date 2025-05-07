import 'package:supabase_flutter/supabase_flutter.dart';

class DonationReportService {
  static final SupabaseClient supabase = Supabase.instance.client;

  static Future<List<Map<String, dynamic>>> getDonationReports() async {
    final response = await supabase.from('donation_reports').select('''
      id, 
      campaign_id, 
      report_description, 
      report_image, 
      report_pdf,
      created_at, 
      campaigns(
        title, 
        collected_amount, 
        goal_amount
      )
    ''').order('created_at', ascending: false);

    if (response.isEmpty) return [];

    return response.map((report) {
      return {
        'id': report['id'],
        'campaign_title': report['campaigns']['title'],
        'campaign_collected_amount': report['campaigns']['collected_amount'],
        'campaign_goal_amount': report['campaigns']['goal_amount'],
        'report_description': report['report_description'],
        'report_image': List<String>.from(report['report_image'] ?? []),
        'report_pdf': report['report_pdf'] as String?,
        'created_at': report['created_at'],
      };
    }).toList();
  }
}
