package com.example.back_to_childhood

import android.app.Activity
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.util.Log
import androidx.documentfile.provider.DocumentFile
import java.io.File
import java.io.FileOutputStream
import java.io.IOException
import java.io.InputStream
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "back_to_childhood/app"
    private val OPEN_DOCUMENT_TREE_REQUEST = 1001
    private var pendingResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "isAppInstalled" -> {
                    val packageName = call.argument<String>("packageName") ?: ""
                    try {
                        val pm = applicationContext.packageManager
                        val installed = try {
                            pm.getApplicationInfo(packageName, 0)
                            true
                        } catch (e: PackageManager.NameNotFoundException) {
                            false
                        }
                        result.success(installed)
                    } catch (e: Exception) {
                        Log.e("MainActivity", "Error checking package: $packageName", e)
                        result.error("ERROR", e.message, null)
                    }
                }
                "openApp" -> {
                    val packageName = call.argument<String>("packageName") ?: ""
                    try {
                        val pm = applicationContext.packageManager
                        val intent = pm.getLaunchIntentForPackage(packageName)
                        if (intent != null) {
                            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            applicationContext.startActivity(intent)
                            result.success(true)
                        } else {
                            result.error("NOT_FOUND", "No launch intent found for $packageName", null)
                        }
                    } catch (e: Exception) {
                        Log.e("MainActivity", "Error opening app: $packageName", e)
                        result.error("ERROR", e.message, null)
                    }
                }
                "openDocumentTreeWithDocsUI" -> {
                    // Lance ACTION_OPEN_DOCUMENT_TREE en ciblant l'app DocumentsUI (Files by Google)
                    try {
                        if (pendingResult != null) {
                            result.error("BUSY", "Another request is pending", null)
                            return@setMethodCallHandler
                        }

                        var intent = Intent(Intent.ACTION_OPEN_DOCUMENT_TREE)
                        // Forcer l'app Files by Google si disponible
                        intent.setPackage("com.google.android.documentsui")
                        intent.addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION or
                                Intent.FLAG_GRANT_WRITE_URI_PERMISSION or
                                Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION)

                        pendingResult = result
                        try {
                            // Essayer d'abord avec le package forcé
                            startActivityForResult(intent, OPEN_DOCUMENT_TREE_REQUEST)
                        } catch (e: Exception) {
                            Log.w("MainActivity", "DocsUI picker failed, fallback to generic picker", e)
                            // fallback: réessayer sans forcer le package
                            try {
                                intent = Intent(Intent.ACTION_OPEN_DOCUMENT_TREE)
                                intent.addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION or
                                        Intent.FLAG_GRANT_WRITE_URI_PERMISSION or
                                        Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION)
                                startActivityForResult(intent, OPEN_DOCUMENT_TREE_REQUEST)
                            } catch (e2: Exception) {
                                Log.e("MainActivity", "Generic picker also failed", e2)
                                val r = pendingResult
                                pendingResult = null
                                r?.error("ERROR", e2.message, null)
                            }
                        }
                    } catch (e: Exception) {
                        Log.e("MainActivity", "Error launching document tree picker", e)
                        result.error("ERROR", e.message, null)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == OPEN_DOCUMENT_TREE_REQUEST) {
            val result = pendingResult
            pendingResult = null

            if (resultCode == Activity.RESULT_OK && data != null) {
                val uri: Uri? = data.data
                if (uri != null) {
                    try {
                        // Prendre la permission persistante
                        val flags = data.flags
                        val takeFlags = (flags and (Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_GRANT_WRITE_URI_PERMISSION))
                        Log.d("MainActivity", "onActivityResult: uri=$uri, flags=$flags, takeFlags=$takeFlags")
                        contentResolver.takePersistableUriPermission(uri, takeFlags)

                        // Log current persisted permissions for diagnostics
                        val persisted = contentResolver.persistedUriPermissions
                        val persistedList = ArrayList<Map<String, Any>>()
                        for (p in persisted) {
                            Log.d("MainActivity", "persisted permission: uri=${p.uri}, read=${p.isReadPermission}, write=${p.isWritePermission}")
                            val entry: Map<String, Any> = mapOf(
                                "uri" to p.uri.toString(),
                                "read" to p.isReadPermission,
                                "write" to p.isWritePermission
                            )
                            persistedList.add(entry)
                        }

                        // Attempt to copy files from the picked tree into app-specific cache
                        val copiedFiles = ArrayList<String>()
                        var copiedCachePath: String? = null
                        var copiedToRetro = false
                        var retroarchPath: String? = null
                        try {
                            val tree = DocumentFile.fromTreeUri(this, uri)
                            val outBase: File? = getExternalFilesDir("saf_cache") ?: filesDir
                            outBase?.let { base ->
                                if (!base.exists()) base.mkdirs()
                                // Nettoyer d'anciens caches nommés from_saf* pour éviter de mélanger des fichiers
                                try {
                                    base.listFiles()?.filter { it.isDirectory && it.name.startsWith("from_saf") }?.forEach {
                                        try {
                                            it.deleteRecursively()
                                            Log.d("MainActivity", "Deleted old cache folder: ${it.absolutePath}")
                                        } catch (delEx: Exception) {
                                            Log.w("MainActivity", "Failed to delete old cache ${it.absolutePath}", delEx)
                                        }
                                    }
                                } catch (e: Exception) {
                                    Log.w("MainActivity", "Error during old cache cleanup", e)
                                }

                                // Créer un cache unique pour cette sélection pour éviter les collisions
                                val sub = File(base, "from_saf_${System.currentTimeMillis()}")
                                if (!sub.exists()) sub.mkdirs()
                                copiedCachePath = sub.absolutePath

                                fun copyDoc(doc: DocumentFile, dest: File) {
                                    if (doc.isDirectory) {
                                        val dirName = doc.name ?: "dir"
                                        val newDir = File(dest, dirName)
                                        if (!newDir.exists()) newDir.mkdirs()
                                        val children = doc.listFiles()
                                        for (c in children) {
                                            copyDoc(c, newDir)
                                        }
                                    } else if (doc.isFile) {
                                        val name = doc.name ?: "file"
                                        val outFile = File(dest, name)
                                        try {
                                            val `in`: InputStream? = contentResolver.openInputStream(doc.uri)
                                            if (`in` != null) {
                                                FileOutputStream(outFile).use { out ->
                                                    val buf = ByteArray(8192)
                                                    var len: Int
                                                    while (`in`.read(buf).also { len = it } > 0) {
                                                        out.write(buf, 0, len)
                                                    }
                                                    out.flush()
                                                }
                                                `in`.close()
                                                copiedFiles.add(outFile.absolutePath)
                                            }
                                        } catch (ex: IOException) {
                                            Log.w("MainActivity", "Failed to copy file ${doc.uri}", ex)
                                        }
                                    }
                                }

                                        if (tree != null && tree.exists()) {
                                            val children = tree.listFiles()
                                            for (c in children) {
                                                copyDoc(c, sub)
                                            }

                                            // Tentative: copier récursivement le dossier copié dans le cache
                                            // vers /storage/emulated/0/RetroArch/system en préservant la structure.
                                            try {
                                                val externalRetroRoot = File("/storage/emulated/0/RetroArch")
                                                val externalSystemDir = File(externalRetroRoot, "system")
                                                if (!externalSystemDir.exists()) externalSystemDir.mkdirs()

                                                fun copyDirRecursive(src: File, dest: File) {
                                                    if (src.isDirectory) {
                                                        if (!dest.exists()) dest.mkdirs()
                                                        val children = src.listFiles()
                                                        if (children != null) {
                                                            for (child in children) {
                                                                copyDirRecursive(child, File(dest, child.name))
                                                            }
                                                        }
                                                    } else {
                                                        try {
                                                            src.copyTo(dest, overwrite = true)
                                                            copiedToRetro = true
                                                        } catch (e: Exception) {
                                                            Log.w("MainActivity", "Failed to copy file ${src.absolutePath} to ${dest.absolutePath}", e)
                                                        }
                                                    }
                                                }

                                                // Copier le dossier 'sub' (cache from_saf) vers RetroArch/system
                                                copyDirRecursive(sub, externalSystemDir)
                                                if (copiedToRetro) {
                                                    retroarchPath = externalSystemDir.absolutePath
                                                }
                                            } catch (ex: Exception) {
                                                Log.w("MainActivity", "Failed to copy tree to RetroArch/system", ex)
                                            }
                                        }
                            }
                        } catch (ex: Exception) {
                            Log.w("MainActivity", "Error copying SAF tree to cache", ex)
                        }

                        // Build a structured response so Flutter puisse l'afficher directement
                        val response: MutableMap<String, Any> = mutableMapOf(
                            "uri" to uri.toString(),
                            "flags" to flags,
                            "takeFlags" to takeFlags,
                            "persisted" to persistedList
                        )
                        if (copiedCachePath != null) {
                            response["copiedCachePath"] = copiedCachePath
                            response["files"] = copiedFiles
                        }
                            if (copiedToRetro && retroarchPath != null) {
                                response["copiedToRetroArch"] = true
                                response["retroarchPath"] = retroarchPath!!
                            }

                        result?.success(response)
                    } catch (e: Exception) {
                        Log.e("MainActivity", "Error taking persistable permission", e)
                        result?.error("ERROR", e.message, null)
                    }
                } else {
                    result?.error("NO_URI", "No URI returned by picker", null)
                }
            } else {
                result?.error("CANCELLED", "User cancelled picker", null)
            }
        }
    }
}
