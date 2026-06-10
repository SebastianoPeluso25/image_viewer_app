import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/photo_provider.dart';
import '../screens/photo_viewer_screen.dart';
import 'photo_card.dart';

class PhotoGrid extends StatelessWidget {
  const PhotoGrid({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Consumer<PhotoProvider>(
      builder: (context, provider, child) {
        if (provider.isLoading && provider.photos.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }

        if (provider.photos.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.photo_library, size: 80, color: Colors.grey),
                SizedBox(height: 16),
                Text(
                  "Nessuna foto trovata. Carica una cartella!",
                  style: TextStyle(fontSize: 18, color: Colors.grey),
                ),
              ],
            ),
          );
        }

        return GridView.builder(
          padding: const EdgeInsets.all(16),
          gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: provider.gridSize,
            childAspectRatio: 1,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
          ),
          itemCount: provider.photos.length,
          itemBuilder: (context, index) {
            final photo = provider.photos[index];
            return PhotoCard(
              photoId: photo.id,
              name: photo.name,
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
