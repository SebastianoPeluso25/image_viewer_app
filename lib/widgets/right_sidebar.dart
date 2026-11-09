import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/photo_provider.dart';
import '../providers/settings_provider.dart';

/// Barra laterale destra: impostazioni di aspetto, visualizzazione e ordinamento.
class RightSidebar extends StatelessWidget {
  const RightSidebar({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    // La larghezza è decisa da ResizableSidebar (regolabile dall'utente)
    return Container(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLowest,
        border: Border(
          left: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.6)),
        ),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.tune, color: scheme.primary),
                const SizedBox(width: 10),
                const Flexible(
                  child: Text(
                    "Impostazioni",
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // --- Aspetto e interfaccia ---
            _Section(
              title: "Aspetto",
              child: Consumer<SettingsProvider>(
                builder: (context, settings, child) {
                  final isDark = settings.themeMode == ThemeMode.dark;
                  return Column(
                    children: [
                      _SwitchRow(
                        icon: isDark
                            ? Icons.dark_mode_outlined
                            : Icons.light_mode_outlined,
                        label: "Tema scuro",
                        value: isDark,
                        onChanged: (_) => settings.toggleTheme(),
                      ),
                      _SwitchRow(
                        icon: Icons.label_outline,
                        label: "Mostra nomi delle foto",
                        value: settings.showPhotoNames,
                        onChanged: settings.setShowPhotoNames,
                      ),
                      _SwitchRow(
                        icon: Icons.search,
                        label: "Mostra barra di ricerca",
                        value: settings.showSearchBar,
                        onChanged: (value) {
                          settings.setShowSearchBar(value);
                          // Nascondendo la barra si azzera anche il filtro di ricerca
                          if (!value) context.read<PhotoProvider>().setSearchQuery('');
                        },
                      ),
                    ],
                  );
                },
              ),
            ),

            // --- Dimensione griglia ---
            _Section(
              title: "Dimensione miniature",
              child: Consumer<PhotoProvider>(
                builder: (context, provider, child) {
                  return Row(
                    children: [
                      Icon(
                        Icons.photo_size_select_small,
                        size: 18,
                        color: scheme.onSurfaceVariant,
                      ),
                      Expanded(
                        child: Slider(
                          value: provider.gridSize,
                          min: 100.0,
                          max: 400.0,
                          onChanged: provider.setGridSize,
                          onChangeEnd: (_) => provider.saveGridSize(),
                        ),
                      ),
                      Icon(
                        Icons.photo_size_select_large,
                        size: 22,
                        color: scheme.onSurfaceVariant,
                      ),
                    ],
                  );
                },
              ),
            ),

            // --- Ordinamento ---
            _Section(
              title: "Ordina per",
              child: Consumer<PhotoProvider>(
                builder: (context, provider, child) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _sortChip(provider, "Data", "created_at",
                              Icons.calendar_today_outlined),
                          _sortChip(
                              provider, "Nome", "name", Icons.sort_by_alpha),
                          _sortChip(provider, "Dimensione", "size",
                              Icons.straighten),
                        ],
                      ),
                      const SizedBox(height: 16),
                      SegmentedButton<String>(
                        segments: const [
                          ButtonSegment(
                            value: "ASC",
                            label: Text("Crescente"),
                            icon: Icon(Icons.arrow_upward, size: 18),
                          ),
                          ButtonSegment(
                            value: "DESC",
                            label: Text("Decrescente"),
                            icon: Icon(Icons.arrow_downward, size: 18),
                          ),
                        ],
                        selected: {provider.order},
                        showSelectedIcon: false,
                        onSelectionChanged: (sel) =>
                            provider.setSorting(provider.sortBy, sel.first),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sortChip(
    PhotoProvider provider,
    String label,
    String value,
    IconData icon,
  ) {
    final selected = provider.sortBy == value;
    return ChoiceChip(
      avatar: selected ? null : Icon(icon, size: 16),
      label: Text(label),
      selected: selected,
      onSelected: (_) => provider.setSorting(value, provider.order),
    );
  }
}

class _SwitchRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _SwitchRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () => onChanged(!value),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          children: [
            Icon(icon, size: 20, color: value ? scheme.primary : scheme.onSurfaceVariant),
            const SizedBox(width: 12),
            Expanded(child: Text(label)),
            Switch(value: value, onChanged: onChanged),
          ],
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final Widget child;

  const _Section({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title.toUpperCase(),
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.1,
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}
