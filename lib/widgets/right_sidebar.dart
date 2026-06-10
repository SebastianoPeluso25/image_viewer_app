import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/photo_provider.dart';
import '../providers/theme_provider.dart';

class RightSidebar extends StatelessWidget {
  const RightSidebar({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 300,
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(-2, 0),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Impostazioni",
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),
          Consumer<ThemeProvider>(
            builder: (context, themeProvider, child) {
              return ListTile(
                leading: Icon(
                  themeProvider.themeMode == ThemeMode.light
                      ? Icons.light_mode
                      : Icons.dark_mode,
                ),
                title: const Text("Tema Scuro"),
                trailing: Switch(
                  value: themeProvider.themeMode == ThemeMode.dark,
                  onChanged: (value) => themeProvider.toggleTheme(),
                ),
                contentPadding: EdgeInsets.zero,
              );
            },
          ),
          const Divider(height: 40),
          const Text(
            "Filtri e Ordinamento",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 24),
          const Text(
            "Dimensione Griglia",
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          Consumer<PhotoProvider>(
            builder: (context, provider, child) {
              return Slider(
                value: provider.gridSize,
                min: 100.0,
                max: 400.0,
                onChanged: (value) => provider.setGridSize(value),
              );
            },
          ),
          const Divider(height: 40),
          const Text(
            "Ordina per",
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          Consumer<PhotoProvider>(
            builder: (context, provider, child) {
              return Column(
                children: [
                  _sortOption(
                    context,
                    provider,
                    "Data di creazione",
                    "created_at",
                  ),
                  _sortOption(context, provider, "Nome", "name"),
                  _sortOption(context, provider, "Dimensione", "size"),
                ],
              );
            },
          ),
          const Divider(height: 40),
          const Text("Ordine", style: TextStyle(fontWeight: FontWeight.w600)),
          Consumer<PhotoProvider>(
            builder: (context, provider, child) {
              return Row(
                children: [
                  ChoiceChip(
                    label: const Text("Crescente"),
                    selected: provider.order == "ASC",
                    onSelected: (val) {
                      if (val) provider.setSorting(provider.sortBy, "ASC");
                    },
                  ),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    label: const Text("Decrescente"),
                    selected: provider.order == "DESC",
                    onSelected: (val) {
                      if (val) provider.setSorting(provider.sortBy, "DESC");
                    },
                  ),
                ],
              );
            },
          ),
          const Spacer(),
          ElevatedButton.icon(
            onPressed: () => _pickFolder(context),
            icon: const Icon(Icons.folder_open),
            label: const Text("Carica Cartella"),
            style: ElevatedButton.styleFrom(
              minimumSize: const Size.fromHeight(50),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sortOption(
    BuildContext context,
    PhotoProvider provider,
    String label,
    String value,
  ) {
    return RadioListTile<String>(
      title: Text(label, style: const TextStyle(fontSize: 14)),
      value: value,
      groupValue: provider.sortBy,
      contentPadding: EdgeInsets.zero,
      onChanged: (val) {
        if (val != null) provider.setSorting(val, provider.order);
      },
    );
  }

  Future<void> _pickFolder(BuildContext context) async {
    final provider = Provider.of<PhotoProvider>(context, listen: false);
    // Note: file_picker on Windows can pick directories.
    // In a real app we'd use file_picker.
    // For this demo, let's assume we can get a path.
    // Since I can't interactively pick a folder here, I'll show how it's done.
    /*
    String? selectedDirectory = await FilePicker.platform.getDirectoryPath();
    if (selectedDirectory != null) {
      provider.scanFolder(selectedDirectory);
    }
    */
    // For now, let's just trigger a dialog to enter a path or use a mock path if needed
    // But I'll leave the logic for file_picker.

    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Inserisci il percorso della cartella"),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: "C:\\Users\\..."),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Annulla"),
          ),
          TextButton(
            onPressed: () {
              provider.scanFolder(controller.text);
              Navigator.pop(context);
            },
            child: const Text("Scansiona"),
          ),
        ],
      ),
    );
  }
}
