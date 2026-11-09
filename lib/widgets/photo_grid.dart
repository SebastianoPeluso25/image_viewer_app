import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/photo_provider.dart';
import '../providers/settings_provider.dart';
import '../screens/photo_viewer_screen.dart';
import 'left_sidebar.dart';
import 'photo_card.dart';

class PhotoGrid extends StatelessWidget {
  const PhotoGrid({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final showNames = context.watch<SettingsProvider>().showPhotoNames;

    return Consumer<PhotoProvider>(
      builder: (context, provider, child) {
        if (provider.isLoading && provider.photos.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }

        if (provider.error != null && provider.photos.isEmpty) {
          return _EmptyState(
            icon: Icons.cloud_off_outlined,
            message: provider.error!,
            action: TextButton.icon(
              onPressed: provider.refresh,
              icon: const Icon(Icons.refresh),
              label: const Text("Riprova"),
            ),
          );
        }

        if (provider.photos.isEmpty) {
          if (provider.rootFolder == null) {
            return _EmptyState(
              icon: Icons.photo_library_outlined,
              message: "Nessuna foto ancora.\nScegli una cartella per iniziare!",
              action: FilledButton.icon(
                onPressed: () => pickRootFolder(context),
                icon: const Icon(Icons.create_new_folder_outlined),
                label: const Text("Scegli cartella"),
              ),
            );
          }
          return const _EmptyState(
            icon: Icons.image_not_supported_outlined,
            message:
                "Nessuna foto in questa cartella.\nProva a selezionare una sottocartella a sinistra.",
          );
        }

        return GridView.builder(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
          gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: provider.gridSize,
            childAspectRatio: 1,
            crossAxisSpacing: 14,
            mainAxisSpacing: 14,
          ),
          itemCount: provider.photos.length,
          itemBuilder: (context, index) {
            final photo = provider.photos[index];
            return PhotoCard(
              photoId: photo.id,
              name: photo.name,
              showName: showNames,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => PhotoViewerScreen(
                      photos: provider.photos,
                      initialIndex: index,
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String message;
  final Widget? action;

  const _EmptyState({required this.icon, required this.message, this.action});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: scheme.primaryContainer.withValues(alpha: 0.5),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 56, color: scheme.primary),
          ),
          const SizedBox(height: 20),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              height: 1.5,
              color: scheme.onSurfaceVariant,
            ),
          ),
          if (action != null) ...[
            const SizedBox(height: 20),
            action!,
          ],
        ],
      ),
    );
  }
}
