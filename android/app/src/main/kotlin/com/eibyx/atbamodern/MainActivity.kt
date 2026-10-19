package com.eibyx.atbamodern

import android.Manifest
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Context
import android.content.pm.PackageManager
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "atba.modern/notifications")
            .setMethodCallHandler { call, result ->
                if (call.method != "show") {
                    result.notImplemented()
                    return@setMethodCallHandler
                }
                if (Build.VERSION.SDK_INT >= 33 &&
                    checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED) {
                    result.success(false)
                    return@setMethodCallHandler
                }
                val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
                val channelId = "torbox-transfers"
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    manager.createNotificationChannel(NotificationChannel(channelId, "Eventos de TorBox", NotificationManager.IMPORTANCE_DEFAULT))
                }
                @Suppress("DEPRECATION")
                val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    Notification.Builder(this, channelId)
                } else {
                    Notification.Builder(this)
                }
                val notification = builder
                    .setSmallIcon(android.R.drawable.stat_sys_download_done)
                    .setContentTitle(call.argument<String>("title") ?: "ATBA Modern")
                    .setContentText(call.argument<String>("body") ?: "Estado actualizado")
                    .setVisibility(Notification.VISIBILITY_PRIVATE)
                    .setAutoCancel(true)
                    .build()
                manager.notify(call.argument<Int>("id") ?: 1, notification)
                result.success(true)
            }
    }
}
