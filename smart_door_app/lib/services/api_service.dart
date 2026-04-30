// api_service.dart — All REST API calls
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import '../config/api_config.dart';
import '../models/alert_model.dart';
import '../models/log_model.dart';
import '../models/person_model.dart';
import '../models/user_model.dart';
import 'auth_service.dart';

class ApiService {
  final _auth = AuthService();

  Future<Map<String, String>> get _headers => _auth.authHeaders();

  // ─── Door ────────────────────────────────────────────────────────────────
  Future<Map<String, dynamic>> getDoorStatus() async {
    final resp = await http.get(Uri.parse(ApiConfig.doorStatus), headers: await _headers);
    _check(resp);
    return jsonDecode(resp.body);
  }

  Future<void> lockDoor() async {
    final resp = await http.post(Uri.parse(ApiConfig.doorLock), headers: await _headers);
    _check(resp);
  }

  Future<void> unlockDoor() async {
    final resp = await http.post(Uri.parse(ApiConfig.doorUnlock), headers: await _headers);
    _check(resp);
  }

  // ─── Alerts ──────────────────────────────────────────────────────────────
  Future<List<AlertModel>> getAlerts({String? status}) async {
    var url = ApiConfig.alerts;
    if (status != null) url += '?status=$status';
    final resp = await http.get(Uri.parse(url), headers: await _headers);
    _check(resp);
    return (jsonDecode(resp.body) as List).map((e) => AlertModel.fromJson(e)).toList();
  }

  Future<void> approveAlert(int id) async {
    final resp = await http.post(Uri.parse(ApiConfig.alertApprove(id)), headers: await _headers);
    _check(resp);
  }

  Future<void> rejectAlert(int id) async {
    final resp = await http.post(Uri.parse(ApiConfig.alertReject(id)), headers: await _headers);
    _check(resp);
  }

  // ─── Logs ────────────────────────────────────────────────────────────────
  Future<List<LogModel>> getLogs({String? type}) async {
    var url = ApiConfig.logs;
    if (type != null) url += '?type=$type';
    final resp = await http.get(Uri.parse(url), headers: await _headers);
    _check(resp);
    return (jsonDecode(resp.body) as List).map((e) => LogModel.fromJson(e)).toList();
  }

  // ─── Persons ─────────────────────────────────────────────────────────────
  Future<List<PersonModel>> getPersons() async {
    final resp = await http.get(Uri.parse(ApiConfig.persons), headers: await _headers);
    _check(resp);
    return (jsonDecode(resp.body) as List).map((e) => PersonModel.fromJson(e)).toList();
  }

  Future<PersonModel> addPerson(String name, XFile photoFile) async {
    final token = await _auth.getToken();
    final request = http.MultipartRequest('POST', Uri.parse(ApiConfig.persons))
      ..headers['Authorization'] = 'Bearer $token'
      ..fields['name'] = name;
      
    final bytes = await photoFile.readAsBytes();
    request.files.add(http.MultipartFile.fromBytes(
      'photo', 
      bytes, 
      filename: photoFile.name.isNotEmpty ? photoFile.name : 'upload.jpg',
    ));
    
    final streamed = await request.send();
    final resp = await http.Response.fromStream(streamed);
    _check(resp);
    return PersonModel.fromJson(jsonDecode(resp.body));
  }

  Future<void> deletePerson(int id) async {
    final resp = await http.delete(Uri.parse('${ApiConfig.persons}/$id'), headers: await _headers);
    _check(resp);
  }

  // ─── Users ───────────────────────────────────────────────────────────────
  Future<List<UserModel>> getUsers() async {
    final resp = await http.get(Uri.parse(ApiConfig.users), headers: await _headers);
    _check(resp);
    return (jsonDecode(resp.body) as List).map((e) => UserModel.fromJson(e)).toList();
  }

  Future<Map<String, dynamic>> createInvite(String role, {String? email}) async {
    final resp = await http.post(
      Uri.parse(ApiConfig.createInvite),
      headers: await _headers,
      body: jsonEncode({'role': role, 'email': email}),
    );
    _check(resp);
    return jsonDecode(resp.body);
  }

  Future<void> deleteUser(int id) async {
    final resp = await http.delete(Uri.parse('${ApiConfig.users}/$id'), headers: await _headers);
    _check(resp);
  }

  Future<void> updateUserRole(int id, String role) async {
    final resp = await http.patch(
      Uri.parse('${ApiConfig.users}/$id'),
      headers: await _headers,
      body: jsonEncode({'role': role}),
    );
    _check(resp);
  }

  // ─── Auth ────────────────────────────────────────────────────────────────
  Future<void> setupPin(String pin) async {
    final resp = await http.post(
      Uri.parse(ApiConfig.setupPin),
      headers: await _headers,
      body: jsonEncode({'pin': pin}),
    );
    _check(resp);
  }

  Future<List<int>> setupTotp() async {
    final resp = await http.post(Uri.parse(ApiConfig.setupTotp), headers: await _headers);
    _check(resp);
    return resp.bodyBytes;
  }

  Future<void> updateFcmToken(String token) async {
    final resp = await http.patch(
      Uri.parse('${ApiConfig.baseUrl}/auth/me/fcm-token'),
      headers: await _headers,
      body: jsonEncode({'fcm_token': token}),
    );
    _check(resp);
  }

  // ─── Internal ────────────────────────────────────────────────────────────
  void _check(http.Response resp) {
    if (resp.statusCode >= 400) {
      final msg = jsonDecode(resp.body)['detail'] ?? 'Server error';
      throw Exception(msg);
    }
  }
}
