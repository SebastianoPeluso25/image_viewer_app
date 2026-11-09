class FolderNode {
  final String name;
  final String path;

  /// Foto direttamente contenute in questa cartella.
  final int photoCount;

  /// Foto contenute in questa cartella e in tutte le sottocartelle.
  final int totalCount;
  final List<FolderNode> children;

  FolderNode({
    required this.name,
    required this.path,
    required this.photoCount,
    required this.totalCount,
    required this.children,
  });

  factory FolderNode.fromJson(Map<String, dynamic> json) {
    return FolderNode(
      name: json['name'],
      path: json['path'],
      photoCount: json['photoCount'] ?? 0,
      totalCount: json['totalCount'] ?? 0,
      children: (json['children'] as List? ?? [])
          .map((c) => FolderNode.fromJson(c as Map<String, dynamic>))
          .toList(),
    );
  }

  /// Restituisce il percorso (lista di nodi) dalla radice fino alla cartella [target].
  List<FolderNode>? pathTo(String target) {
    if (path.toLowerCase() == target.toLowerCase()) return [this];
    for (final child in children) {
      final sub = child.pathTo(target);
      if (sub != null) return [this, ...sub];
    }
    return null;
  }
}
