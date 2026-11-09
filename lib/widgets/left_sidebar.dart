import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/folder_node.dart';
import '../providers/photo_provider.dart';

/// Barra laterale sinistra: mostra l'albero delle cartelle con le foto.
/// Permette di rimuovere una o più cartelle SOLO dall'app (i file restano sul disco).
class LeftSidebar extends StatelessWidget {
  const LeftSidebar({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      width: 280,
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLowest,
        border: Border(
          right: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.6)),
        ),
      ),
      child: Consumer<PhotoProvider>(
        builder: (context, provider, child) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildHeader(context, provider),
              if (provider.isScanning)
                const LinearProgressIndicator(minHeight: 2),
              Expanded(child: _buildContent(context, provider)),
              const Divider(),
              Padding(
                padding: const EdgeInsets.all(16),
                child: provider.selectionMode
                    ? _buildSelectionActions(context, provider)
                    : _buildDefaultActions(context, provider),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildHeader(BuildContext context, PhotoProvider provider) {
    final scheme = Theme.of(context).colorScheme;
    final selecting = provider.selectionMode;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 12, 8),
      child: Row(
        children: [
          Text(
            selecting
                ? "${provider.checkedFolders.length} SELEZIONATE"
                : "CARTELLE",
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
              color: selecting ? scheme.primary : scheme.onSurfaceVariant,
            ),
          ),
          const Spacer(),
          if (provider.folderTree != null && provider.folderTree!.children.isNotEmpty)
            IconButton(
              tooltip: selecting ? "Annulla selezione" : "Seleziona cartelle da rimuovere",
              visualDensity: VisualDensity.compact,
              isSelected: selecting,
              icon: const Icon(Icons.checklist, size: 20),
              selectedIcon: const Icon(Icons.close, size: 20),
              onPressed: provider.isScanning
                  ? null
                  : () => provider.setSelectionMode(!selecting),
            ),
          if (provider.rootFolder != null && !selecting)
            IconButton(
              tooltip: "Aggiorna",
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.refresh, size: 20),
              onPressed: provider.isScanning ? null : provider.refresh,
            ),
        ],
      ),
    );
  }

  Widget _buildDefaultActions(BuildContext context, PhotoProvider provider) {
    final removedCount = provider.excludedFolders.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (removedCount > 0) ...[
          TextButton.icon(
            onPressed: provider.isScanning ? null : () => _showRemovedFolders(context),
            icon: const Icon(Icons.folder_off_outlined, size: 18),
            label: Text("Cartelle rimosse ($removedCount)"),
          ),
          const SizedBox(height: 8),
        ],
        FilledButton.icon(
          onPressed: provider.isScanning ? null : () => pickRootFolder(context),
          icon: const Icon(Icons.create_new_folder_outlined),
          label: Text(
            provider.rootFolder == null ? "Scegli cartella" : "Cambia cartella",
          ),
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(48),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ],
    );
  }

  Widget _buildSelectionActions(BuildContext context, PhotoProvider provider) {
    final scheme = Theme.of(context).colorScheme;
    final count = provider.checkedFolders.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FilledButton.icon(
          onPressed: count == 0
              ? null
              : () => confirmAndRemoveFolders(context, provider.checkedFolders.toList()),
          icon: const Icon(Icons.folder_delete_outlined),
          label: Text(count == 0 ? "Seleziona le cartelle" : "Rimuovi dall'app ($count)"),
          style: FilledButton.styleFrom(
            backgroundColor: scheme.error,
            foregroundColor: scheme.onError,
            minimumSize: const Size.fromHeight(48),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        const SizedBox(height: 8),
        OutlinedButton(
          onPressed: () => provider.setSelectionMode(false),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(44),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: const Text("Annulla"),
        ),
      ],
    );
  }

  Widget _buildContent(BuildContext context, PhotoProvider provider) {
    final scheme = Theme.of(context).colorScheme;
    final tree = provider.folderTree;

    if (provider.rootFolder == null || tree == null) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.folder_copy_outlined,
              size: 48,
              color: scheme.primary.withValues(alpha: 0.6),
            ),
            const SizedBox(height: 12),
            Text(
              provider.rootFolder == null
                  ? "Scegli una cartella (es. FOTO) per vedere qui tutte le sue sottocartelle."
                  : "Impossibile leggere la cartella.\nVerifica che il server sia avviato.",
              textAlign: TextAlign.center,
              style: TextStyle(color: scheme.onSurfaceVariant, height: 1.4),
            ),
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      children: [
        if (provider.selectionMode)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            child: Text(
              "Spunta le cartelle da togliere dall'app. I file restano sul computer.",
              style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant, height: 1.3),
            ),
          )
        else
          _FolderRow(
            icon: Icons.photo_library_outlined,
            selectedIcon: Icons.photo_library,
            label: "Tutte le foto",
            depth: 0,
            selected: provider.selectedFolder == null,
            onTap: () => provider.selectFolder(null),
          ),
        const SizedBox(height: 4),
        _FolderTreeTile(node: tree, depth: 0, initiallyExpanded: true, isRoot: true),
      ],
    );
  }

  Future<void> _showRemovedFolders(BuildContext context) {
    return showDialog(
      context: context,
      builder: (_) => const _RemovedFoldersDialog(),
    );
  }
}

/// Apre il selettore di cartelle di sistema e imposta la cartella radice.
Future<void> pickRootFolder(BuildContext context) async {
  final provider = Provider.of<PhotoProvider>(context, listen: false);
  final selected = await FilePicker.platform.getDirectoryPath(
    dialogTitle: "Scegli la cartella delle foto",
  );
  if (selected != null && selected.isNotEmpty) {
    await provider.setRootFolder(selected);
  }
}

/// Mostra il popup di conferma e, se confermato, rimuove le cartelle
/// SOLO dall'app e dal database. I file sul computer non vengono toccati.
Future<void> confirmAndRemoveFolders(BuildContext context, List<String> paths) async {
  final provider = context.read<PhotoProvider>();
  final messenger = ScaffoldMessenger.of(context);
  final tree = provider.folderTree;

  // Tiene solo le cartelle "più esterne": le sottocartelle di una cartella
  // già selezionata sono comunque incluse e non vanno contate due volte.
  final nodes = <FolderNode>[];
  for (final p in paths) {
    final chain = tree?.pathTo(p);
    if (chain == null) continue;
    final hasSelectedAncestor = chain
        .take(chain.length - 1)
        .any((a) => paths.any((x) => x.toLowerCase() == a.path.toLowerCase()));
    if (!hasSelectedAncestor) nodes.add(chain.last);
  }
  if (nodes.isEmpty) return;

  final confirmed = await showDialog<bool>(
    context: context,
    builder: (_) => _ConfirmRemoveDialog(folders: nodes),
  );
  if (confirmed != true) return;

  try {
    final removed = await provider.removeFolders(nodes.map((n) => n.path).toList());
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          "${nodes.length == 1 ? "Cartella rimossa" : "${nodes.length} cartelle rimosse"} "
          "dall'app ($removed foto). I file sono ancora sul computer.",
        ),
      ),
    );
  } catch (e) {
    messenger.showSnackBar(
      const SnackBar(content: Text("Impossibile rimuovere le cartelle. Il server è avviato?")),
    );
  }
}

class _ConfirmRemoveDialog extends StatelessWidget {
  final List<FolderNode> folders;

  const _ConfirmRemoveDialog({required this.folders});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final photoCount = folders.fold<int>(0, (sum, f) => sum + f.totalCount);
    final single = folders.length == 1;

    return AlertDialog(
      icon: Icon(Icons.folder_delete_outlined, color: scheme.error, size: 32),
      title: Text(single ? "Rimuovere la cartella dall'app?" : "Rimuovere ${folders.length} cartelle dall'app?"),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Elenco delle cartelle coinvolte
            Container(
              constraints: const BoxConstraints(maxHeight: 160),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: scheme.outlineVariant),
              ),
              child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.symmetric(vertical: 4),
                children: [
                  for (final f in folders)
                    ListTile(
                      dense: true,
                      leading: Icon(Icons.folder_outlined, color: scheme.primary),
                      title: Text(f.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: Text(f.path, maxLines: 1, overflow: TextOverflow.ellipsis),
                      trailing: Text("${f.totalCount} foto"),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text(
              "${single ? "La cartella" : "Le cartelle"}, le sottocartelle e le "
              "$photoCount foto contenute verranno rimosse dall'app e dal database.",
            ),
            const SizedBox(height: 12),
            // Rassicurazione ben visibile: nulla viene cancellato dal disco
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: scheme.primaryContainer,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.verified_user_outlined, color: scheme.primary, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      "Le foto NON verranno eliminate dal computer: i file restano "
                      "nella loro cartella sul disco. Potrai ripristinare la cartella "
                      "in qualsiasi momento da \"Cartelle rimosse\".",
                      style: TextStyle(color: scheme.onPrimaryContainer, height: 1.35),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text("Annulla"),
        ),
        FilledButton.icon(
          onPressed: () => Navigator.pop(context, true),
          icon: const Icon(Icons.folder_delete_outlined, size: 18),
          label: const Text("Rimuovi dall'app"),
          style: FilledButton.styleFrom(
            backgroundColor: scheme.error,
            foregroundColor: scheme.onError,
          ),
        ),
      ],
    );
  }
}

/// Elenco delle cartelle rimosse, con la possibilità di ripristinarle.
class _RemovedFoldersDialog extends StatefulWidget {
  const _RemovedFoldersDialog();

  @override
  State<_RemovedFoldersDialog> createState() => _RemovedFoldersDialogState();
}

class _RemovedFoldersDialogState extends State<_RemovedFoldersDialog> {
  final Set<String> _restoring = {};

  Future<void> _restore(List<String> paths) async {
    setState(() => _restoring.addAll(paths));
    try {
      await context.read<PhotoProvider>().restoreFolders(paths);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Impossibile ripristinare. Il server è avviato?")),
        );
      }
    }
    if (mounted) setState(() => _restoring.removeAll(paths));
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final folders = context.watch<PhotoProvider>().excludedFolders;

    return AlertDialog(
      title: const Text("Cartelle rimosse"),
      content: SizedBox(
        width: 460,
        child: folders.isEmpty
            ? const Text("Nessuna cartella rimossa.")
            : Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Queste cartelle sono nascoste dall'app. Ripristinandole, "
                    "le foto tornano visibili.",
                    style: TextStyle(color: scheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: 12),
                  Flexible(
                    child: ListView(
                      shrinkWrap: true,
                      children: [
                        for (final path in folders)
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: const Icon(Icons.folder_off_outlined),
                            title: Text(
                              path.split(RegExp(r'[\\/]')).where((s) => s.isNotEmpty).last,
                              style: const TextStyle(fontWeight: FontWeight.w600),
                            ),
                            subtitle: Text(path, maxLines: 1, overflow: TextOverflow.ellipsis),
                            trailing: _restoring.contains(path)
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : TextButton.icon(
                                    onPressed: () => _restore([path]),
                                    icon: const Icon(Icons.restore, size: 18),
                                    label: const Text("Ripristina"),
                                  ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
      ),
      actions: [
        if (folders.length > 1)
          TextButton(
            onPressed: _restoring.isEmpty ? () => _restore(List.of(folders)) : null,
            child: const Text("Ripristina tutte"),
          ),
        FilledButton.tonal(
          onPressed: () => Navigator.pop(context),
          child: const Text("Chiudi"),
        ),
      ],
    );
  }
}

class _FolderTreeTile extends StatefulWidget {
  final FolderNode node;
  final int depth;
  final bool initiallyExpanded;
  final bool isRoot;

  /// true se una cartella che contiene questa è spuntata (quindi è già inclusa).
  final bool ancestorChecked;

  const _FolderTreeTile({
    required this.node,
    required this.depth,
    this.initiallyExpanded = false,
    this.isRoot = false,
    this.ancestorChecked = false,
  });

  @override
  State<_FolderTreeTile> createState() => _FolderTreeTileState();
}

class _FolderTreeTileState extends State<_FolderTreeTile> {
  late bool _expanded = widget.initiallyExpanded;

  Future<void> _showContextMenu(Offset position) async {
    final scheme = Theme.of(context).colorScheme;
    final choice = await showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(position.dx, position.dy, position.dx, position.dy),
      items: [
        PopupMenuItem(
          value: 'remove',
          child: Row(
            children: [
              Icon(Icons.folder_delete_outlined, size: 20, color: scheme.error),
              const SizedBox(width: 12),
              const Text("Rimuovi dall'app"),
            ],
          ),
        ),
        const PopupMenuItem(
          value: 'select',
          child: Row(
            children: [
              Icon(Icons.checklist, size: 20),
              SizedBox(width: 12),
              Text("Seleziona più cartelle"),
            ],
          ),
        ),
      ],
    );
    if (!mounted) return;
    final provider = context.read<PhotoProvider>();
    if (choice == 'remove') {
      await confirmAndRemoveFolders(context, [widget.node.path]);
    } else if (choice == 'select') {
      provider.setSelectionMode(true);
      provider.toggleChecked(widget.node.path);
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PhotoProvider>();
    final node = widget.node;
    final hasChildren = node.children.isNotEmpty;
    final selecting = provider.selectionMode;

    final checkedSelf = provider.checkedFolders.contains(node.path);
    final checked = checkedSelf || widget.ancestorChecked;
    final selected = !selecting &&
        provider.selectedFolder?.toLowerCase() == node.path.toLowerCase();

    // La cartella principale non si rimuove: per quella c'è "Cambia cartella"
    final canCheck = selecting && !widget.isRoot && !widget.ancestorChecked;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _FolderRow(
          icon: Icons.folder_outlined,
          selectedIcon: Icons.folder_open,
          label: node.name,
          count: node.photoCount,
          depth: widget.depth,
          selected: selected,
          checked: selecting && !widget.isRoot ? checked : null,
          checkEnabled: canCheck,
          expanded: hasChildren ? _expanded : null,
          onToggle: hasChildren ? () => setState(() => _expanded = !_expanded) : null,
          onSecondaryTapDown: widget.isRoot || selecting
              ? null
              : (details) => _showContextMenu(details.globalPosition),
          onTap: () {
            if (selecting) {
              if (canCheck) provider.toggleChecked(node.path);
              return;
            }
            provider.selectFolder(node.path);
            if (hasChildren && !_expanded) setState(() => _expanded = true);
          },
        ),
        if (hasChildren && _expanded)
          for (final child in node.children)
            _FolderTreeTile(
              node: child,
              depth: widget.depth + 1,
              ancestorChecked: checked && !widget.isRoot,
            ),
      ],
    );
  }
}

class _FolderRow extends StatelessWidget {
  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final int? count;
  final int depth;
  final bool selected;
  final bool? expanded; // null = nessuna sottocartella
  final bool? checked; // null = nessuna casella di selezione
  final bool checkEnabled;
  final VoidCallback onTap;
  final VoidCallback? onToggle;
  final GestureTapDownCallback? onSecondaryTapDown;

  const _FolderRow({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.depth,
    required this.selected,
    required this.onTap,
    this.count,
    this.expanded,
    this.checked,
    this.checkEnabled = true,
    this.onToggle,
    this.onSecondaryTapDown,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final count = this.count;
    final checked = this.checked;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Material(
        color: selected
            ? scheme.primaryContainer
            : (checked == true ? scheme.errorContainer.withValues(alpha: 0.5) : Colors.transparent),
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          onSecondaryTapDown: onSecondaryTapDown,
          child: Padding(
            padding: EdgeInsets.only(
              left: 4.0 + depth * 16,
              right: 10,
              top: checked != null ? 2 : 7,
              bottom: checked != null ? 2 : 7,
            ),
            child: Row(
              children: [
                SizedBox(
                  width: 24,
                  child: expanded == null
                      ? null
                      : InkResponse(
                          radius: 14,
                          onTap: onToggle,
                          child: AnimatedRotation(
                            turns: expanded! ? 0.25 : 0,
                            duration: const Duration(milliseconds: 150),
                            child: Icon(
                              Icons.chevron_right,
                              size: 18,
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                ),
                if (checked != null)
                  SizedBox(
                    width: 32,
                    height: 36,
                    child: Checkbox(
                      value: checked,
                      onChanged: checkEnabled ? (_) => onTap() : null,
                      activeColor: scheme.error,
                      visualDensity: VisualDensity.compact,
                    ),
                  )
                else
                  Icon(
                    selected ? selectedIcon : icon,
                    size: 20,
                    color: selected ? scheme.primary : scheme.onSurfaceVariant,
                  ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: selected ? scheme.onPrimaryContainer : scheme.onSurface,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                    ),
                  ),
                ),
                if (count != null && count > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: selected ? scheme.primary : scheme.surfaceContainerHigh,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      "$count",
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: selected ? scheme.onPrimary : scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
