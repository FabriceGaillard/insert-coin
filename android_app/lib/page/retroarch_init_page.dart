import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:io' show Directory, Platform;
import 'retroarch_config_page.dart';

const MethodChannel _appChannel = MethodChannel('back_to_childhood/app');

class RetroarchInitPage extends StatefulWidget {
  const RetroarchInitPage({Key? key}) : super(key: key);

  @override
  State<RetroarchInitPage> createState() => _RetroarchInitPageState();
}

class _RetroarchInitPageState extends State<RetroarchInitPage> {
  bool _retroArchFolderExists = false;

  @override
  void initState() {
    super.initState();
    _checkRetroArchFolder();
  }

  Future<void> _checkRetroArchFolder() async {
    if (!Platform.isAndroid) {
      if (!mounted) return;
      setState(() => _retroArchFolderExists = false);
      return;
    }

    try {
      // Plusieurs emplacements possibles selon l’archi et la version
      final paths = <String>[
        '/storage/emulated/0/RetroArch',
        '/sdcard/RetroArch',
        '/storage/emulated/0/Android/data/com.retroarch/files',
        '/storage/emulated/0/Android/data/com.retroarch.aarch64/files',
      ];

      for (final path in paths) {
        final directory = Directory(path);
        debugPrint('Vérification du chemin: $path');
        if (await directory.exists()) {
          debugPrint('Dossier trouvé à: $path');
          if (!mounted) return;
          setState(() => _retroArchFolderExists = true);
          return;
        }
      }

      if (!mounted) return;
      setState(() => _retroArchFolderExists = false);
    } catch (e) {
      debugPrint('Erreur lors de la vérification du dossier: $e');
      if (!mounted) return;
      setState(() => _retroArchFolderExists = false);
    }
  } // <-- ❗️ACCOLADE MANQUANTE ICI DANS TA VERSION

  Future<void> _openRetroArch(BuildContext context) async {
    const packageNames = ['com.retroarch', 'com.retroarch.aarch64'];
    final messenger = ScaffoldMessenger.of(context);

    try {
      for (final packageName in packageNames) {
        debugPrint('Vérification de $packageName...');
        final bool? isInstalled = await _appChannel.invokeMethod<bool>(
          'isAppInstalled',
          {'packageName': packageName},
        );
        debugPrint('$packageName installé: $isInstalled');

        if (isInstalled == true) {
          debugPrint('Tentative d\'ouverture de $packageName...');
          await _appChannel.invokeMethod<void>('openApp', {
            'packageName': packageName,
          });
          return;
        }
      }

      messenger.showSnackBar(
        const SnackBar(content: Text('RetroArch n\'est pas installé')),
      );
    } catch (e) {
      debugPrint('Erreur lors de l\'ouverture de RetroArch: $e');
      messenger.showSnackBar(
        SnackBar(content: Text('Impossible d\'ouvrir RetroArch: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Initialiser RetroArch'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Actualiser',
            onPressed: _checkRetroArchFolder,
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
              "Ouvrez RetroArch une première fois afin qu’il termine son installation interne."
              "Acceptez les autorisations demandées, puis revenez ici pour poursuivre la configuration.",
              style: TextStyle(color: Colors.white, fontSize: 14),
            ),
          ),
          // Corps
          Expanded(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Icône RetroArch
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Image.asset(
                        'lib/assets/apps/retro_arch.png',
                        width: 80,
                        height: 80,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Bouton ouvrir RetroArch
                  ElevatedButton(
                    onPressed: () => _openRetroArch(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFA5C7FA),
                      foregroundColor: const Color(0xFF052C5E),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 16,
                      ),
                      shape: const StadiumBorder(),
                    ),
                    child: const Text(
                      'Ouvrir RetroArch',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Indicateur d’état
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.grey[900],
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _retroArchFolderExists ? Icons.check : Icons.close,
                          size: 14,
                          color: Colors.white,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _retroArchFolderExists
                              ? 'Configuration présente'
                              : 'Configuration absente',
                          style: const TextStyle(
                            fontSize: 13,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Bouton Suivant
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              child: Opacity(
                opacity: _retroArchFolderExists ? 1.0 : 0.5,
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _retroArchFolderExists
                        ? () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    const RetroarchConfigPage(),
                              ),
                            );
                          }
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFA5C7FA),
                      foregroundColor: const Color(0xFF052C5E),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 24,
                      ),
                      shape: const StadiumBorder(),
                    ),
                    child: const Text(
                      'Suivant',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
