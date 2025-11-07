import 'package:flutter/material.dart';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:saf/saf.dart';

class RetroarchConfigPage extends StatefulWidget {
  const RetroarchConfigPage({Key? key}) : super(key: key);

  @override
  State<RetroarchConfigPage> createState() => _RetroarchConfigPageState();
}

class _RetroarchConfigPageState extends State<RetroarchConfigPage> {
  String? _sourcePath;
  String? _sourceTreeUri;
  bool _isCopying = false;
  bool _nativeCopiedToRetro = false;
  String _status = '';
  final List<String> _debugLogs = [];

  void _addLog(String msg) {
    final line = '${DateTime.now().toIso8601String()}  $msg';
    // garder un buffer raisonnable
    setState(() {
      _debugLogs.add(line);
      if (_debugLogs.length > 200)
        _debugLogs.removeRange(0, _debugLogs.length - 200);
    });
    print(line);
  }

  Future<void> _selectSourceFolder() async {
    try {
      setState(() => _status = 'Sélection du dossier...');
      _addLog('Début sélection dossier');

      // Note: ne pas purger automatiquement les permissions persistées ici
      // car cela peut supprimer une URI valide avant d'en obtenir une nouvelle.

      // 1) Ouvrir le picker SAF (dynamique)
      final bool? granted = await Saf.getDynamicDirectoryPermission();
      if (!mounted) return;
      _addLog('Saf.getDynamicDirectoryPermission => $granted');

      if (granted != true) {
        setState(() => _status = 'Aucun dossier sélectionné');
        return;
      }

      // 2) Récupérer la liste des URIs persistées
      List<String>? dirs;
      try {
        dirs = await Saf.getPersistedPermissionDirectories();
        _addLog(
          'Saf.getPersistedPermissionDirectories => ${dirs?.length ?? 0} entries: ${dirs ?? 'null'}',
        );
      } catch (e) {
        dirs = null;
        _addLog('Exception getPersistedPermissionDirectories: $e');
      }
      if (!mounted) return;

      if (dirs == null || dirs.isEmpty) {
        // Tentative de fallback : forcer l'ouverture du picker "Files by Google"
        // via un MethodChannel natif (MainActivity) qui lance ACTION_OPEN_DOCUMENT_TREE
        final fallbackUri = await _openDocsUIDocumentTree();
        if (!mounted) return;
        _addLog('Fallback picker returned URI: $fallbackUri');
        if (fallbackUri != null) {
          // If the native fallback returned a local cache path (copied by native code),
          // prefer using that directly instead of trying to use SAF.sync().
          if (fallbackUri.startsWith('/')) {
            // local absolute path returned by native copy
            if (mounted) {
              setState(() {
                _sourceTreeUri = fallbackUri;
                _sourcePath = fallbackUri;
                if (fallbackUri.contains('/RetroArch')) {
                  _nativeCopiedToRetro = true;
                  _status =
                      'Copie terminée : fichiers présents dans RetroArch ($fallbackUri)';
                } else {
                  _status =
                      'Fichiers copiés dans le cache natif : $fallbackUri';
                }
              });
            }
            _addLog(
              'Native picker returned local cache path, using it as source: $fallbackUri',
            );
            return;
          }

          // sinon, traiter comme une URI SAF/content et tenter un sync
          // tenter de synchroniser directement sur l'URI retournée
          final normalizedUri = normalizeTreeUri(fallbackUri);
          if (mounted)
            setState(() => _status = 'Normalized URI: $normalizedUri');
          _addLog('Normalized URI: $normalizedUri');
          final safDir = Saf(normalizedUri);
          bool? syncedFallback;
          try {
            _addLog('Calling saf.sync() on normalized URI');
            syncedFallback = await safDir.sync();
            _addLog('saf.sync() returned: $syncedFallback');
          } catch (e) {
            _addLog(
              'Exception during safDir.sync() for fallbackUri=$fallbackUri : $e',
            );
            if (!mounted) return;
            setState(() {
              _sourceTreeUri = null;
              _sourcePath = null;
              _status =
                  'Impossible de synchroniser le dossier sélectionné (fallback) : $e';
            });
            return;
          }
          if (!mounted) return;
          if (syncedFallback == true) {
            setState(() {
              _sourceTreeUri = fallbackUri;
              _sourcePath = fallbackUri;
              _status =
                  'Dossier synchronisé et prêt pour la copie (via DocsUI)';
            });
            _addLog('Fallback sync successful, sourceTreeUri set');
            return;
          } else {
            // si sync retourne false, essayer de lister les persisted dirs pour mieux diagnostiquer
            List<String>? postDirs;
            try {
              postDirs = await Saf.getPersistedPermissionDirectories();
            } catch (e) {
              postDirs = null;
            }
            _addLog('Post-pick persisted dirs: ${postDirs ?? 'null'}');
            setState(() {
              _sourceTreeUri = null;
              _sourcePath = null;
              _status =
                  'Impossible de synchroniser le dossier sélectionné (fallback). URI: $fallbackUri\nPersisted dirs post-pick: ${postDirs ?? 'null'}';
            });
            _addLog(
              'Fallback sync returned false; updated UI status with persisted dirs',
            );
            return;
          }
        }

        setState(() {
          _sourceTreeUri = null;
          _sourcePath = null;
          _status = 'Impossible de récupérer le dossier sélectionné';
        });
        return;
      }

      // 3) Sélectionne prudemment l’index 0 (certains bugs apparaissent avec .last)
      //    et vérifie qu’il y a bien au moins 1 élément
      final String selectedTreeUri = dirs[0];

      // 4) Vérifier que cette URI est bien persistée (sécurité)
      bool isPersisted = false;
      try {
        isPersisted =
            (await Saf.isPersistedPermissionDirectoryFor(selectedTreeUri)) ==
            true;
        _addLog(
          'Saf.isPersistedPermissionDirectoryFor($selectedTreeUri) => $isPersisted',
        );
      } catch (e) {
        isPersisted =
            true; // certains firmwares renvoient une erreur alors que c’est OK
        _addLog('Exception isPersistedPermissionDirectoryFor: $e');
      }
      if (!mounted) return;

      if (!isPersisted) {
        setState(() {
          _sourceTreeUri = null;
          _sourcePath = null;
          _status = 'Le dossier n’a pas été correctement persisté';
        });
        return;
      }

      // 5) Sync le cache local sur CETTE URI
      final safDir = Saf(selectedTreeUri);
      _addLog('Calling saf.sync() on selectedTreeUri');
      final bool? synced = await safDir.sync();
      _addLog('saf.sync() on selectedTreeUri returned: $synced');
      if (!mounted) return;

      if (synced != true) {
        setState(
          () => _status = 'Impossible de synchroniser le dossier sélectionné',
        );
        return;
      }

      // 6) OK : maj de l’état
      setState(() {
        _sourceTreeUri = selectedTreeUri; // content://...
        _sourcePath = selectedTreeUri; // affichage
        _status = 'Dossier synchronisé et prêt pour la copie';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _status = 'Erreur lors de la sélection : $e');
    }
  }

  static const MethodChannel _platform = MethodChannel('back_to_childhood/app');

  Future<String?> _openDocsUIDocumentTree() async {
    try {
      final dynamic res = await _platform.invokeMethod(
        'openDocumentTreeWithDocsUI',
      );

      // res should be a Map with uri, flags, takeFlags, persisted
      if (res == null) return null;

      String returnedUri = '';
      if (res is String) {
        returnedUri = res;
        _addLog('Native picker returned string URI: $returnedUri');
      } else if (res is Map) {
        // The native side may return diagnostic info AND perform an immediate copy.
        // If native copying happened, it'll include 'copiedCachePath' and 'files'.
        final rawUri = res['uri'] ?? '';
        final int flags = res['flags'] ?? 0;
        final int takeFlags = res['takeFlags'] ?? 0;
        final persisted = res['persisted'];
        final persistedStr = (persisted is List)
            ? persisted
                  .map((e) => '${e['uri']} (r=${e['read']}, w=${e['write']})')
                  .join('\n')
            : persisted.toString();

        final String? copiedCachePath = (res['copiedCachePath'] is String)
            ? res['copiedCachePath'] as String
            : null;
        final List<dynamic>? copiedFiles = (res['files'] is List)
            ? (res['files'] as List<dynamic>)
            : null;
        final bool copiedToRetro = res['copiedToRetroArch'] == true;
        final String? retroarchPath = (res['retroarchPath'] is String)
            ? res['retroarchPath'] as String
            : null;

        // If native provided a local cache path, prefer returning that so Dart can
        // use local files directly (no SAF persistence required).
        if (copiedToRetro &&
            retroarchPath != null &&
            retroarchPath.isNotEmpty) {
          // Native already copied files into RetroArch; return that path so Dart can show success.
          returnedUri = retroarchPath;
          _nativeCopiedToRetro = true;
          if (mounted) {
            setState(() {
              _status =
                  'Picker copied files directly into RetroArch: $retroarchPath';
            });
          }
          _addLog(
            'Native picker copied files directly into RetroArch: $retroarchPath',
          );
        } else if (copiedCachePath != null && copiedCachePath.isNotEmpty) {
          returnedUri = copiedCachePath;
          if (mounted) {
            setState(() {
              _status =
                  'Picker copied files to local cache: $copiedCachePath\nfiles: ${copiedFiles?.length ?? 0}';
            });
          }
          _addLog(
            'Native picker copied files to cache: $copiedCachePath (${copiedFiles?.length ?? 0} files)',
          );
        } else {
          returnedUri = rawUri;
          if (mounted) {
            setState(() {
              _status =
                  'Picker returned URI: $returnedUri\nflags=$flags takeFlags=$takeFlags\nPersisted:\n$persistedStr';
            });
            _addLog(
              'Native picker response: uri=$returnedUri flags=$flags takeFlags=$takeFlags persisted=$persistedStr',
            );
          }
        }
      } else {
        returnedUri = res.toString();
      }

      return returnedUri.isNotEmpty ? returnedUri : null;
    } on PlatformException catch (e) {
      print('PlatformException openDocsUI: $e');
      if (!mounted) return null;
      setState(
        () => _status =
            'Erreur plateforme lors de l\'ouverture du picker: ${e.message}',
      );
      return null;
    } catch (e) {
      print('Error openDocsUI: $e');
      if (!mounted) return null;
      setState(
        () => _status = 'Erreur inconnue lors de l\'ouverture du picker: $e',
      );
      return null;
    }
  }

  String normalizeTreeUri(String uri) {
    // Tentatives successives pour corriger les doubles-embeddings / double-encodages
    String res = uri;

    // Cas simple : content://content:// -> content://
    res = res.replaceAll('content://content://', 'content://');

    // Remplacer les patterns encodés qui apparaissent dans vos logs
    res = res.replaceAll('primary%3Acontent:%2F%2F', 'primary%3A');
    res = res.replaceAll('%3Acontent%3A%2F%2F', '%3A');

    // Cas non-encodé
    res = res.replaceAll('primary:content://', 'primary:');

    // Nettoyage générique : enlever occurrences de 'content:%2F%2F' embarquées
    res = res.replaceAll('content:%2F%2F', 'content://');

    // Log utile pour debug (visible dans la Card État)
    print('normalizeTreeUri: in=$uri out=$res');
    return res;
  }

  Future<void> _copyFiles() async {
    if (_sourceTreeUri == null) {
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
      // Créer le dossier RetroArch s'il n'existe pas
      final retroarchPath = '/storage/emulated/0/RetroArch';
      final retroarchDir = Directory(retroarchPath);
      if (!await retroarchDir.exists()) {
        await retroarchDir.create(recursive: true);
      }

      Directory sourceDir;

      // Si _sourceTreeUri est un chemin local (retourné par le natif), copier depuis ce dossier
      if (_sourceTreeUri!.startsWith('/') ||
          _sourceTreeUri!.startsWith('file://')) {
        final localPath = _sourceTreeUri!.startsWith('file://')
            ? _sourceTreeUri!.substring('file://'.length)
            : _sourceTreeUri!;
        sourceDir = Directory(localPath);
        _addLog('Using native-copied directory as source: $localPath');
        if (!await sourceDir.exists()) {
          throw Exception(
            'Le dossier source local fourni par le natif est introuvable: $localPath',
          );
        }
      } else {
        // Cas SAF/content:// : synchroniser vers un cache standard puis copier depuis le cache
        final saf = Saf(_sourceTreeUri!);

        // Créer un dossier cache temporaire pour le transfert (même emplacement attendu que le natif)
        final cacheDir = Directory(
          '/storage/emulated/0/Android/data/com.example.back_to_childhood/cache/saf_cache',
        );
        if (!await cacheDir.exists()) {
          await cacheDir.create(recursive: true);
        }

        // Synchroniser les fichiers du dossier SAF vers le cache
        bool? synced = await saf.sync();
        if (synced != true) {
          throw Exception(
            'Erreur lors de la synchronisation avec le dossier SAF',
          );
        }

        sourceDir = cacheDir;
      }

      // Copier les fichiers du dossier source (cache natif ou cache SAF) vers RetroArch
      final files = sourceDir.listSync().whereType<File>();
      for (final file in files) {
        if (!mounted) break;
        final fileName = file.path.split('/').last;
        setState(() => _status = 'Copie de $fileName...');

        final targetPath = '$retroarchPath/$fileName';
        try {
          await file.copy(targetPath);
        } catch (e) {
          print('Erreur lors de la copie de $fileName: $e');
        }
      }

      // Si nous avons synchronisé dans le cache SAF (et non utilisé un dossier natif
      // fourni par le code natif), le supprimer maintenant.
      try {
        if (sourceDir.path.contains(
          '/Android/data/com.example.back_to_childhood/cache/saf_cache',
        )) {
          if (await sourceDir.exists()) {
            await sourceDir.delete(recursive: true);
            _addLog('Deleted temp cache at ${sourceDir.path}');
          }
        }
      } catch (e) {
        // Ne pas bloquer la réussite finale si le nettoyage échoue
        _addLog('Failed to delete temp cache: $e');
      }

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
      appBar: AppBar(title: const Text('Configuration de RetroArch')),
      body: Column(
        children: [
          // Bandeau d'info
          Container(
            width: double.infinity,
            color: Colors.grey[850],
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: const Text(
              "Cette configuration permet d'installer les éléments que vous souhaitez dans RetroArch.\n"
              "Sélectionnez d'abord un dossier source, puis cliquez sur Copier pour copier son contenu dans RetroArch.",
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
                  ElevatedButton.icon(
                    onPressed: _isCopying ? null : _selectSourceFolder,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 16,
                      ),
                    ),
                    icon: const Icon(Icons.folder_open),
                    label: const Text('Sélectionner le dossier source'),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed:
                        (_sourcePath != null &&
                            !_isCopying &&
                            !_nativeCopiedToRetro)
                        ? _copyFiles
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 16,
                      ),
                    ),
                    icon: const Icon(Icons.copy),
                    label: const Text('Copier vers RetroArch'),
                  ),
                  if (_status.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          children: [
                            Text(
                              'État',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 8),
                            if (_sourcePath != null) ...[
                              Text(
                                'Dossier sélectionné :',
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _sourcePath!,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 8),
                            ],
                            Text(
                              _status,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: _status.contains('Erreur')
                                    ? Colors.red
                                    : _status.contains('succès')
                                    ? Colors.green
                                    : null,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  Text(
                    'Debug logs',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 8),
                  Container(
                    height: 200,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Scrollbar(
                      thumbVisibility: true,
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(8.0),
                        child: SelectableText(
                          _debugLogs.join('\n'),
                          style: const TextStyle(
                            fontSize: 12,
                            fontFamily: 'monospace',
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      ElevatedButton.icon(
                        onPressed: () {
                          final text = _debugLogs.join('\n');
                          Clipboard.setData(ClipboardData(text: text));
                          _addLog(
                            'Copied debug logs to clipboard (${_debugLogs.length} lines)',
                          );
                        },
                        icon: const Icon(Icons.copy),
                        label: const Text('Copier les logs'),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton(
                        onPressed: () {
                          setState(() => _debugLogs.clear());
                        },
                        child: const Text('Effacer'),
                      ),
                    ],
                  ),
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
