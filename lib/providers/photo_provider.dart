import 'package:flutter/material.dart';
import '../models/folder_node.dart';
import '../models/photo.dart';
import '../services/api_service.dart';

class PhotoProvider with ChangeNotifier {
  final ApiService _apiService = ApiService();
  List<Photo> _photos = [];
  bool _isLoading = false;
  bool _isScanning = false;
  String? _error;
  double _gridSize = 200.0;
  String _sortBy = 'created_at';
  String _order = 'DESC';
  String _searchQuery = '';

  String? _rootFolder;
  FolderNode? _folderTree;
  String? _selectedFolder; // null = tutte le foto
  int _requestId = 0;

  List<Photo> get photos => _photos;
  bool get isLoading => _isLoading;
  bool get isScanning => _isScanning;
  String? get error => _error;
  double get gridSize => _gridSize;
  String get sortBy => _sortBy;
  String get order => _order;
  String? get rootFolder => _rootFolder;
  FolderNode? get folderTree => _folderTree;
  String? get selectedFolder => _selectedFolder;

  // --- Rimozione cartelle (solo dall'app, mai dal disco) ---
  List<String> _excludedFolders = [];
  bool _selectionMode = false;
  final Set<String> _checkedFolders = {};

  List<String> get excludedFolders => _excludedFolders;
  bool get selectionMode => _selectionMode;
  Set<String> get checkedFolders => _checkedFolders;

  void setSelectionMode(bool enabled) {
    _selectionMode = enabled;
    _checkedFolders.clear();
    notifyListeners();
  }

  void toggleChecked(String folderPath) {
    if (!_checkedFolders.remove(folderPath)) _checkedFolders.add(folderPath);
    notifyListeners();
  }

  bool _isSameOrInside(String folder, String parent) {
    String norm(String s) =>
        s.toLowerCase().replaceAll('/', '\\').replaceFirst(RegExp(r'\\+$'), '');
    final f = norm(folder);
    final p = norm(parent);
    return f == p || f.startsWith('$p\\');
  }

  Future<void> loadExcludedFolders() async {
    try {
      _excludedFolders = await _apiService.getExcludedFolders();
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading removed folders: $e');
    }
  }

  /// Rimuove le cartelle SOLO dall'app e dal database. I file restano sul computer.
  /// Restituisce il numero di foto rimosse dall'app.
  Future<int> removeFolders(List<String> paths) async {
    final removed = await _apiService.removeFolders(paths);
    // Se la cartella aperta è stata rimossa, torna a "Tutte le foto"
    final current = _selectedFolder;
    if (current != null && paths.any((p) => _isSameOrInside(current, p))) {
      _selectedFolder = null;
    }
    _selectionMode = false;
    _checkedFolders.clear();
    await loadExcludedFolders();
    await reloadAfterEdit();
    return removed;
  }

  Future<void> restoreFolders(List<String> paths) async {
    _isScanning = true;
    notifyListeners();
    try {
      await _apiService.restoreFolders(paths);
    } finally {
      _isScanning = false;
    }
    await loadExcludedFolders();
    await reloadAfterEdit();
  }

  /// Percorso (breadcrumb) dalla cartella radice a quella selezionata.
  List<FolderNode> get selectedPath {
    if (_folderTree == null || _selectedFolder == null) return [];
    return _folderTree!.pathTo(_selectedFolder!) ?? [];
  }

  /// Carica la cartella radice salvata e le foto iniziali.
  Future<void> init() async {
    try {
      final settings = await _apiService.getAllSettings();

      // Preferenze di visualizzazione salvate nel database
      final grid = double.tryParse(settings['grid_size'] ?? '');
      if (grid != null) _gridSize = grid.clamp(100.0, 400.0);
      if (const ['created_at', 'name', 'size'].contains(settings['sort_by'])) {
        _sortBy = settings['sort_by']!;
      }
      if (const ['ASC', 'DESC'].contains(settings['sort_order'])) {
        _order = settings['sort_order']!;
      }

      final root = settings['root_folder'];
      if (root != null && root.isNotEmpty) {
        _rootFolder = root;
        await loadFolderTree();
      }
      await loadExcludedFolders();
    } catch (e) {
      debugPrint('Error loading settings: $e');
    }
    await fetchPhotos();
  }

  /// Aggiorna la dimensione durante il trascinamento dello slider.
  void setGridSize(double size) {
    _gridSize = size;
    notifyListeners();
  }

  /// Salva la dimensione nel database (chiamato al rilascio dello slider).
  void saveGridSize() => _saveSetting('grid_size', _gridSize.round().toString());

  void setSorting(String field, String direction) {
    _sortBy = field;
    _order = direction;
    fetchPhotos();
    _saveSetting('sort_by', field);
    _saveSetting('sort_order', direction);
  }

  Future<void> _saveSetting(String key, String value) async {
    try {
      await _apiService.updateSetting(key, value);
    } catch (e) {
      debugPrint('Error saving setting $key: $e');
    }
  }

  void setSearchQuery(String query) {
    _searchQuery = query;
    fetchPhotos();
  }

  void selectFolder(String? folderPath) {
    if (_selectedFolder == folderPath) return;
    _selectedFolder = folderPath;
    fetchPhotos();
  }

  Future<void> fetchPhotos() async {
    final requestId = ++_requestId;
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      final photos = await _apiService.getPhotos(
        name: _searchQuery.isEmpty ? null : _searchQuery,
        sortBy: _sortBy,
        order: _order,
        folder: _selectedFolder,
      );
      // Ignora risposte di richieste superate (es. click rapidi su cartelle diverse)
      if (requestId != _requestId) return;
      _photos = photos;
    } catch (e) {
      if (requestId != _requestId) return;
      _error = 'Impossibile caricare le foto. Il server è avviato?';
      debugPrint('$e');
    } finally {
      if (requestId == _requestId) {
        _isLoading = false;
        notifyListeners();
      }
    }
  }

  Future<void> loadFolderTree() async {
    if (_rootFolder == null) return;
    try {
      _folderTree = await _apiService.getFolderTree(_rootFolder!);
    } catch (e) {
      _folderTree = null;
      debugPrint('Error loading folder tree: $e');
    }
    notifyListeners();
  }

  /// Imposta una nuova cartella radice: la scansiona (con le sottocartelle) e ne mostra l'albero.
  Future<void> setRootFolder(String path) async {
    _rootFolder = path;
    _selectedFolder = null;
    await _scanRoot();
    try {
      await _apiService.updateSetting('root_folder', path);
    } catch (e) {
      debugPrint('Error saving root folder: $e');
    }
  }

  /// Riscansiona la cartella radice per trovare nuove foto/cartelle.
  Future<void> refresh() async {
    if (_rootFolder == null) {
      await fetchPhotos();
      return;
    }
    await _scanRoot();
  }

  Future<void> _scanRoot() async {
    _isScanning = true;
    notifyListeners();
    try {
      await _apiService.scanFolder(_rootFolder!);
      await loadFolderTree();
    } catch (e) {
      _error = 'Impossibile scansionare la cartella.';
      debugPrint('$e');
    } finally {
      _isScanning = false;
      notifyListeners();
    }
    await fetchPhotos();
  }

  /// Ricarica albero e foto dopo una modifica (es. nuova copia salvata).
  Future<void> reloadAfterEdit() async {
    await loadFolderTree();
    await fetchPhotos();
  }

  // Mantenuto per compatibilità
  Future<void> scanFolder(String path) => setRootFolder(path);
}
