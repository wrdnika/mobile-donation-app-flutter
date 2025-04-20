import 'package:supabase_flutter/supabase_flutter.dart';

class DonationReportService {
  static final SupabaseClient supabase = Supabase.instance.client;

  static Future<List<Map<String, dynamic>>> getDonationReports() async {
    final response = await supabase
        .from('donation_reports')
        .select(
            'id, campaign_id, report_description, report_image, created_at, campaigns(title)')
        .order('created_at', ascending: false);

    if (response.isEmpty) {
      return [];
    }

    return response.map((report) {
      return {
        'id': report['id'],
        'campaign_title': report['campaigns']['title'],
        'report_description': report['report_description'],
        'report_image': report['report_image'],
        'created_at': report['created_at'],
      };
    }).toList();
  }
}
