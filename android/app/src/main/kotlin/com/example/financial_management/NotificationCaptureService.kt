package com.example.financial_management

import android.app.Notification
import android.content.Context
import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification
import org.json.JSONArray
import org.json.JSONObject
import java.io.File

/**
 * Captura notificações de apps de banco e grava cada uma como um arquivo JSON
 * na fila em disco. O Flutter drena essa fila quando volta ao primeiro plano.
 *
 * Este serviço deliberadamente NÃO interpreta nada: valor, estabelecimento e
 * tipo de transação são derivados no Dart, onde as regras podem mudar sem
 * recompilar o nativo. Aqui só há captura e filtro.
 *
 * O Android inicia e mantém este serviço enquanto a permissão de acesso a
 * notificações estiver concedida — inclusive com o app fechado e após reboot.
 * Por isso não existe engine Flutter em background: nada de Dart roda aqui.
 */
class NotificationCaptureService : NotificationListenerService() {

    override fun onNotificationPosted(sbn: StatusBarNotification) {
        val config = CaptureConfig(this)

        // Modo descoberta: registra apenas QUAIS apps notificam, nunca o
        // conteúdo. Serve para identificar o package do banco sem transformar
        // isto num log de tudo que chega no aparelho.
        if (config.discoveryMode) {
            config.recordSeenPackage(sbn.packageName)
        }

        if (!config.watchedPackages.contains(sbn.packageName)) return

        val extras = sbn.notification.extras
        val payload = JSONObject().apply {
            put("packageName", sbn.packageName)
            put("title", extras.getCharSequence(Notification.EXTRA_TITLE)?.toString() ?: "")
            put("text", extras.getCharSequence(Notification.EXTRA_TEXT)?.toString() ?: "")
            put("bigText", extras.getCharSequence(Notification.EXTRA_BIG_TEXT)?.toString() ?: "")
            put("subText", extras.getCharSequence(Notification.EXTRA_SUB_TEXT)?.toString() ?: "")
            put("postTime", sbn.postTime)
        }

        // Um arquivo por evento: o nativo só cria, o Dart só apaga. Nenhum dos
        // dois lados escreve no arquivo do outro, então não há corrida — o que
        // aconteceria com um único log em modo append.
        val name = "${sbn.postTime}_${sbn.key.hashCode().toUInt()}.json"
        runCatching { File(queueDir(this), name).writeText(payload.toString()) }
    }

    companion object {
        private const val QUEUE_DIR_NAME = "pending_notifications"

        /** Fonte única do caminho da fila — o Dart pergunta, não adivinha. */
        fun queueDir(context: Context): File =
            File(context.filesDir, QUEUE_DIR_NAME).apply { mkdirs() }
    }
}

/**
 * Configuração da captura, em um SharedPreferences próprio do lado nativo.
 *
 * Arquivo separado de propósito: o plugin shared_preferences do Flutter usa o
 * armazenamento padrão (com chaves prefixadas por "flutter."), e escrever no
 * mesmo lugar de dois processos reintroduziria o problema de cache que este
 * desenho existe para evitar.
 */
class CaptureConfig(context: Context) {
    private val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)

    var discoveryMode: Boolean
        get() = prefs.getBoolean(KEY_DISCOVERY, false)
        set(value) = prefs.edit().putBoolean(KEY_DISCOVERY, value).apply()

    var watchedPackages: Set<String>
        get() = prefs.getStringSet(KEY_WATCHED, DEFAULT_WATCHED) ?: DEFAULT_WATCHED
        set(value) = prefs.edit().putStringSet(KEY_WATCHED, value).apply()

    /** Packages vistos no modo descoberta, sem nenhum conteúdo de notificação. */
    val seenPackages: List<String>
        get() = runCatching {
            val raw = prefs.getString(KEY_SEEN, "[]") ?: "[]"
            val array = JSONArray(raw)
            List(array.length()) { array.getString(it) }
        }.getOrDefault(emptyList())

    fun recordSeenPackage(packageName: String) {
        val current = seenPackages
        if (current.contains(packageName)) return
        val updated = JSONArray().apply {
            current.forEach { put(it) }
            put(packageName)
        }
        prefs.edit().putString(KEY_SEEN, updated.toString()).apply()
    }

    fun clearSeenPackages() = prefs.edit().remove(KEY_SEEN).apply()

    companion object {
        private const val PREFS_NAME = "notification_capture_config"
        private const val KEY_DISCOVERY = "discovery_mode"
        private const val KEY_WATCHED = "watched_packages"
        private const val KEY_SEEN = "seen_packages"

        /**
         * Palpite inicial, não verdade: o package do Nubank precisa ser
         * confirmado pelo modo descoberta no aparelho antes de virar padrão.
         */
        private val DEFAULT_WATCHED = setOf("com.nu.production")
    }
}
