import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import '../models/folder.dart';
import '../services/vault_service.dart';

class FolderTile extends StatelessWidget {
  final Folder folder;
  final String currentPath;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final Function(String) onNavigate;

  const FolderTile({
    super.key,
    required this.folder,
    required this.currentPath,
    required this.onEdit,
    required this.onDelete,
    required this.onNavigate,
  });

  @override
  Widget build(BuildContext context) {
    final counts = VaultService.getFolderCounts(folder);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Slidable(
        endActionPane: ActionPane(
          motion: const ScrollMotion(),
          children: [
            SlidableAction(
              onPressed: (context) => onEdit(),
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
              icon: Icons.edit,
              label: 'Edit',
            ),
            SlidableAction(
              onPressed: (context) => onDelete(),
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              icon: Icons.delete,
              label: 'Delete',
            ),
          ],
        ),
        child: ListTile(
          leading: const Icon(Icons.folder, color: Colors.amber),
          title: Text(folder.name),
          subtitle: folder.email != null ? Text(folder.email!) : null,
          trailing: Text(
            '${counts.$1} folders, ${counts.$2} accounts',
            style: const TextStyle(fontSize: 12),
          ),
          onTap: () => onNavigate('$currentPath > ${folder.name}'),
        ),
      ),
    );
  }
}
