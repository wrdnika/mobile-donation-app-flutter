import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/donation_report_service.dart';

class DonationReportScreen extends StatefulWidget {
  @override
  _DonationReportScreenState createState() => _DonationReportScreenState();
}

class _DonationReportScreenState extends State<DonationReportScreen> {
  late Future<List<Map<String, dynamic>>> _reportsFuture;

  @override
  void initState() {
    super.initState();
    _loadReports();
  }

  void _loadReports() {
    setState(() {
      _reportsFuture = DonationReportService.getDonationReports();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () async {
          _loadReports();
        },
        child: FutureBuilder<List<Map<String, dynamic>>>(
          future: _reportsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Center(child: CircularProgressIndicator());
            } else if (snapshot.hasError) {
              return Center(child: Text('Error: ${snapshot.error}'));
            } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return Center(child: Text('Belum ada laporan donasi.'));
            } else {
              final reports = snapshot.data!;
              return ListView.builder(
                padding: EdgeInsets.all(8.0),
                itemCount: reports.length,
                itemBuilder: (context, index) {
                  final report = reports[index];
                  final campaignTitle = report['campaign_title'] ?? 'Unknown';
                  final collectedAmount =
                      report['campaign_collected_amount'] ?? 0;
                  final goalAmount = report['campaign_goal_amount'] ?? 0;
                  final reportDate = DateTime.parse(report['created_at']);
                  final imageUrl = report['report_image'] ?? '';
                  final description =
                      report['report_description'] ?? 'Tidak ada deskripsi.';

                  return Card(
                    margin: EdgeInsets.symmetric(vertical: 8.0),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12.0),
                    ),
                    elevation: 6,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (imageUrl.isNotEmpty)
                          ClipRRect(
                            borderRadius: BorderRadius.vertical(
                                top: Radius.circular(12.0)),
                            child: Image.network(imageUrl, fit: BoxFit.cover),
                          ),
                        Padding(
                          padding: EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                campaignTitle,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                  color: Colors.green[800],
                                ),
                              ),
                              SizedBox(height: 8),
                              Text(
                                'Terkumpul dan tersalurkan: Rp${NumberFormat('#,##0', 'id_ID').format(collectedAmount)} dari Target: Rp${NumberFormat('#,##0', 'id_ID').format(goalAmount)}',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[700],
                                ),
                              ),
                              SizedBox(height: 8),
                              Text(
                                'Tanggal: ${DateFormat('dd MMM yyyy').format(reportDate)}',
                              ),
                              SizedBox(height: 8),
                              Text(description),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              );
            }
          },
        ),
      ),
    );
  }
}
