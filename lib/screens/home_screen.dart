import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/photo_provider.dart';
import '../providers/settings_provider.dart';
import '../widgets/left_sidebar.dart';
import '../widgets/photo_grid.dart';
import '../widgets/right_sidebar.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<PhotoProvider>(context, listen: false).init();
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 20,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: scheme.primaryContainer,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                Icons.photo_camera_back_outlined,
                color: scheme.primary,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            const Text(
              "Photo Viewer",
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ],
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(
            height: 1,
            color: scheme.outlineVariant.withValues(alpha: 0.6),
          ),
        ),
        actions: [
          if (context.watch<SettingsProvider>().showSearchBar)
            Container(
              width: 320,
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: TextField(
                decoration: InputDecoration(
                  hintText: "Cerca foto...",
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(30),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: scheme.surfaceContainerHigh,
                  contentPadding: EdgeInsets.zero,
                ),
                onChanged: (value) {
                  Provider.of<PhotoProvider>(
                    context,
                    listen: false,
                  ).setSearchQuery(value);
                },
              ),
            ),
          const SizedBox(width: 20),
        ],
      ),
      body: const Row(
        children: [
          LeftSidebar(),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _GalleryHeader(),
                Expanded(child: PhotoGrid()),
              ],
            ),
          ),
          RightSidebar(),
        ],
      ),
    );
  }
}

/// Intestazione dell'area centrale: percorso della cartella (breadcrumb) e numero di foto.
class _GalleryHeader extends StatelessWidget {
  const _GalleryHeader();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Consumer<PhotoProvider>(
      builder: (context, provider, child) {
        final crumbs = provider.selectedPath;
        final title = crumbs.isEmpty ? "Tutte le foto" : crumbs.last.name;
        final count = provider.photos.length;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (crumbs.length > 1)
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        for (var i = 0; i < crumbs.length - 1; i++) ...[
                          InkWell(
                            borderRadius: BorderRadius.circular(6),
                            onTap: () => provider.selectFolder(crumbs[i].path),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4,
                                vertical: 2,
                              ),
                              child: Text(
                                crumbs[i].name,
                                style: TextStyle(
                                  color: scheme.primary,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ),
                          Icon(
                            Icons.chevron_right,
                            size: 16,
                            color: scheme.onSurfaceVariant,
                          ),
                        ],
                      ],
                    ),
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: scheme.secondaryContainer,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          count == 1 ? "1 foto" : "$count foto",
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: scheme.onSecondaryContainer,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            SizedBox(
              height: 2,
              child: provider.isLoading
                  ? const LinearProgressIndicator(minHeight: 2)
                  : null,
            ),
          ],
        );
      },
    );
  }
}
