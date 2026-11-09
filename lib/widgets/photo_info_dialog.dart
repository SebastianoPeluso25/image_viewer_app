import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import '../models/photo.dart';
import '../services/api_service.dart';
import '../utils/format.dart';

/// Popup con i dettagli di una foto: data di creazione in evidenza,
/// risoluzione, qualità, formato, dimensione, fotocamera, percorso.
class PhotoInfoDialog extends StatefulWidget {
  final Photo photo;

  const PhotoInfoDialog({super.key, required this.photo});

  static Future<void> show(BuildContext context, Photo photo) {
    return showDialog(
      context: context,
      builder: (_) => PhotoInfoDialog(photo: photo),
    );
  }

  @override
  State<PhotoInfoDialog> createState() => _PhotoInfoDialogState();
}

class _PhotoDetails {
  DateTime? takenAt; // dai metadati EXIF (data di scatto)
  DateTime? fileCreatedAt;
  DateTime? fileModifiedAt;
  DateTime? addedAt;
  int? width;
  int? height;
  int size = 0;
  String format = '';
  String? camera;
  bool exists = true;
}

class _PhotoInfoDialogState extends State<PhotoInfoDialog> {
  late final Future<_PhotoDetails> _future = _load();

  Future<_PhotoDetails> _load() async {
    final api = ApiService();
    final d = _PhotoDetails()
      ..size = widget.photo.size
      ..format = _formatName(widget.photo.name);

    final info = await api.getPhotoInfo(widget.photo.id);
    d.exists = info['exists'] == true;
    d.size = (info['size'] as num?)?.toInt() ?? d.size;
    d.fileCreatedAt = DateTime.tryParse(info['file_created_at'] ?? '');
    d.fileModifiedAt = DateTime.tryParse(info['file_modified_at'] ?? '');
    d.addedAt = DateTime.tryParse(info['added_at'] ?? '');

    if (!d.exists) return d;

    // Risoluzione e metadati EXIF letti direttamente dai byte dell'immagine
    final bytes = await api.getPhotoBytes(widget.photo.id);
    _readImageData(bytes, d);
    return d;
  }

  void _readImageData(Uint8List bytes, _PhotoDetails d) {
    try {
      final decodeInfo = img.findDecoderForData(bytes)?.startDecode(bytes);
      d.width = decodeInfo?.width;
      d.height = decodeInfo?.height;

      final exif = img.decodeJpgExif(bytes);
      if (exif == null) return;

      // Orientamento 5-8 = foto ruotata di 90°: larghezza e altezza invertite
      final orientation = exif.imageIfd.orientation ?? 1;
      if (orientation >= 5 && d.width != null) {
        final w = d.width;
        d.width = d.height;
        d.height = w;
      }

      final taken = exif.exifIfd[0x9003]?.toString() ?? // DateTimeOriginal
          exif.imageIfd[0x0132]?.toString(); // DateTime
      d.takenAt = _parseExifDate(taken);

      final make = exif.imageIfd[0x010F]?.toString().trim() ?? '';
      final model = exif.imageIfd[0x0110]?.toString().trim() ?? '';
      final camera = model.toLowerCase().startsWith(make.toLowerCase())
          ? model
          : '$make $model'.trim();
      if (camera.isNotEmpty) d.camera = camera;
    } catch (_) {
      // Metadati non leggibili: mostriamo solo i dati del file
    }
  }

  /// I dati EXIF usano il formato "2025:06:12 14:32:10"
  DateTime? _parseExifDate(String? value) {
    if (value == null || value.length < 19) return null;
    final normalized =
        '${value.substring(0, 10).replaceAll(':', '-')}T${value.substring(11, 19)}';
    return DateTime.tryParse(normalized);
  }

  String _formatName(String fileName) {
    final ext = fileName.split('.').last.toUpperCase();
    return ext == 'JPG' ? 'JPEG' : ext;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460, maxHeight: 640),
        child: FutureBuilder<_PhotoDetails>(
          future: _future,
          builder: (context, snapshot) {
            Widget body;
            if (snapshot.connectionState != ConnectionState.done) {
              body = const Padding(
                padding: EdgeInsets.all(48),
                child: Center(child: CircularProgressIndicator()),
              );
            } else if (snapshot.hasError) {
              body = Padding(
                padding: const EdgeInsets.all(32),
                child: Text(
                  "Impossibile caricare i dettagli.\nVerifica che il server sia avviato.",
                  textAlign: TextAlign.center,
                  style: TextStyle(color: scheme.error),
                ),
              );
            } else {
              body = _buildDetails(context, snapshot.data!);
            }

            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildHeader(context),
                Flexible(child: SingleChildScrollView(child: body)),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: FilledButton.tonal(
                      onPressed: () => Navigator.pop(context),
                      child: const Text("Chiudi"),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 16, 12),
      child: Row(
        children: [
          Icon(Icons.info_outline, color: scheme.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Dettagli foto",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
                Text(
                  widget.photo.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: "Chiudi",
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  Widget _buildDetails(BuildContext context, _PhotoDetails d) {
    final scheme = Theme.of(context).colorScheme;
    final created = d.takenAt ?? d.fileModifiedAt;
    final hasResolution = d.width != null && d.height != null;
    final megapixels = hasResolution ? d.width! * d.height! / 1e6 : 0.0;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (!d.exists)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                "⚠ Il file non esiste più nel percorso salvato.",
                style: TextStyle(color: scheme.error),
              ),
            ),

          // --- Data di creazione in evidenza ---
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: scheme.primaryContainer,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: scheme.primary,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.event, color: scheme.onPrimary),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        d.takenAt != null ? "SCATTATA IL" : "DATA DI CREAZIONE",
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1,
                          color: scheme.onPrimaryContainer.withValues(alpha: 0.75),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        created != null ? formatDateTime(created) : "Non disponibile",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: scheme.onPrimaryContainer,
                        ),
                      ),
                      if (d.camera != null)
                        Text(
                          "con ${d.camera}",
                          style: TextStyle(
                            fontSize: 13,
                            color: scheme.onPrimaryContainer.withValues(alpha: 0.8),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // --- Qualità ---
          if (hasResolution) ...[
            _QualityBar(megapixels: megapixels),
            const SizedBox(height: 8),
          ],

          _row(context, Icons.aspect_ratio, "Risoluzione",
              hasResolution ? "${d.width} × ${d.height} px" : "—"),
          if (hasResolution)
            _row(context, Icons.grid_on, "Megapixel",
                "${megapixels.toStringAsFixed(1).replaceAll('.', ',')} MP"),
          if (hasResolution)
            _row(
              context,
              d.width! >= d.height! ? Icons.crop_landscape : Icons.crop_portrait,
              "Orientamento",
              d.width! == d.height!
                  ? "Quadrata"
                  : (d.width! > d.height! ? "Orizzontale" : "Verticale"),
            ),
          _row(context, Icons.image_outlined, "Formato", d.format),
          _row(context, Icons.sd_storage_outlined, "Dimensione file", formatBytes(d.size)),
          if (d.camera != null)
            _row(context, Icons.photo_camera_outlined, "Fotocamera", d.camera!),
          if (d.takenAt != null && d.fileModifiedAt != null)
            _row(context, Icons.insert_drive_file_outlined, "File creato",
                formatDateTime(d.fileModifiedAt!)),
          if (d.fileModifiedAt != null)
            _row(context, Icons.edit_calendar_outlined, "Ultima modifica",
                formatDateTime(d.fileModifiedAt!)),
          if (d.addedAt != null)
            _row(context, Icons.library_add_outlined, "Aggiunta alla libreria",
                formatDateTime(d.addedAt!)),
          const SizedBox(height: 8),
          _pathBox(context),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  Widget _row(BuildContext context, IconData icon, String label, String value) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          Icon(icon, size: 18, color: scheme.onSurfaceVariant),
          const SizedBox(width: 12),
          Text(label, style: TextStyle(color: scheme.onSurfaceVariant)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _pathBox(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(Icons.folder_outlined, size: 18, color: scheme.onSurfaceVariant),
          const SizedBox(width: 10),
          Expanded(
            child: SelectableText(
              widget.photo.path,
              style: const TextStyle(fontSize: 12),
            ),
          ),
          IconButton(
            tooltip: "Copia percorso",
            icon: const Icon(Icons.copy, size: 18),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: widget.photo.path));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Percorso copiato")),
              );
            },
          ),
        ],
      ),
    );
  }
}

/// Indicatore della qualità basato sui megapixel.
class _QualityBar extends StatelessWidget {
  final double megapixels;

  const _QualityBar({required this.megapixels});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (String label, Color color, double level) = switch (megapixels) {
      >= 12 => ("Eccellente", const Color(0xFF2E9D5B), 1.0),
      >= 8 => ("Alta", const Color(0xFF3FA86B), 0.8),
      >= 2 => ("Media", const Color(0xFFE0A100), 0.55),
      _ => ("Bassa", const Color(0xFFD9534F), 0.3),
    };

    return Row(
      children: [
        Icon(Icons.high_quality_outlined, size: 18, color: scheme.onSurfaceVariant),
        const SizedBox(width: 12),
        Text("Qualità", style: TextStyle(color: scheme.onSurfaceVariant)),
        const SizedBox(width: 12),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: level,
              minHeight: 6,
              color: color,
              backgroundColor: scheme.surfaceContainerHigh,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Text(label, style: TextStyle(fontWeight: FontWeight.w700, color: color)),
      ],
    );
  }
}
