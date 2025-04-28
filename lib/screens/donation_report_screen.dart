import 'dart:async';
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
                  final List<String> imageUrls =
                      List<String>.from(report['report_image'] ?? []);
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
                        if (imageUrls.isNotEmpty)
                          ImageSlider(imageUrls: imageUrls),
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
                                  'Tanggal: ${DateFormat('dd MMM yyyy').format(reportDate)}'),
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

class ImageSlider extends StatefulWidget {
  final List<String> imageUrls;
  ImageSlider({required this.imageUrls});

  @override
  _ImageSliderState createState() => _ImageSliderState();
}

class _ImageSliderState extends State<ImageSlider> {
  late PageController _pageController;
  Timer? _timer;
  int _currentPage = 0;
  bool _isManualSwipe = false;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: 0);
    _startAutoPlay();
  }

  void _startAutoPlay() {
    _timer = Timer.periodic(Duration(seconds: 3), (timer) {
      if (!_isManualSwipe) {
        _currentPage++;
        if (_currentPage >= widget.imageUrls.length) {
          _currentPage = 0;
        }
        if (mounted) {
          _pageController.animateToPage(
            _currentPage,
            duration: Duration(milliseconds: 300),
            curve: Curves.easeInOut,
          );
        }
      }
    });
  }

  void _stopAutoPlay() {
    _timer?.cancel();
  }

  @override
  void dispose() {
    _stopAutoPlay();
    _pageController.dispose();
    super.dispose();
  }

  void _openFullScreenImage(String imageUrl, int index) {
    _stopAutoPlay();
    _isManualSwipe = true;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            FullScreenImagePage(imageUrl: imageUrl, tag: 'image_$index'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        SizedBox(
          height: 200,
          child: PageView.builder(
            controller: _pageController,
            itemCount: widget.imageUrls.length,
            onPageChanged: (index) {
              _currentPage = index;
              _isManualSwipe = true;
              _stopAutoPlay();
            },
            itemBuilder: (context, index) {
              return GestureDetector(
                onTap: () =>
                    _openFullScreenImage(widget.imageUrls[index], index),
                child: Hero(
                  tag: 'image_$index',
                  child: ClipRRect(
                    borderRadius:
                        BorderRadius.vertical(top: Radius.circular(12.0)),
                    child: Image.network(
                      widget.imageUrls[index],
                      fit: BoxFit.cover,
                      width: double.infinity,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        Positioned(
          left: 10,
          child: IconButton(
            icon: Icon(Icons.arrow_back_ios, color: Colors.white),
            onPressed: () {
              _stopAutoPlay();
              _isManualSwipe = true;
              _currentPage = (_currentPage - 1 + widget.imageUrls.length) %
                  widget.imageUrls.length;
              _pageController.animateToPage(
                _currentPage,
                duration: Duration(milliseconds: 300),
                curve: Curves.easeInOut,
              );
            },
          ),
        ),
        Positioned(
          right: 10,
          child: IconButton(
            icon: Icon(Icons.arrow_forward_ios, color: Colors.white),
            onPressed: () {
              _stopAutoPlay();
              _isManualSwipe = true;
              _currentPage = (_currentPage + 1) % widget.imageUrls.length;
              _pageController.animateToPage(
                _currentPage,
                duration: Duration(milliseconds: 300),
                curve: Curves.easeInOut,
              );
            },
          ),
        ),
      ],
    );
  }
}

class FullScreenImagePage extends StatelessWidget {
  final String imageUrl;
  final String tag;

  FullScreenImagePage({required this.imageUrl, required this.tag});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTap: () => Navigator.pop(context),
        child: Center(
          child: Hero(
            tag: tag,
            child: InteractiveViewer(
              child: Image.network(imageUrl),
            ),
          ),
        ),
      ),
    );
  }
}
