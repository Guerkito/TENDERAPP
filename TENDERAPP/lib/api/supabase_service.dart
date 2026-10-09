import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseService {
  static const String supabaseUrl = 'https://qnbxbzpvjkwfmnvblqys.supabase.co';
  static const String supabaseAnonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InFuYnhienB2amt3Zm1udmJscXlzIiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTE1NjM4MjEsImV4cCI6MjEwNzEzOTgyMX0.DtnStii_kcaib5LZo8Sm0QCAFdGFEsrMSZTcs9rn7-E';

  // Cambiar cuando la webapp de facturas esté publicada (Netlify/Vercel).
  static const String webAppUrl = 'https://TU-WEBAPP-AQUI';

  static Future<void> init() async {
    await Supabase.initialize(url: supabaseUrl, anonKey: supabaseAnonKey);
  }

  static SupabaseClient get client => Supabase.instance.client;

  static User? get currentUser => client.auth.currentUser;
  static bool get isLoggedIn => currentUser != null;
  static String? get currentEmail => currentUser?.email;

  static Future<void> signIn(String email, String password) async {
    await client.auth
        .signInWithPassword(email: email.trim(), password: password);
  }

  /// Devuelve true si la sesión quedó activa (sin confirmación por correo).
  static Future<bool> signUp(String email, String password) async {
    final res = await client.auth
        .signUp(email: email.trim(), password: password);
    return res.session != null;
  }

  static Future<void> signOut() => client.auth.signOut();

  /// Vincula la instalación con la tienda del usuario autenticado.
  /// Si la cuenta ya tiene tienda, devuelve su id remoto (para adoptarlo);
  /// si no, registra la tienda local.
  static Future<String> syncStore(String localStoreId, String name) async {
    final uid = currentUser!.id;
    final existing = await client
        .from('stores')
        .select('id')
        .eq('owner_id', uid)
        .limit(1)
        .maybeSingle();
    if (existing != null) {
      final remoteId = existing['id'] as String;
      await client.from('stores').update({'name': name}).eq('id', remoteId);
      return remoteId;
    }
    try {
      await client
          .from('stores')
          .insert({'id': localStoreId, 'name': name, 'owner_id': uid});
      return localStoreId;
    } catch (e) {
      final again = await client
          .from('stores')
          .select('id')
          .eq('owner_id', uid)
          .limit(1)
          .maybeSingle();
      if (again != null) return again['id'] as String;
      rethrow;
    }
  }

  static Future<List<Map<String, dynamic>>> fetchPendingSubmissions(
      String storeId) async {
    final rows = await client
        .from('receipt_submissions')
        .select()
        .eq('store_id', storeId)
        .eq('status', 'pending')
        .order('submitted_at', ascending: true);

    final result = <Map<String, dynamic>>[];
    for (final row in rows) {
      String? photoUrl;
      try {
        photoUrl = await client.storage
            .from('invoices')
            .createSignedUrl(row['photo_path'] as String, 3600);
      } catch (e) {
        debugPrint('SupabaseService: no se pudo firmar la foto: $e');
      }
      result.add({...row, 'photo_url': photoUrl});
    }
    return result;
  }

  static Future<void> reviewSubmission(String id,
      {required bool approved}) async {
    await client.from('receipt_submissions').update({
      'status': approved ? 'approved' : 'rejected',
      'reviewed_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', id);
  }
}
