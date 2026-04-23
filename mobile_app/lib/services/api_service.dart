import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

import '../config.dart';
import '../models/models.dart';

class ApiException implements Exception {
  final String message;
  ApiException(this.message);
  @override
  String toString() => 'ApiException: $message';
}

/// Thin client over the Google Apps Script web app.
/// Mirrors the exact actions the web portal uses.
class ApiService {
  static final ApiService instance = ApiService._();
  ApiService._();

  final _base = Uri.parse(AppConfig.scriptUrl);

  // ---------- low level ----------

  Future<Map<String, dynamic>> _get(Map<String, String> params) async {
    final uri = _base.replace(queryParameters: params);
    final res = await http.get(uri).timeout(const Duration(seconds: 30));
    if (res.statusCode != 200) {
      throw ApiException('HTTP ${res.statusCode}');
    }
    final body = res.body.trim();
    final decoded = jsonDecode(body);
    if (decoded is! Map<String, dynamic>) {
      throw ApiException('Unexpected response');
    }
    if ((decoded['status'] ?? 'success') != 'success') {
      throw ApiException((decoded['message'] ?? 'Error').toString());
    }
    return decoded;
  }

  /// Apps Script always responds to doPost with a 302 to
  /// script.googleusercontent.com. Dart's HttpClient refuses to follow
  /// redirects on POST (per the HTTP spec), so we follow it by hand.
  Future<Map<String, dynamic>> _post(Map<String, String> body) async {
    final client = http.Client();
    try {
      final req = http.Request('POST', _base)
        ..headers['Content-Type'] = 'application/x-www-form-urlencoded'
        ..followRedirects = false
        ..bodyFields = body;
      var streamed =
          await client.send(req).timeout(const Duration(seconds: 45));

      var hops = 0;
      while ((streamed.statusCode == 301 ||
              streamed.statusCode == 302 ||
              streamed.statusCode == 303 ||
              streamed.statusCode == 307 ||
              streamed.statusCode == 308) &&
          hops < 6) {
        final loc = streamed.headers['location'];
        if (loc == null || loc.isEmpty) break;
        final next = Uri.parse(loc);
        final getReq = http.Request('GET', next)..followRedirects = false;
        streamed =
            await client.send(getReq).timeout(const Duration(seconds: 45));
        hops++;
      }

      final res = await http.Response.fromStream(streamed);
      if (res.statusCode != 200) {
        throw ApiException('HTTP ${res.statusCode}');
      }
      final decoded = jsonDecode(res.body.trim());
      if (decoded is! Map<String, dynamic>) {
        throw ApiException('Unexpected response');
      }
      if ((decoded['status'] ?? 'success') != 'success') {
        throw ApiException((decoded['message'] ?? 'Error').toString());
      }
      return decoded;
    } finally {
      client.close();
    }
  }

  // ---------- users ----------

  Future<Map<String, AppUser>> getUsers() async {
    final d = await _get({'action': 'getUsers'});
    final raw = d['users'];
    final out = <String, AppUser>{};
    if (raw is Map) {
      raw.forEach((k, v) {
        if (v is Map) {
          final username = k.toString().trim();
          if (username.isEmpty) return;
          out[username] = AppUser(
            username: username,
            password: (v['password'] ?? '').toString().trim(),
            role: (v['role'] ?? 'user').toString().trim().toLowerCase(),
            displayName: ((v['displayName'] ?? '').toString().trim().isEmpty
                    ? username
                    : v['displayName'])
                .toString()
                .trim(),
          );
        }
      });
    }
    return out;
  }

  Future<void> addUser({
    required String username,
    required String password,
    required String role,
    required String displayName,
  }) =>
      _post({
        'action': 'addUser',
        'username': username,
        'password': password,
        'role': role,
        'displayName': displayName,
      });

  Future<void> deleteUser(String username) =>
      _post({'action': 'deleteUser', 'username': username});

  // ---------- employees ----------

  Future<List<Employee>> getEmployees() async {
    final d = await _get({'action': 'getEmployees'});
    final raw = d['employees'] ?? d['data'] ?? [];
    return (raw as List)
        .map((e) => Employee.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<void> addEmployee(Employee e) => _post({
        'action': 'addEmployee',
        'empId': e.id,
        'empName': e.name,
        'role': e.role,
      });

  Future<void> editEmployee(Employee e) => _post({
        'action': 'editEmployee',
        'empId': e.id,
        'empName': e.name,
        'role': e.role,
      });

  Future<void> deleteEmployee(String empId) =>
      _post({'action': 'deleteEmployee', 'empId': empId});

  // ---------- status ----------

  Future<List<StatusRecord>> getStatus({String? date}) async {
    final d = await _get({
      'action': 'getStatus',
      if (date != null && date.isNotEmpty) 'date': date,
    });
    final list = (d['data'] as List? ?? []);
    return list
        .map((e) => StatusRecord.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<List<StatusRecord>> getStatusRange({
    required String from,
    required String to,
    String empId = 'ALL',
  }) async {
    final d = await _get({
      'action': 'getStatusRange',
      'from': from,
      'to': to,
      'empId': empId,
    });
    final list = (d['data'] as List? ?? []);
    return list
        .map((e) => StatusRecord.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<void> submitStatus({
    required String empId,
    required String empName,
    required String role,
    required String siteName,
    required String workType,
    required String scopeOfWork,
    required String status,
    required String date,
  }) =>
      _post({
        'action': 'submitStatus',
        'empId': empId,
        'empName': empName,
        'role': role,
        'siteName': siteName,
        'workType': workType,
        'scopeOfWork': scopeOfWork,
        'status': status,
        'date': date,
      });

  Future<void> updateWorkDone({
    required String empId,
    required String date,
    String workDone = '',
    String completionPct = '',
    String workRemarks = '',
    String nextVisitRequired = '',
    String nextVisitDate = '',
    String instructionFrom = '',
    String inspectedBy = '',
    String customerName = '',
    String designation = '',
    String phone = '',
    String email = '',
  }) =>
      _post({
        'action': 'updateWorkDone',
        'empId': empId,
        'date': date,
        'workDone': workDone,
        'completionPct': completionPct,
        'workRemarks': workRemarks,
        'nextVisitRequired': nextVisitRequired,
        'nextVisitDate': nextVisitDate,
        'instructionFrom': instructionFrom,
        'inspectedBy': inspectedBy,
        'customerName': customerName,
        'designation': designation,
        'phone': phone,
        'email': email,
      });

  // ---------- sites ----------

  Future<List<Site>> getSites() async {
    final d = await _get({'action': 'getSites'});
    final list = (d['data'] as List? ?? []);
    return list
        .map((e) => Site.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<void> addSite(Site s) => _post({
        'action': 'addSite',
        'name': s.name,
        'id': s.id,
        'address': s.address,
        'city': s.city,
        'state': s.state,
        'zipCode': s.zipCode,
        'contactName': s.contactName,
        'contactPhone': s.contactPhone,
        'contactEmail': s.contactEmail,
      });

  // ---------- signatures ----------

  Future<Map<String, String>> getReportSignatures({
    required String empId,
    required String date,
  }) async {
    final d = await _get({
      'action': 'getReportSignatures',
      'empId': empId,
      'date': date,
    });
    return {
      'custSig': (d['custSig'] ?? '').toString(),
      'engSig': (d['engSig'] ?? '').toString(),
    };
  }

  Future<void> saveReportSignatures({
    required String empId,
    required String date,
    required String custSig,
    required String engSig,
  }) =>
      _post({
        'action': 'saveReportSignatures',
        'empId': empId,
        'date': date,
        'custSig': custSig,
        'engSig': engSig,
      });

  Future<void> saveServiceReport(Map<String, String> report) =>
      _post({'action': 'saveServiceReport', ...report});

  // ---------- inventory ----------

  Future<List<InventoryItem>> getInventory() async {
    final d = await _get({'action': 'getInventory'});
    final list = (d['data'] as List? ?? []);
    return list
        .map((e) => InventoryItem.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<void> addInventory(InventoryItem it, String updatedBy) => _post({
        'action': 'addInventory',
        'itemId': it.itemId,
        'name': it.name,
        'category': it.category,
        'qty': it.qty.toString(),
        'minStock': it.minStock.toString(),
        'unit': it.unit,
        'location': it.location,
        'description': it.description,
        'updatedBy': updatedBy,
      });

  Future<void> editInventory(InventoryItem it, String updatedBy) => _post({
        'action': 'editInventory',
        'itemId': it.itemId,
        'name': it.name,
        'category': it.category,
        'qty': it.qty.toString(),
        'minStock': it.minStock.toString(),
        'unit': it.unit,
        'location': it.location,
        'description': it.description,
        'updatedBy': updatedBy,
      });

  Future<void> deleteInventory(String itemId) =>
      _post({'action': 'deleteInventory', 'itemId': itemId});

  Future<void> invTransaction({
    required String itemId,
    required String itemName,
    required num qty,
    required String type,
    String siteName = '',
    String empName = '',
    String remarks = '',
    String purpose = '',
    String updatedBy = '',
  }) =>
      _post({
        'action': 'invTransaction',
        'itemId': itemId,
        'itemName': itemName,
        'qty': qty.toString(),
        'type': type,
        'siteName': siteName,
        'empName': empName,
        'remarks': remarks,
        'purpose': purpose,
        'updatedBy': updatedBy,
      });

  Future<List<SerialNumber>> getSerialNumbers() async {
    final d = await _get({'action': 'getSerialNumbers'});
    final list = (d['data'] as List? ?? []);
    return list
        .map((e) => SerialNumber.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<void> addSerialNumber({
    required String serialNo,
    required String itemId,
    required String itemName,
    String status = 'Available',
  }) =>
      _post({
        'action': 'addSerialNumber',
        'serialNo': serialNo,
        'itemId': itemId,
        'itemName': itemName,
        'status': status,
      });

  Future<void> updateSerialStatus({
    required String serialNo,
    required String status,
    String siteName = '',
    String issuedTo = '',
  }) =>
      _post({
        'action': 'updateSerialStatus',
        'serialNo': serialNo,
        'status': status,
        'siteName': siteName,
        'issuedTo': issuedTo,
      });

  Future<List<InventoryLogEntry>> getInventoryLog() async {
    final d = await _get({'action': 'getInventoryLog'});
    final list = (d['data'] as List? ?? []);
    return list
        .map((e) => InventoryLogEntry.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }
}
