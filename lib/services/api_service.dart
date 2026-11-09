import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import '../models/folder_node.dart';
import '../models/photo.dart';

class ApiService {
  static const String baseUrl = 'http://localhost:3000/api';

  Future<List<Photo>> getPhotos({
    String? name,
    String? sortBy,
    String? order,
    String? folder,
  }) async {
    final queryParameters = {
      if (name != null) 'name': name,
      if (folder != null) 'folder': folder,
      if (sortBy != null) 'sortBy': sortBy,
      if (order != null) 'order': order,
    };

    final uri = Uri.parse('$baseUrl/photos').replace(queryParameters: queryParameters);
    final response = await http.get(uri);

    if (response.statusCode == 200) {
      List jsonResponse = json.decode(response.body);
      return jsonResponse.map((data) => Photo.fromJson(data)).toList();
    } else {
      throw Exception('Failed to load photos');
    }
  }

  Future<void> scanFolder(String folderPath) async {
    final response = await http.post(
      Uri.parse('$baseUrl/scan'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'folderPath': folderPath}),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to scan folder');
    }
  }

  Future<FolderNode> getFolderTree(String root) async {
    final uri = Uri.parse('$baseUrl/folders').replace(queryParameters: {'root': root});
    final response = await http.get(uri);

    if (response.statusCode == 200) {
      return FolderNode.fromJson(json.decode(response.body));
    } else {
      throw Exception('Failed to load folders');
    }
  }

  /// Cartelle rimosse dall'app.
  Future<List<String>> getExcludedFolders() async {
    final response = await http.get(Uri.parse('$baseUrl/folders/excluded'));
    if (response.statusCode == 200) {
      return (json.decode(response.body) as List).cast<String>();
    }
    throw Exception('Failed to load removed folders');
  }

  /// Rimuove le cartelle SOLO dall'app e dal database (i file restano sul disco).
  /// Restituisce il numero di foto rimosse dall'app.
  Future<int> removeFolders(List<String> paths) async {
    final response = await http.post(
      Uri.parse('$baseUrl/folders/remove'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'paths': paths}),
    );
    if (response.statusCode == 200) {
      return (json.decode(response.body)['removedPhotos'] as num).toInt();
    }
    throw Exception('Failed to remove folders');
  }

  /// Ripristina cartelle rimosse in precedenza (vengono riscansionate).
  Future<void> restoreFolders(List<String> paths) async {
    final response = await http.post(
      Uri.parse('$baseUrl/folders/restore'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'paths': paths}),
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to restore folders');
    }
  }

  /// Versione di ogni foto modificata: cambiando l'URL si forza Flutter a
  /// ricaricare l'immagine invece di usare quella in cache.
  static final Map<int, int> _photoVersions = {};

  static void bumpPhotoVersion(int id) {
    _photoVersions[id] = (_photoVersions[id] ?? 0) + 1;
  }

  String getPhotoUrl(int id) {
    final version = _photoVersions[id];
    return version == null
        ? '$baseUrl/photo/$id'
        : '$baseUrl/photo/$id?v=$version';
  }

  Future<Uint8List> getPhotoBytes(int id) async {
    final response = await http.get(Uri.parse('$baseUrl/photo/$id'));
    if (response.statusCode == 200) return response.bodyBytes;
    throw Exception('Failed to load photo');
  }

  Future<Map<String, dynamic>> getPhotoInfo(int id) async {
    final response = await http.get(Uri.parse('$baseUrl/photo/$id/info'));
    if (response.statusCode == 200) {
      return json.decode(response.body) as Map<String, dynamic>;
    }
    throw Exception('Failed to load photo info');
  }

  /// Salva l'immagine modificata: come copia oppure sovrascrivendo l'originale.
  /// Restituisce la foto salvata (la copia nuova o l'originale aggiornato).
  Future<Photo> saveEditedPhoto(
    int id,
    Uint8List bytes, {
    required bool overwrite,
    required String ext,
  }) async {
    final uri = Uri.parse('$baseUrl/photo/$id/edit').replace(
      queryParameters: {'mode': overwrite ? 'overwrite' : 'copy', 'ext': ext},
    );
    final response = await http.post(
      uri,
      headers: {'Content-Type': 'application/octet-stream'},
      body: bytes,
    );
    if (response.statusCode == 200) {
      return Photo.fromJson(json.decode(response.body));
    }
    throw Exception('Failed to save photo: ${response.body}');
  }

  /// Tutte le impostazioni salvate nel database, come mappa chiave → valore.
  Future<Map<String, String>> getAllSettings() async {
    final response = await http.get(Uri.parse('$baseUrl/settings'));
    if (response.statusCode == 200) {
      final data = json.decode(response.body) as Map<String, dynamic>;
      return data.map((k, v) => MapEntry(k, '$v'));
    }
    throw Exception('Failed to load settings');
  }

  Future<String?> getSetting(String key) async {
    final response = await http.get(Uri.parse('$baseUrl/settings/$key'));
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return data['value'];
    }
    return null;
  }

  Future<void> updateSetting(String key, String value) async {
    await http.post(
      Uri.parse('$baseUrl/settings'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'key': key, 'value': value}),
    );
  }
}
