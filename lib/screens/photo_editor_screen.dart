import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import '../models/photo.dart';
import '../services/api_service.dart';

/// Risultato restituito dall'editor quando l'immagine è stata salvata.
class PhotoEditResult {
  final Photo photo;
  final bool overwritten;

  const PhotoEditResult(this.photo, {required this.overwritten});
}

/// Schermata per ritagliare, ruotare e riflettere un'immagine.
class PhotoEditorScreen extends StatefulWidget {
  final Photo photo;

  const PhotoEditorScreen({super.key, required this.photo});

  @override
  State<PhotoEditorScreen> createState() => _PhotoEditorScreenState();
}

enum _Handle { topLeft, topRight, bottomLeft, bottomRight, move }

class _AspectOption {
  final String label;
  final double? ratio; // null = libero

  const _AspectOption(this.label, this.ratio);
}

const _aspectOptions = [
  _AspectOption("Libero", null),
  _AspectOption("1:1", 1),
  _AspectOption("4:3", 4 / 3),
  _AspectOption("3:4", 3 / 4),
  _AspectOption("16:9", 16 / 9),
  _AspectOption("9:16", 9 / 16),
];

const _fullCrop = Rect.fromLTWH(0, 0, 1, 1);
const double _handleHitSize = 28;
const double _minCropSize = 48;
const double _margin = 16;

class _PhotoEditorScreenState extends State<PhotoEditorScreen> {
  final ApiService _api = ApiService();

  Uint8List? _bytes;
  Size? _imageSize; // dimensioni originali (con orientamento EXIF applicato)
  String? _loadError;
  bool _saving = false;

  // Stato delle modifiche
  int _turns = 0; // rotazioni di 90° in senso orario
  bool _flipped = false;
  double? _ratio;
  Rect _crop = _fullCrop; // area di ritaglio normalizzata (0..1) sull'immagine ruotata

  // Stato del trascinamento
  _Handle? _activeHandle;
  Offset _dragStart = Offset.zero;
  Rect _cropAtDragStart = Rect.zero;
  Size _displaySize = Size.zero;

  bool get _hasChanges => _turns != 0 || _flipped || _crop != _fullCrop;

  Size get _rotatedSize {
    final s = _imageSize!;
    return _turns.isOdd ? Size(s.height, s.width) : s;
  }

  String get _originalExt => widget.photo.name.split('.').last.toLowerCase();

  /// Formato di salvataggio: JPEG e BMP restano tali, gli altri diventano PNG.
  String get _outputExt => switch (_originalExt) {
        'jpg' || 'jpeg' || 'bmp' || 'png' => _originalExt,
        _ => 'png',
      };

  bool get _canOverwrite => _outputExt == _originalExt;

  @override
  void initState() {
    super.initState();
    _loadImage();
  }

  Future<void> _loadImage() async {
    try {
      final bytes = await _api.getPhotoBytes(widget.photo.id);
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      final size = Size(
        frame.image.width.toDouble(),
        frame.image.height.toDouble(),
      );
      frame.image.dispose();
      codec.dispose();
      if (!mounted) return;
      setState(() {
        _bytes = bytes;
        _imageSize = size;
      });
    } catch (e) {
      if (mounted) setState(() => _loadError = "Impossibile caricare l'immagine.");
    }
  }

  // ------------------------------------------------------------------
  // Azioni
  // ------------------------------------------------------------------

  void _rotate(int direction) {
    setState(() {
      // Con l'immagine riflessa il verso di rotazione visivo è invertito
      _turns = (_turns + (_flipped ? -direction : direction)) % 4;
      _crop = _initialCrop();
    });
  }

  void _flip() {
    setState(() {
      _flipped = !_flipped;
      _crop = Rect.fromLTRB(1 - _crop.right, _crop.top, 1 - _crop.left, _crop.bottom);
    });
  }

  void _setRatio(double? ratio) {
    setState(() {
      _ratio = ratio;
      _crop = _initialCrop();
    });
  }

  void _reset() {
    setState(() {
      _turns = 0;
      _flipped = false;
      _ratio = null;
      _crop = _fullCrop;
    });
  }

  /// Area di ritaglio iniziale: tutta l'immagine, o la più grande con il rapporto scelto.
  Rect _initialCrop() {
    final ratio = _ratio;
    if (ratio == null || _imageSize == null) return _fullCrop;
    final s = _rotatedSize;
    double w = s.width, h = s.height;
    if (w / h > ratio) {
      w = h * ratio;
    } else {
      h = w / ratio;
    }
    final nw = w / s.width, nh = h / s.height;
    return Rect.fromLTWH((1 - nw) / 2, (1 - nh) / 2, nw, nh);
  }

  // ------------------------------------------------------------------
  // Gestione del trascinamento dell'area di ritaglio
  // ------------------------------------------------------------------

  Rect _toDisplay(Rect r) => Rect.fromLTRB(
        r.left * _displaySize.width,
        r.top * _displaySize.height,
        r.right * _displaySize.width,
        r.bottom * _displaySize.height,
      );

  Rect _toNormalized(Rect r) => Rect.fromLTRB(
        r.left / _displaySize.width,
        r.top / _displaySize.height,
        r.right / _displaySize.width,
        r.bottom / _displaySize.height,
      );

  void _onPanStart(DragStartDetails details) {
    final pos = details.localPosition - const Offset(_margin, _margin);
    final rect = _toDisplay(_crop);
    final corners = {
      _Handle.topLeft: rect.topLeft,
      _Handle.topRight: rect.topRight,
      _Handle.bottomLeft: rect.bottomLeft,
      _Handle.bottomRight: rect.bottomRight,
    };

    _activeHandle = null;
    for (final entry in corners.entries) {
      if ((entry.value - pos).distance <= _handleHitSize) {
        _activeHandle = entry.key;
        break;
      }
    }
    if (_activeHandle == null && rect.contains(pos)) _activeHandle = _Handle.move;

    _dragStart = pos;
    _cropAtDragStart = rect;
  }

  void _onPanUpdate(DragUpdateDetails details) {
    final handle = _activeHandle;
    if (handle == null) return;
    final pos = details.localPosition - const Offset(_margin, _margin);
    final start = _cropAtDragStart;
    final w = _displaySize.width, h = _displaySize.height;

    Rect result;
    if (handle == _Handle.move) {
      final delta = pos - _dragStart;
      final dx = delta.dx.clamp(-start.left, w - start.right);
      final dy = delta.dy.clamp(-start.top, h - start.bottom);
      result = start.shift(Offset(dx, dy));
    } else {
      // L'angolo opposto resta fermo
      final anchor = switch (handle) {
        _Handle.topLeft => start.bottomRight,
        _Handle.topRight => start.bottomLeft,
        _Handle.bottomLeft => start.topRight,
        _ => start.topLeft,
      };
      final point = Offset(pos.dx.clamp(0, w), pos.dy.clamp(0, h));
      result = _rectFromAnchor(anchor, point);
    }

    setState(() => _crop = _toNormalized(result));
  }

  Rect _rectFromAnchor(Offset anchor, Offset point) {
    final sx = point.dx >= anchor.dx ? 1.0 : -1.0;
    final sy = point.dy >= anchor.dy ? 1.0 : -1.0;
    final maxW = sx > 0 ? _displaySize.width - anchor.dx : anchor.dx;
    final maxH = sy > 0 ? _displaySize.height - anchor.dy : anchor.dy;

    double cw = (point.dx - anchor.dx).abs();
    double ch = (point.dy - anchor.dy).abs();
    cw = math.max(cw, math.min(_minCropSize, maxW));
    ch = math.max(ch, math.min(_minCropSize, maxH));

    final ratio = _ratio;
    if (ratio != null) {
      if (cw / ch > ratio) {
        cw = ch * ratio;
      } else {
        ch = cw / ratio;
      }
      // Rientra nei bordi mantenendo il rapporto
      if (cw > maxW) {
        cw = maxW;
        ch = cw / ratio;
      }
      if (ch > maxH) {
        ch = maxH;
        cw = ch * ratio;
      }
    }

    return Rect.fromPoints(anchor, anchor + Offset(sx * cw, sy * ch));
  }

  // ------------------------------------------------------------------
  // Salvataggio
  // ------------------------------------------------------------------

  Future<void> _save() async {
    final overwrite = await showDialog<bool>(
      context: context,
      builder: (context) => _SaveDialog(
        photoName: widget.photo.name,
        canOverwrite: _canOverwrite,
        outputExt: _outputExt,
      ),
    );
    if (overwrite == null || !mounted) return;

    setState(() => _saving = true);
    try {
      final edited = await compute(_applyEdits, {
        'bytes': _bytes!,
        'turns': _turns,
        'flip': _flipped,
        'left': _crop.left,
        'top': _crop.top,
        'right': _crop.right,
        'bottom': _crop.bottom,
        'ext': _outputExt,
      });
      final saved = await _api.saveEditedPhoto(
        widget.photo.id,
        edited,
        overwrite: overwrite,
        ext: _outputExt,
      );
      if (!mounted) return;
      Navigator.pop(context, PhotoEditResult(saved, overwritten: overwrite));
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Errore durante il salvataggio: $e")),
      );
    }
  }

  // ------------------------------------------------------------------
  // UI
  // ------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: const Color(0xFF121316),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1B1C20),
        foregroundColor: Colors.white,
        leading: IconButton(
          tooltip: "Annulla",
          icon: const Icon(Icons.close),
          onPressed: _saving ? null : () => Navigator.pop(context),
        ),
        title: Text(
          "Modifica · ${widget.photo.name}",
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          TextButton.icon(
            onPressed: _hasChanges && !_saving ? _reset : null,
            icon: const Icon(Icons.restart_alt),
            label: const Text("Ripristina"),
            style: TextButton.styleFrom(foregroundColor: Colors.white70),
          ),
          const SizedBox(width: 8),
          FilledButton.icon(
            onPressed: _hasChanges && !_saving && _bytes != null ? _save : null,
            icon: _saving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.check),
            label: const Text("Salva"),
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: Column(
        children: [
          Expanded(child: _buildCanvas()),
          _buildToolbar(scheme),
        ],
      ),
    );
  }

  Widget _buildCanvas() {
    if (_loadError != null) {
      return Center(
        child: Text(_loadError!, style: const TextStyle(color: Colors.white70)),
      );
    }
    if (_bytes == null || _imageSize == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return Padding(
      padding: const EdgeInsets.all(24),
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Dimensione dell'immagine a schermo (adattata allo spazio disponibile)
          final s = _rotatedSize;
          final maxW = constraints.maxWidth - _margin * 2;
          final maxH = constraints.maxHeight - _margin * 2;
          final scale = math.min(maxW / s.width, maxH / s.height);
          _displaySize = Size(s.width * scale, s.height * scale);

          return Center(
            child: GestureDetector(
              onPanStart: _saving ? null : _onPanStart,
              onPanUpdate: _saving ? null : _onPanUpdate,
              onPanEnd: (_) => _activeHandle = null,
              child: SizedBox(
                width: _displaySize.width + _margin * 2,
                height: _displaySize.height + _margin * 2,
                child: Stack(
                  children: [
                    Positioned(
                      left: _margin,
                      top: _margin,
                      width: _displaySize.width,
                      height: _displaySize.height,
                      child: Transform.flip(
                        flipX: _flipped,
                        child: RotatedBox(
                          quarterTurns: _turns,
                          child: Image.memory(
                            _bytes!,
                            fit: BoxFit.fill,
                            gaplessPlayback: true,
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      left: _margin,
                      top: _margin,
                      width: _displaySize.width,
                      height: _displaySize.height,
                      child: IgnorePointer(
                        child: CustomPaint(
                          painter: _CropOverlayPainter(_toDisplay(_crop)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildToolbar(ColorScheme scheme) {
    final cropPixels = _imageSize == null
        ? ""
        : "${(_crop.width * _rotatedSize.width).round()} × "
            "${(_crop.height * _rotatedSize.height).round()} px";

    return Container(
      color: const Color(0xFF1B1C20),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
      child: Row(
        children: [
          _ToolButton(
            icon: Icons.rotate_left,
            label: "Ruota a sinistra",
            onPressed: _saving ? null : () => _rotate(-1),
          ),
          _ToolButton(
            icon: Icons.rotate_right,
            label: "Ruota a destra",
            onPressed: _saving ? null : () => _rotate(1),
          ),
          _ToolButton(
            icon: Icons.flip,
            label: "Rifletti",
            active: _flipped,
            onPressed: _saving ? null : _flip,
          ),
          const SizedBox(width: 16),
          Container(width: 1, height: 32, color: Colors.white24),
          const SizedBox(width: 16),
          const Icon(Icons.crop, color: Colors.white70, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final option in _aspectOptions)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(option.label),
                        selected: _ratio == option.ratio,
                        onSelected: _saving ? null : (_) => _setRatio(option.ratio),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),
          Text(cropPixels, style: const TextStyle(color: Colors.white60, fontSize: 13)),
        ],
      ),
    );
  }
}

class _ToolButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  final bool active;

  const _ToolButton({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.active = false,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: IconButton(
        tooltip: label,
        onPressed: onPressed,
        icon: Icon(icon),
        color: active ? scheme.onPrimary : Colors.white,
        style: IconButton.styleFrom(
          backgroundColor: active ? scheme.primary : Colors.white10,
          padding: const EdgeInsets.all(12),
        ),
      ),
    );
  }
}

class _SaveDialog extends StatelessWidget {
  final String photoName;
  final bool canOverwrite;
  final String outputExt;

  const _SaveDialog({
    required this.photoName,
    required this.canOverwrite,
    required this.outputExt,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dot = photoName.lastIndexOf('.');
    final baseName = dot > 0 ? photoName.substring(0, dot) : photoName;

    return AlertDialog(
      title: const Text("Salva modifiche"),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: Icon(Icons.copy_all_outlined, color: scheme.primary),
            title: const Text("Salva come copia"),
            subtitle: Text("Crea \"${baseName}_modificata.$outputExt\" nella stessa cartella"),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            onTap: () => Navigator.pop(context, false),
          ),
          ListTile(
            enabled: canOverwrite,
            leading: Icon(Icons.save_outlined, color: canOverwrite ? scheme.error : null),
            title: const Text("Sovrascrivi l'originale"),
            subtitle: Text(
              canOverwrite
                  ? "L'operazione non si può annullare"
                  : "Non disponibile per questo formato",
            ),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            onTap: () => Navigator.pop(context, true),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text("Annulla"),
        ),
      ],
    );
  }
}

/// Disegna l'area esterna oscurata, il bordo, la griglia dei terzi e le maniglie.
class _CropOverlayPainter extends CustomPainter {
  final Rect crop;

  _CropOverlayPainter(this.crop);

  @override
  void paint(Canvas canvas, Size size) {
    final outside = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(Offset.zero & size)
      ..addRect(crop);
    canvas.drawPath(outside, Paint()..color = Colors.black.withValues(alpha: 0.6));

    // Griglia dei terzi
    final grid = Paint()
      ..color = Colors.white.withValues(alpha: 0.35)
      ..strokeWidth = 1;
    for (var i = 1; i < 3; i++) {
      final x = crop.left + crop.width * i / 3;
      final y = crop.top + crop.height * i / 3;
      canvas.drawLine(Offset(x, crop.top), Offset(x, crop.bottom), grid);
      canvas.drawLine(Offset(crop.left, y), Offset(crop.right, y), grid);
    }

    canvas.drawRect(
      crop,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );

    // Maniglie agli angoli (a forma di L)
    final handle = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    const len = 20.0;
    for (final (corner, dx, dy) in [
      (crop.topLeft, 1.0, 1.0),
      (crop.topRight, -1.0, 1.0),
      (crop.bottomLeft, 1.0, -1.0),
      (crop.bottomRight, -1.0, -1.0),
    ]) {
      canvas.drawLine(corner, corner + Offset(dx * len, 0), handle);
      canvas.drawLine(corner, corner + Offset(0, dy * len), handle);
    }
  }

  @override
  bool shouldRepaint(_CropOverlayPainter oldDelegate) => oldDelegate.crop != crop;
}

/// Applica rotazione, riflessione e ritaglio (eseguita in un isolate separato
/// per non bloccare l'interfaccia con immagini grandi).
Uint8List _applyEdits(Map<String, Object> params) {
  final bytes = params['bytes'] as Uint8List;
  var image = img.decodeImage(bytes);
  if (image == null) throw Exception('Formato immagine non supportato');

  image = img.bakeOrientation(image);

  final turns = params['turns'] as int;
  if (turns != 0) image = img.copyRotate(image, angle: turns * 90);
  if (params['flip'] as bool) {
    image = img.copyFlip(image, direction: img.FlipDirection.horizontal);
  }

  final w = image.width, h = image.height;
  final left = ((params['left'] as double) * w).round().clamp(0, w - 1);
  final top = ((params['top'] as double) * h).round().clamp(0, h - 1);
  final right = ((params['right'] as double) * w).round().clamp(left + 1, w);
  final bottom = ((params['bottom'] as double) * h).round().clamp(top + 1, h);
  if (left != 0 || top != 0 || right != w || bottom != h) {
    image = img.copyCrop(
      image,
      x: left,
      y: top,
      width: right - left,
      height: bottom - top,
    );
  }

  return switch (params['ext'] as String) {
    'jpg' || 'jpeg' => img.encodeJpg(image, quality: 95),
    'bmp' => img.encodeBmp(image),
    _ => img.encodePng(image),
  };
}
