import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class AuthService {
  static final SupabaseClient _client = Supabase.instance.client;

  static Future<bool> login(String email, String password) async {
    try {
      final response = await _client.auth.signInWithPassword(
        email: email,
        password: password,
      );

      if (response.session != null) {
        final user = response.session!.user;

        if (user.emailConfirmedAt == null) {
          print('Login gagal: Email belum terverifikasi.');
          return false;
        }

        print('Login berhasil: ${user.id}');
        return true;
      } else {
        print('Login gagal');
        return false;
      }
    } catch (e) {
      print('Error saat login: $e');
      return false;
    }
  }

  static Future<bool> register(
      String email, String password, String fullName, String phone) async {
    try {
      final redirectUrl = dotenv.env['SUPABASE_REDIRECT_URL_REGIST'] ?? '';

      final response = await _client.auth.signUp(
        email: email,
        password: password,
        emailRedirectTo: redirectUrl,
      );

      if (response.user != null) {
        await _client.from('profiles').insert({
          'id': response.user!.id,
          'full_name': fullName,
          'phone': phone,
        });

        print('Registrasi berhasil! Email verifikasi dikirim ke: $email');
        return true;
      } else {
        print(
            'Registrasi gagal: ${response.error?.message ?? "Unknown error"}');
        return false;
      }
    } catch (e) {
      print('Error saat registrasi: $e');
      return false;
    }
  }

  static Future<bool> resetPassword(String email) async {
    if (email.isEmpty || !email.contains('@')) {
      print('Email tidak valid.');
      return false;
    }

    try {
      final redirectUrl = dotenv.env['SUPABASE_REDIRECT_URL_RESET'] ?? '';
      print('Mencoba reset password untuk: $email');
      print('Menggunakan redirect URL: $redirectUrl');

      await _client.auth.resetPasswordForEmail(
        email,
        redirectTo: redirectUrl,
      );

      print('Link reset password dikirim ke $email');
      return true;
    } catch (e) {
      print('Error detail saat kirim link reset password: $e');
      print(StackTrace.current);
      return false;
    }
  }

  static Future<void> logout() async {
    try {
      await _client.auth.signOut();
      print('Logout berhasil');
    } catch (e) {
      print('Error saat logout: $e');
    }
  }
}

extension on AuthResponse {
  get error => null;
}
