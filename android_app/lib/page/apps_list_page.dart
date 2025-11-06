import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/services.dart';
import 'dart:io' show Platform;

// MethodChannel name must match Android MainActivity
const MethodChannel _appChannel = MethodChannel('insert_coin/app');

class AppData {
  final String name;
  final List<String> links;
  final String thumb;
  final List<String> ids;
  final String description;

  AppData({
    required this.name,
    required this.links,
    required this.thumb,
    required this.ids,
    required this.description,
  });
}

final List<AppData> apps = [
  AppData(
    name: 'RetroArch',
    links: [
      'https://play.google.com/store/apps/details?id=com.retroarch',
      'https://www.retroarch.com/?page=platforms',
    ],
    ids: ['com.retroarch', 'com.retroarch.aarch64'],
    thumb: 'lib/assets/apps/retro_arch.png',
    description:
        'RetroArch is a free and open-source, cross-platform frontend for emulators, game engines, video games, media players and other applications',
  ),
  AppData(
    name: 'Daijishō',
    links: [
      'https://play.google.com/store/apps/details?id=com.magneticchen.daijishou',
    ],
    ids: ['com.magneticchen.daijishou'],
    thumb: 'lib/assets/apps/daijisho.png',
    description:
        'Daijishō est un lanceur rétro qui vous permet de gérer vos bibliothèques de jeux rétro.',
  ),
  AppData(
    name: 'Dolphin',
    links: [
      'https://play.google.com/store/apps/details?id=org.dolphinemu.dolphinemu',
    ],
    ids: ['org.dolphinemu.dolphinemu'],
    thumb: 'lib/assets/apps/dolphin.png',
    description:
        'Dolphin is a free and open-source video game console emulator of the GameCube and Wii that runs on Windows, Linux, macOS, Android, Xbox One, Xbox Series X and Series S',
  ),
];

class AppsListPage extends StatefulWidget {
  const AppsListPage({super.key});

  @override
  State<AppsListPage> createState() => _AppsListPageState();
}

class _AppsListPageState extends State<AppsListPage> {
  // Create a GlobalKey for each AppListItem so we can call its state to refresh installation checks.
  final List<GlobalKey<_AppListItemState>> _itemKeys = List.generate(
    apps.length,
    (_) => GlobalKey<_AppListItemState>(),
  );

  Future<void> _refreshAll() async {
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(const SnackBar(content: Text('Actualisation...')));

    final futures = <Future<void>>[];
    for (final key in _itemKeys) {
      final state = key.currentState;
      if (state != null) {
        futures.add(state._checkInstalled());
      }
    }

    // Wait for visible items to finish. Items off-screen may not have a state yet.
    await Future.wait(futures);
    messenger.showSnackBar(
      const SnackBar(content: Text('Actualisation terminée')),
    );
  }

  bool areAllAppsInstalled() {
    for (final key in _itemKeys) {
      final state = key.currentState;
      if (state != null && (state._installed != true)) {
        return false;
      }
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Download apps'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Actualiser',
            onPressed: _refreshAll,
          ),
        ],
      ),
      body: Column(
        children: [
          // Info banner
          Container(
            width: double.infinity,
            color: Colors.grey[850],
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: const Text(
              "Ces app sont nécessaires pour le bon fonctionnement des jeux vidéo rétro. Elles seront toutes installées sur téléphone — Il faut prévoir 2Go.",
              style: TextStyle(color: Colors.white, fontSize: 14),
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: ListView.builder(
              itemCount: apps.length,
              itemBuilder: (context, index) {
                final app = apps[index];
                return AppListItem(key: _itemKeys[index], app: app);
              },
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: areAllAppsInstalled() ? () {} : null,
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
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
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

class _DropdownInstallButton extends StatefulWidget {
  final List<String> links;
  final bool installed;
  const _DropdownInstallButton({required this.links, this.installed = false});

  @override
  State<_DropdownInstallButton> createState() => _DropdownInstallButtonState();
}

class _DropdownInstallButtonState extends State<_DropdownInstallButton> {
  String? selectedLink;
  late String buttonText;

  void _openLink(String url) async {
    final uri = Uri.parse(url);
    // Play Store links need LaunchMode.externalApplication, website links work better with platformDefault
    final isPlayStore = uri.host.contains('play.google.com');
    final canLaunch = await canLaunchUrl(uri);
    print('Opening $url (can launch: $canLaunch)');

    if (canLaunch) {
      final mode = isPlayStore
          ? LaunchMode.externalApplication
          : LaunchMode.platformDefault;
      final launched = await launchUrl(uri, mode: mode);
      print('Launch result: $launched');
    } else {
      print('Cannot launch URL: $url');
    }
  }

  String _getDomain(String url) {
    try {
      final uri = Uri.parse(url);
      return uri.host.replaceFirst('www.', '');
    } catch (_) {
      return url;
    }
  }

  Future<void> _showMenu(BuildContext context) async {
    final RenderBox button = context.findRenderObject() as RenderBox;
    final RenderBox overlay =
        Overlay.of(context).context.findRenderObject() as RenderBox;
    final Offset position = button.localToGlobal(
      Offset.zero,
      ancestor: overlay,
    );
    // small gap between button and menu
    const double gap = 8.0;
    final selected = await showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
        position.dx,
        position.dy + button.size.height + gap,
        overlay.size.width - position.dx - button.size.width,
        overlay.size.height - position.dy - gap,
      ),
      color: const Color(0xFFA5C7FA),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      items: widget.links.map((link) {
        return PopupMenuItem<String>(
          value: link,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              _getDomain(link),
              style: const TextStyle(color: Color(0xFF052C5E), fontSize: 14),
            ),
          ),
        );
      }).toList(),
    );
    if (selected != null) _openLink(selected);
  }

  @override
  Widget build(BuildContext context) {
    final bool installed = widget.installed;
    return ElevatedButton(
      onPressed: () => _showMenu(context),
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFFA5C7FA),
        foregroundColor: const Color(0xFF052C5E),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        shape: const StadiumBorder(),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            installed ? 'Mettre à jour' : 'Récupérer',
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }
}

class AppListItem extends StatefulWidget {
  final AppData app;
  const AppListItem({required this.app, Key? key}) : super(key: key);

  @override
  State<AppListItem> createState() => _AppListItemState();
}

class _AppListItemState extends State<AppListItem> {
  bool? _installed;

  @override
  void initState() {
    super.initState();
    _checkInstalled();
  }

  // package id extraction removed because native plugin was removed; keep helper removal for now

  Future<void> _checkInstalled() async {
    bool installed = false;
    // Use platform channel to ask Android whether any of the package IDs is installed.
    if (Platform.isAndroid) {
      try {
        for (final pkg in widget.app.ids) {
          print('Checking if $pkg is installed...');
          final result = await _appChannel.invokeMethod<bool>(
            'isAppInstalled',
            {'packageName': pkg},
          );
          print('Package $pkg installation check result: $result');
          if (result == true) {
            installed = true;
            break;
          }
        }
      } on PlatformException catch (e) {
        print('Error checking package installation: ${e.message}');
        installed = false;
      } catch (e) {
        print('Unexpected error checking package: $e');
        installed = false;
      }
    } else {
      print('Not on Android, assuming not installed');
    }

    if (mounted) setState(() => _installed = installed);
  }

  void _openLink(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri))
      await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final app = widget.app;
    final installed = _installed == true;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.asset(
              app.thumb,
              width: 48,
              height: 48,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(app.name, style: const TextStyle(fontSize: 14)),
                const SizedBox(height: 4),
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
                        installed ? Icons.check : Icons.close,
                        size: 14,
                        color: Colors.white,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        installed ? 'Installé' : 'Pas encore installé',
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
          widget.app.links.length == 1
              ? ElevatedButton(
                  onPressed: () => _openLink(widget.app.links.first),
                  child: Text(installed ? 'Mettre à jour' : 'Récupérer'),
                )
              : _DropdownInstallButton(
                  links: widget.app.links,
                  installed: installed,
                ),
        ],
      ),
    );
  }
}
