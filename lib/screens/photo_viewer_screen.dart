import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/photo.dart';
import '../providers/photo_provider.dart';
import '../services/api_service.dart';
import '../widgets/photo_info_dialog.dart';
import 'photo_editor_screen.dart';

class PhotoViewerScreen extends StatefulWidget {
  final List<Photo> photos;
  final int initialIndex;

  const PhotoViewerScreen({
    Key? key,
    required this.photos,
    required this.initialIndex,
  }) : super(key: key);

  @override
  State<PhotoViewerScreen> createState() => _PhotoViewerScreenState();
}

class _PhotoViewerScreenState extends State<PhotoViewerScreen> {
  late PageController _pageController;
  late int _currentIndex;
  final ApiService _apiService = ApiService();
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _nextPage() {
    if (_currentIndex < widget.photos.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _prevPage() {
    if (_currentIndex > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  Future<void> _showInfo() async {
    await PhotoInfoDialog.show(context, widget.photos[_currentIndex]);
    _focusNode.requestFocus(); // per far funzionare di nuovo le frecce
  }

  Future<void> _openEditor() async {
    final photo = widget.photos[_currentIndex];
    final result = await Navigator.push<PhotoEditResult>(
      context,
      MaterialPageRoute(builder: (_) => PhotoEditorScreen(photo: photo)),
    );
    if (!mounted) return;
    _focusNode.requestFocus();
    if (result == null) return;

    final provider = context.read<PhotoProvider>();
    final messenger = ScaffoldMessenger.of(context);
    if (result.overwritten) {
      // Nuovo URL per la foto: forza il ricaricamento al posto della versione in cache
      ApiService.bumpPhotoVersion(photo.id);
      setState(() {});
      provider.fetchPhotos();
      messenger.showSnackBar(
        const SnackBar(content: Text("Immagine aggiornata")),
      );
    } else {
      provider.reloadAfterEdit();
      messenger.showSnackBar(
        SnackBar(content: Text("Copia salvata: ${result.photo.name}")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: KeyboardListener(
        focusNode: _focusNode,
        autofocus: true,
        onKeyEvent: (event) {
          if (event is KeyDownEvent) {
            if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
              _nextPage();
            } else if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
              _prevPage();
            } else if (event.logicalKey == LogicalKeyboardKey.escape) {
              Navigator.pop(context);
            } else if (event.logicalKey == LogicalKeyboardKey.keyI) {
              _showInfo();
            } else if (event.logicalKey == LogicalKeyboardKey.keyE) {
              _openEditor();
            }
          }
        },
        child: Stack(
          children: [
            // Image PageView
            PageView.builder(
              controller: _pageController,
              itemCount: widget.photos.length,
              onPageChanged: (index) {
                setState(() {
                  _currentIndex = index;
                });
              },
              itemBuilder: (context, index) {
                final photo = widget.photos[index];
                return InteractiveViewer(
                  minScale: 0.5,
                  maxScale: 4.0,
                  child: Center(
                    child: Image.network(
                      _apiService.getPhotoUrl(photo.id),
                      fit: BoxFit.contain,
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return const Center(child: CircularProgressIndicator());
                      },
                      errorBuilder: (context, error, stackTrace) => const Center(
                        child: Icon(Icons.broken_image, size: 100, color: Colors.white54),
                      ),
                    ),
                  ),
                );
              },
            ),

            // Top Bar
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 40),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.black.withValues(alpha: 0.7), Colors.transparent],
                  ),
                ),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.photos[_currentIndex].name,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            "${_currentIndex + 1} di ${widget.photos.length}",
                            style: const TextStyle(color: Colors.white70, fontSize: 14),
                          ),
                        ],
                      ),
                    ),
                    _TopAction(
                      icon: Icons.info_outline,
                      tooltip: "Dettagli (I)",
                      onPressed: _showInfo,
                    ),
                    const SizedBox(width: 8),
                    _TopAction(
                      icon: Icons.crop_rotate,
                      tooltip: "Modifica: ritaglia e ruota (E)",
                      onPressed: _openEditor,
                    ),
                  ],
                ),
              ),
            ),

            // Navigation Arrows (Visual)
            if (_currentIndex > 0)
              Positioned(
                left: 16,
                top: 0,
                bottom: 0,
                child: Center(
                  child: IconButton(
                    icon: const Icon(Icons.arrow_back_ios, color: Colors.white54, size: 40),
                    onPressed: _prevPage,
                  ),
                ),
              ),
            if (_currentIndex < widget.photos.length - 1)
              Positioned(
                right: 16,
                top: 0,
                bottom: 0,
                child: Center(
                  child: IconButton(
                    icon: const Icon(Icons.arrow_forward_ios, color: Colors.white54, size: 40),
                    onPressed: _nextPage,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Pulsante circolare semitrasparente per la barra superiore del visualizzatore.
class _TopAction extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  const _TopAction({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      icon: Icon(icon, color: Colors.white),
      style: IconButton.styleFrom(
        backgroundColor: Colors.white.withValues(alpha: 0.15),
        hoverColor: Colors.white.withValues(alpha: 0.25),
        padding: const EdgeInsets.all(12),
      ),
    );
  }
}
