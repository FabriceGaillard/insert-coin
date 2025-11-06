import 'package:flutter/material.dart';
// import 'package:file_picker/file_picker.dart';
import 'package:permission_handler/permission_handler.dart';

class RetroarchConfigPage extends StatefulWidget {
  const RetroarchConfigPage({Key? key}) : super(key: key);

  @override
  State<RetroarchConfigPage> createState() => _RetroarchConfigPageState();
}

class _RetroarchConfigPageState extends State<RetroarchConfigPage> {
  String? _sourcePath;
  bool _isCopying = false;
  String _status = '';

  Future<bool> _requestPermissions() async {
    // Vérifier et demander toutes les permissions nécessaires
    final permissions = [Permission.storage, Permission.manageExternalStorage];

    // Demander chaque permission
    for (final permission in permissions) {
      final status = await permission.status;
      if (!status.isGranted) {
        final result = await permission.request();
        if (!result.isGranted) {
          if (!mounted) return false;
          setState(
            () => _status = 'Permission ${permission.toString()} refusée',
          );
          return false;
        }
      }
    }
    return true;
  }

  Future<void> _selectSourceFolder() async {
    try {
      // Demander toutes les permissions nécessaires
      final permissionsGranted = await _requestPermissions();
      if (!permissionsGranted) {
        return;
      }

      // Sélecteur de dossier
      // final result = await FilePicker.platform.getDirectoryPath();

      if (!mounted) return;
      setState(() {
        // _sourcePath = result;
        // _status = result != null
        //     ? 'Dossier source sélectionné : $result'
        //     : 'Aucun dossier sélectionné';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _status = 'Erreur lors de la sélection : $e');
    }
  }

  Future<void> _copyFiles() async {
    if (_sourcePath == null) {
      setState(
        () => _status = 'Veuillez d\'abord sélectionner un dossier source',
      );
      return;
    }

    setState(() {
      _isCopying = true;
      _status = 'Copie en cours...';
    });

    try {
      // TODO: Implémenter la logique de copie avec SAF
      // 1) Lister les fichiers du dossier source
      // 2) Copier vers le répertoire RetroArch cible
      // 3) Afficher la progression

      if (!mounted) return;
      setState(() => _status = 'Copie terminée avec succès');
    } catch (e) {
      if (!mounted) return;
      setState(() => _status = 'Erreur lors de la copie : $e');
    } finally {
      if (!mounted) return;
      setState(() => _isCopying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Configuration de RetroArch'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Actualiser',
            onPressed: _isCopying ? null : () => setState(() => _status = ''),
          ),
        ],
      ),
      body: Column(
        children: [
          // Bandeau d'info
          Container(
            width: double.infinity,
            color: Colors.grey[850],
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: const Text(
              "Cette configuration installe les éléments essentiels pour faire fonctionner les émulateurs dans RetroArch. "
              "Sélectionnez d'abord le dossier source à copier.",
              style: TextStyle(color: Colors.white, fontSize: 14),
            ),
          ),
          // Corps
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ElevatedButton(
                    onPressed: _isCopying ? null : _selectSourceFolder,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFA5C7FA),
                      foregroundColor: const Color(0xFF052C5E),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 16,
                      ),
                      shape: const StadiumBorder(),
                    ),
                    child: const Text('Sélectionner le dossier source'),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: (_sourcePath != null && !_isCopying)
                        ? _copyFiles
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFA5C7FA),
                      foregroundColor: const Color(0xFF052C5E),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 16,
                      ),
                      shape: const StadiumBorder(),
                    ),
                    child: const Text('Copier les fichiers'),
                  ),
                  if (_status.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(_status),
                    ),
                  ],
                  if (_isCopying) ...[
                    const SizedBox(height: 16),
                    const LinearProgressIndicator(),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
