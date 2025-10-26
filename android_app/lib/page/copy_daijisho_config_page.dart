import 'dart:io';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:saf/saf.dart';

class CopyRetroarchCoresPage extends StatefulWidget {
  const CopyRetroarchCoresPage({Key? key}) : super(key: key);

  @override
  State<CopyRetroarchCoresPage> createState() => _CopyRetroarchCoresPageState();
}

class _CopyRetroarchCoresPageState extends State<CopyRetroarchCoresPage> {
  String _status = '';

  Future<void> _copyCoresWithSaf() async {
    setState(() => _status = 'Demande de permissions...');
    if (Platform.isAndroid) {
      final status = await Permission.manageExternalStorage.request();
      if (!status.isGranted) {
        setState(() => _status = 'Permission refusée.');
        openAppSettings();
        return;
      }
    }

    try {
      setState(() => _status = 'Sélectionne le dossier "cores" de RetroArch');
      final saf = Saf('');
      bool? granted = await saf.getDirectoryPermission(isDynamic: true);
      if (granted != true) {
        setState(
          () => _status = 'Aucun dossier sélectionné ou permission refusée.',
        );
        return;
      }

      // Récupère l'URI du dossier sélectionné
      final dirs = await Saf.getPersistedPermissionDirectories();
      if (dirs == null || dirs.isEmpty) {
        setState(
          () => _status = 'Impossible de récupérer le dossier sélectionné.',
        );
        return;
      }

      final safTarget = Saf(dirs.last);

      // Chemin source sur la SD card ou stockage public
      final sourceDir = Directory('/storage/6137-3239/config/daijisho');
      if (!sourceDir.existsSync()) {
        setState(() => _status = 'Dossier source introuvable.');
        return;
      }

      // Copie tous les fichiers du dossier source dans le cache local du SAF
      final cacheDir = Directory(
        '/storage/emulated/0/Android/data/${await _getPackageName()}/cache/saf_cache',
      );
      final files = sourceDir.listSync(recursive: true).whereType<File>();
      for (final file in files) {
        final relativePath = file.path.substring(sourceDir.path.length);
        final destFilePath = (relativePath.startsWith('/')
            ? relativePath.substring(1)
            : relativePath);
        final outFile = File('${cacheDir.path}/$destFilePath');
        await outFile.parent.create(recursive: true);
        await outFile.writeAsBytes(await file.readAsBytes());
      }

      // Synchronise le cache avec le dossier SAF
      bool? synced = await safTarget.sync();
      if (synced == true) {
        setState(() => _status = 'Cores copiés avec succès !');
      } else {
        setState(
          () => _status =
              'Erreur lors de la synchronisation avec le dossier SAF.',
        );
      }
    } catch (e) {
      setState(() => _status = 'Erreur : $e');
    }
  }

  Future<String> _getPackageName() async {
    // Pour un vrai nom dynamique, utiliser package_info_plus
    return 'com.example.insert_coin';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Copier cores RetroArch via SAF')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              onPressed: _copyCoresWithSaf,
              child: const Text('Copier cores via SAF'),
            ),
            const SizedBox(height: 20),
            Text(_status),
            const SizedBox(height: 20),
            const Text(
              'L’utilisateur doit sélectionner le dossier cores de RetroArch via le sélecteur SAF.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: Colors.red),
            ),
          ],
        ),
      ),
    );
  }
}
