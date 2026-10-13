import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseService {
  static const String supabaseUrl = 'https://qnbxbzpvjkwfmnvblqys.supabase.co';
  static const String supabaseAnonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InFuYnhienB2amt3Zm1udmJscXlzIiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTE1NjM4MjEsImV4cCI6MjEwNzEzOTgyMX0.DtnStii_kcaib5LZo8Sm0QCAFdGFEsrMSZTcs9rn7-E';

  // URL pública de la webapp de tarjetas (dominio fijo en Vercel).
  static const String webAppUrl = 'https://tender-tarjetas.vercel.app';

  static bool _ready = false;

  /// False cuando la app arrancó sin internet y el cliente aún no existe.
  static bool get isReady => _ready;

  static Future<void> init() async {
    if (_ready) return;
    await Supabase.initialize(url: supabaseUrl, anonKey: supabaseAnonKey);
    _ready = true;
  }

  static SupabaseClient get client => Supabase.instance.client;

  static Stream<AuthState> get authStateChanges =>
      client.auth.onAuthStateChange;

  static User? get currentUser => _ready ? client.auth.currentUser : null;
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

  static Future<void> resendConfirmation(String email) =>
      client.auth.resend(type: OtpType.signup, email: email.trim());

  /// Envía el correo para restablecer la contraseña. El enlace abre la
  /// webapp de facturas cuando esté publicada.
  static Future<void> sendPasswordReset(String email) => client.auth
      .resetPasswordForEmail(email.trim(), redirectTo: webAppUrl);

  static Future<void> signOut() => client.auth.signOut();

  /// Sube (o actualiza) las tarjetas digitales de los clientes de la tienda.
  /// [rows] lleva: id local, name, phone, stamps_total, rewards_available.
  static Future<int> syncCustomers(
      String storeId, List<Map<String, dynamic>> rows) async {
    if (rows.isEmpty) return 0;
    final now = DateTime.now().toUtc().toIso8601String();
    final payload = rows
        .map((row) => {
              'id': '${storeId}_${row['id']}',
              'store_id': storeId,
              'name': row['name'] ?? '',
              'phone': row['phone'],
              'stamps_total': row['stamps_total'] ?? 0,
              'rewards_available': row['rewards_available'] ?? 0,
              'updated_at': now,
            })
        .toList();
    await client.from('customers').upsert(payload, onConflict: 'id');
    return payload.length;
  }

  static Future<List<Map<String, dynamic>>> fetchCustomers(
      String storeId) async {
    final rows = await client
        .from('customers')
        .select()
        .eq('store_id', storeId)
        .order('updated_at', ascending: false);
    return rows;
  }

  /// Sube las compras recientes con cliente asignado (se ven en la web).
  /// [rows]: id de la venta, phone, name, total, items_count,
  /// payment_method, sold_at.
  static Future<int> syncPurchases(
      String storeId, List<Map<String, dynamic>> rows) async {
    if (rows.isEmpty) return 0;
    final payload = rows
        .map((row) => {
              'id': '${storeId}_${row['id']}',
              'store_id': storeId,
              'customer_phone': row['phone'],
              'customer_name': row['name'],
              'total': row['total'],
              'items_count': row['items_count'],
              'payment_method': row['payment_method'],
              'sold_at': row['sold_at'],
            })
        .toList();
    await client.from('purchases').upsert(payload, onConflict: 'id');
    return payload.length;
  }

  /// Vincula la instalación con la tienda del usuario autenticado.
  /// Si la cuenta ya tiene tienda, devuelve su id remoto (para adoptarlo);
  /// si no, registra la tienda local. También publica la regla de
  /// fidelización (meta y premio) para que la webapp la muestre.
  static Future<String> syncStore(String localStoreId, String name,
      {int? loyaltyGoal, String? loyaltyReward}) async {
    final uid = currentUser!.id;
    final data = <String, dynamic>{
      'name': name,
      if (loyaltyGoal != null) 'loyalty_goal': loyaltyGoal,
      if (loyaltyReward != null) 'loyalty_reward': loyaltyReward,
    };
    final existing = await client
        .from('stores')
        .select('id')
        .eq('owner_id', uid)
        .limit(1)
        .maybeSingle();
    if (existing != null) {
      final remoteId = existing['id'] as String;
      await client.from('stores').update(data).eq('id', remoteId);
      return remoteId;
    }
    try {
      await client
          .from('stores')
          .insert({'id': localStoreId, 'owner_id': uid, ...data});
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
