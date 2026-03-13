import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'user_auth.dart';

final openPricesClientProvider =
    NotifierProvider<_OpenPricesClientNotifier, OpenPricesClient>(
  _OpenPricesClientNotifier.new,
);

class _OpenPricesClientNotifier extends Notifier<OpenPricesClient> {
  @override
  OpenPricesClient build() => OpenPricesClient();
}

class OpenPricesClient {
  static const String _baseUrl = 'https://prices.openfoodfacts.org/api/v1';
  String? _accessToken;

  Map<String, String> _getHeaders(OffCredentials? credentials) {
    final headers = {
      'User-Agent': 'ComparateurApp/1.0.0 (contact@example.com)',
      'Accept': 'application/json',
    };
    
    if (_accessToken != null) {
      headers['Authorization'] = 'Bearer $_accessToken';
    } else if (credentials != null && credentials.isValid) {
      final auth = base64Encode(utf8.encode('${credentials.username}:${credentials.password}'));
      headers['Authorization'] = 'Basic $auth';
    }
    return headers;
  }

  Future<void> _ensureAuthenticated(OffCredentials? credentials) async {
    if (_accessToken != null) return;
    if (credentials == null || !credentials.isValid) return;
    await login(credentials.username, credentials.password);
  }

  Future<bool> login(String username, String password) async {
    final url = Uri.parse('$_baseUrl/auth');
    try {
      final response = await http.post(
        url,
        headers: {
          'User-Agent': 'ComparateurApp/1.0.0 (contact@example.com)',
          'Content-Type': 'application/x-www-form-urlencoded',
          'Accept': 'application/json',
        },
        body: {
          'username': username,
          'password': password,
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        _accessToken = data['access_token'] as String?;
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  Future<List<OpenPrice>> fetchPrices(String barcode) async {
    final now = DateTime.now();
    final twoMonthsAgo = now.subtract(const Duration(days: 60));
    final dateString = "${twoMonthsAgo.year}-${twoMonthsAgo.month.toString().padLeft(2, '0')}-${twoMonthsAgo.day.toString().padLeft(2, '0')}";
    
    final url = Uri.parse('$_baseUrl/prices?product_code=$barcode&date__gte=$dateString');
    
    try {
      final response = await http.get(
        url,
        headers: _getHeaders(null),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List<dynamic> items = data['items'] ?? [];
        
        return items
            .map((item) => OpenPrice.fromJson(item))
            .where((price) => price.date.isAfter(twoMonthsAgo))
            .toList();
      }
    } catch (e) {
      // ignore: avoid_print
      print('Error fetching Open Prices: $e');
    }
    return [];
  }

  Future<int?> uploadReceipt(File file, {OffCredentials? credentials}) async {
    await _ensureAuthenticated(credentials);
    
    final url = Uri.parse('$_baseUrl/proofs/upload');
    final request = http.MultipartRequest('POST', url);
    
    request.headers.addAll(_getHeaders(credentials));
    request.fields['type'] = 'RECEIPT';
    
    try {
      final multiPartFile = await http.MultipartFile.fromPath(
        'file',
        file.path,
        contentType: MediaType('image', 'jpeg'),
      );
      request.files.add(multiPartFile);

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 201 || response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final rawId = data['id'];
        if (rawId is int) return rawId;
        if (rawId is String) return int.tryParse(rawId);
        return null;
      } else {
        throw Exception('Serveur (Code ${response.statusCode}) : ${response.body}');
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<List<ReceiptItem>> getReceiptItems(int proofId, {OffCredentials? credentials}) async {
    await _ensureAuthenticated(credentials);
    
    final url = Uri.parse('$_baseUrl/receipt-items?proof_id=$proofId');
    
    try {
      final response = await http.get(
        url,
        headers: _getHeaders(credentials),
      );

      if (response.statusCode == 200) {
        final dynamic decoded = jsonDecode(response.body);
        List<dynamic> items = [];
        
        if (decoded is List) {
          items = decoded;
        } else if (decoded is Map && decoded['items'] != null) {
          items = decoded['items'] as List;
        }
        
        return items.map((item) => ReceiptItem.fromJson(item)).toList();
      }
    } catch (e) {
      // ignore: avoid_print
      print('Error getting receipt items: $e');
    }
    return [];
  }
}

class ReceiptItem {
  final int id;
  final String? productName;
  final String? barcode;
  final double? price;
  final int? quantity;

  ReceiptItem({
    required this.id,
    this.productName,
    this.barcode,
    this.price,
    this.quantity,
  });

  factory ReceiptItem.fromJson(Map<String, dynamic> json) {
    final predicted = json['predicted_data'] as Map<String, dynamic>? ?? {};
    
    return ReceiptItem(
      id: json['id'] as int,
      productName: predicted['product_name'] as String? ?? predicted['category'] as String?,
      barcode: predicted['product_code'] as String?,
      price: predicted['price'] != null 
          ? (predicted['price'] as num).toDouble() 
          : (predicted['price_total'] != null ? (predicted['price_total'] as num).toDouble() : null),
      quantity: predicted['quantity'] is num ? (predicted['quantity'] as num).toInt() : null,
    );
  }
}

class OpenPrice {
  final double price;
  final String currency;
  final String? storeName;
  final String? city;
  final String? address;
  final DateTime date;

  OpenPrice({
    required this.price,
    required this.currency,
    this.storeName,
    this.city,
    this.address,
    required this.date,
  });

  factory OpenPrice.fromJson(Map<String, dynamic> json) {
    String? storeName;
    String? city;
    String? address;
    
    if (json['location'] != null && json['location'] is Map) {
      final loc = json['location'] as Map<String, dynamic>;
      storeName = loc['name'] ?? loc['osm_name'];
      city = loc['city'] as String?;
      address = loc['address'] as String?;
    }
    
    storeName ??= json['store_name'] ?? json['location_name'];
    
    return OpenPrice(
      price: (json['price'] as num).toDouble(),
      currency: json['currency'] as String,
      storeName: storeName,
      city: city,
      address: address,
      date: DateTime.parse(json['date'] as String),
    );
  }
}
