package com.example.financial_management

import android.content.Intent
import android.provider.Settings
import androidx.core.app.NotificationManagerCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                val config = CaptureConfig(this)
                when (call.method) {
                    "isPermissionGranted" -> result.success(isNotificationAccessGranted())

                    "openSettings" -> {
                        startActivity(Intent(Settings.ACTION_NOTIFICATION_LISTENER_SETTINGS))
                        result.success(null)
                    }

                    // O nativo é dono do caminho da fila. Devolver daqui evita
                    // que o Dart assuma um mapeamento de diretório do
                    // path_provider que pode não ser o mesmo.
                    "getQueueDir" -> result.success(
                        NotificationCaptureService.queueDir(this).absolutePath
                    )

                    "getConfig" -> result.success(
                        mapOf(
                            "discoveryMode" to config.discoveryMode,
                            "watchedPackages" to config.watchedPackages.toList(),
                            "seenPackages" to config.seenPackages,
                        )
                    )

                    "setConfig" -> {
                        call.argument<Boolean>("discoveryMode")?.let {
                            config.discoveryMode = it
                        }
                        call.argument<List<String>>("watchedPackages")?.let {
                            config.watchedPackages = it.toSet()
                        }
                        result.success(null)
                    }

                    "clearSeenPackages" -> {
                        config.clearSeenPackages()
                        result.success(null)
                    }

                    else -> result.notImplemented()
                }
            }
    }

    private fun isNotificationAccessGranted(): Boolean =
        NotificationManagerCompat.getEnabledListenerPackages(this).contains(packageName)

    companion object {
        private const val CHANNEL = "financial_management/notification_capture"
    }
}
