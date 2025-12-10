package com.aimessoft.misuzumusic

import android.content.Intent
import android.net.Uri
import android.provider.OpenableColumns
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import com.ryanheise.audioservice.AudioServiceActivity
import java.io.File
import java.io.FileOutputStream

class MainActivity : AudioServiceActivity() {
  private val channelName = "com.aimessoft.misuzumusic/file_association"
  private var fileAssociationChannel: MethodChannel? = null
  private val pendingOpenFiles = mutableListOf<String>()
  private var dartReadyForFiles = false

  override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
    super.configureFlutterEngine(flutterEngine)
    fileAssociationChannel =
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
    fileAssociationChannel?.setMethodCallHandler { call, result ->
      if (call.method == "collectPendingFiles") {
        dartReadyForFiles = true
        result.success(ArrayList(pendingOpenFiles))
        pendingOpenFiles.clear()
      } else {
        result.notImplemented()
      }
    }
    handleIntent(intent)
  }

  override fun onNewIntent(intent: Intent) {
    super.onNewIntent(intent)
    setIntent(intent)
    handleIntent(intent)
  }

  private fun handleIntent(intent: Intent?) {
    if (intent == null) return
    val action = intent.action ?: return
    if (action != Intent.ACTION_VIEW && action != Intent.ACTION_SEND && action != Intent.ACTION_SEND_MULTIPLE) {
      return
    }

    val uris = mutableListOf<Uri>()
    intent.data?.let { uris.add(it) }
    intent.clipData?.let { clip ->
      for (i in 0 until clip.itemCount) {
        clip.getItemAt(i)?.uri?.let { uris.add(it) }
      }
    }

    val resolved = uris.mapNotNull { resolveUriToPath(it) }
    if (resolved.isEmpty()) return

    if (dartReadyForFiles && fileAssociationChannel != null) {
      fileAssociationChannel?.invokeMethod("openFiles", resolved)
    } else {
      pendingOpenFiles.addAll(resolved)
    }
  }

  private fun resolveUriToPath(uri: Uri): String? {
    return when (uri.scheme) {
      "file" -> uri.path
      "content" -> copyContentUriToCache(uri)
      else -> null
    }
  }

  private fun copyContentUriToCache(uri: Uri): String? {
    return try {
      val resolver = applicationContext.contentResolver
      val mime = resolver.getType(uri) ?: ""
      val name = resolver.query(uri, null, null, null, null)?.use { cursor ->
        val nameIndex = cursor.getColumnIndex(OpenableColumns.DISPLAY_NAME)
        if (nameIndex != -1 && cursor.moveToFirst()) {
          cursor.getString(nameIndex)
        } else null
      }

      val extension = when {
        name?.contains(".") == true -> name.substringAfterLast('.', "")
        mime.contains("audio/") -> mime.substringAfter("audio/", "")
        else -> ""
      }
      val safeExt = if (extension.isNotEmpty()) ".$extension" else ""
      val targetFile =
          File(applicationContext.cacheDir, "opened-${System.currentTimeMillis()}$safeExt")

      resolver.openInputStream(uri)?.use { input ->
        FileOutputStream(targetFile).use { output ->
          input.copyTo(output)
        }
      } ?: return null

      targetFile.absolutePath
    } catch (_: Exception) {
      null
    }
  }
}
