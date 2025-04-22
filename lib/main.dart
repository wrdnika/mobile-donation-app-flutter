import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'screens/login_screen.dart';
import 'services/transaction_service.dart';
import 'dart:async';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await dotenv.load();

  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL'] ?? '',
    anonKey: dotenv.env['SUPABASE_SERVICE_ROLE_KEY'] ?? '',
  );

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  Timer? _expiryCheckTimer;

  @override
  void initState() {
    super.initState();
    // Set up a timer to check for expired transactions every minute
    _expiryCheckTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      _checkExpiredTransactions();
    });
  }

  @override
  void dispose() {
    _expiryCheckTimer?.cancel();
    super.dispose();
  }

  Future<void> _checkExpiredTransactions() async {
    // Check if user is authenticated before checking transactions
    final user = Supabase.instance.client.auth.currentUser;
    if (user != null) {
      await TransactionService.checkAndUpdateExpiredTransactions();
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'IKBS Crowdfunding',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const LoginScreen(),
    );
  }
}
