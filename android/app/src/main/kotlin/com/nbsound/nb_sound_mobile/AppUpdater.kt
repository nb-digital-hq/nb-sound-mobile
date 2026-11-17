package com.nbsound.nb_sound_mobile

import android.app.Activity
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.PackageInstaller
import android.net.Uri
import android.os.Build
import android.provider.Settings
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File

/**
 * Actualización de la app desde GitHub (canal `com.nbsound/updater`). La consulta
 * y la descarga del APK las hace Dart; aquí solo:
 *  - `info`: versión instalada y ABIs del dispositivo (para elegir el APK);
 *  - `canInstall` / `openInstallSettings`: permiso "instalar apps desconocidas";
 *  - `install`: instala el APK con [PackageInstaller]. Android exige que esté
 *    firmado con la misma llave que la app instalada, así que un APK ajeno nunca
 *    se instala encima;
 *  - `openUrl`: abre un enlace en el navegador.
 */
class AppUpdater(private val activity: Activity) : MethodChannel.MethodCallHandler {

    companion object {
        private const val ACTION = "com.nbsound.nb_sound_mobile.UPDATE_STATUS"
    }

    private var receiver: BroadcastReceiver? = null

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "info" -> {
                val pm = activity.packageManager
                val info = pm.getPackageInfo(activity.packageName, 0)
                result.success(
                    mapOf(
                        "version" to (info.versionName ?: ""),
                        "abis" to Build.SUPPORTED_ABIS.toList(),
                    )
                )
            }
            "canInstall" -> result.success(puedeInstalar())
            "openInstallSettings" -> {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    activity.startActivity(
                        Intent(
                            Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES,
                            Uri.parse("package:${activity.packageName}"),
                        )
                    )
                }
                result.success(null)
            }
            "openUrl" -> {
                val url = call.argument<String>("url")
                if (url != null && url.startsWith("https://")) {
                    activity.startActivity(
                        Intent(Intent.ACTION_VIEW, Uri.parse(url))
                            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    )
                }
                result.success(null)
            }
            "install" -> {
                val path = call.argument<String>("path")
                if (path == null || !File(path).isFile) {
                    result.error("no_file", "APK no encontrado", null)
                    return
                }
                try {
                    instalar(File(path))
                    result.success(true)
                } catch (e: Exception) {
                    result.error("install_error", e.message, null)
                }
            }
            else -> result.notImplemented()
        }
    }

    private fun puedeInstalar(): Boolean =
        Build.VERSION.SDK_INT < Build.VERSION_CODES.O ||
            activity.packageManager.canRequestPackageInstalls()

    private fun instalar(apk: File) {
        val installer = activity.packageManager.packageInstaller
        val params = PackageInstaller.SessionParams(
            PackageInstaller.SessionParams.MODE_FULL_INSTALL
        ).apply {
            setAppPackageName(activity.packageName)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                setRequireUserAction(PackageInstaller.SessionParams.USER_ACTION_NOT_REQUIRED)
            }
        }
        val id = installer.createSession(params)
        installer.openSession(id).use { session ->
            apk.inputStream().use { input ->
                session.openWrite("nb-sound.apk", 0, apk.length()).use { out ->
                    input.copyTo(out)
                    session.fsync(out)
                }
            }
            registrarReceptor()
            val intent = Intent(ACTION).setPackage(activity.packageName)
            val flags = PendingIntent.FLAG_UPDATE_CURRENT or
                (if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S)
                    PendingIntent.FLAG_MUTABLE else 0)
            val pi = PendingIntent.getBroadcast(activity, id, intent, flags)
            session.commit(pi.intentSender)
        }
    }

    /** Muestra la confirmación del sistema cuando Android la pide. */
    private fun registrarReceptor() {
        if (receiver != null) return
        val r = object : BroadcastReceiver() {
            override fun onReceive(context: Context, intent: Intent) {
                val status = intent.getIntExtra(PackageInstaller.EXTRA_STATUS, -999)
                if (status == PackageInstaller.STATUS_PENDING_USER_ACTION) {
                    @Suppress("DEPRECATION")
                    val confirm = if (Build.VERSION.SDK_INT >= 33)
                        intent.getParcelableExtra(Intent.EXTRA_INTENT, Intent::class.java)
                    else intent.getParcelableExtra<Intent>(Intent.EXTRA_INTENT)
                    confirm?.let {
                        it.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        activity.startActivity(it)
                    }
                }
            }
        }
        receiver = r
        val filter = IntentFilter(ACTION)
        if (Build.VERSION.SDK_INT >= 33) {
            activity.registerReceiver(r, filter, Context.RECEIVER_NOT_EXPORTED)
        } else {
            @Suppress("UnspecifiedRegisterReceiverFlag")
            activity.registerReceiver(r, filter)
        }
    }

    fun dispose() {
        receiver?.let { runCatching { activity.unregisterReceiver(it) } }
        receiver = null
    }
}
