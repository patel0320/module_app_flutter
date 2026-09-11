package com.soleux.sdm

import android.Manifest
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.ConnectivityManager
import android.net.Uri
import android.net.wifi.WifiManager
import android.os.Build
import android.os.PowerManager
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.net.Inet4Address

class MainActivity : FlutterActivity() {
    private var multicastLock: WifiManager.MulticastLock? = null
    private var nearbyWifiPermissionContinuation: MethodChannel.Result? = null
    private var localNetworkPermissionContinuation: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "soleux.device_manager/wifi_lock"
        ).setMethodCallHandler { call, result ->
            try {
                when (call.method) {
                    "acquire" -> {
                        acquireMulticastLock()
                        result.success(true)
                    }
                    "release" -> {
                        releaseMulticastLock()
                        result.success(true)
                    }
                    "ipv4LinkInfo" -> {
                        result.success(activeIpv4LinkInfo())
                    }
                    "requestNearbyWifiPermission" -> {
                        requestNearbyWifiPermission(result)
                    }
                    "requestLocalNetworkPermission" -> {
                        requestLocalNetworkPermission(result)
                    }
                    else -> result.notImplemented()
                }
            } catch (e: Exception) {
                result.error("WIFI_LOCK", e.message, null)
            }
        }
        registerKeepAliveChannel(flutterEngine)
    }

    // Android foreground service that keeps the Dart-side persistent module
    // sockets + UDP heartbeat alive while the app is backgrounded. The channel
    // is registered on the main activity (main isolate) only: the background
    // worker isolate is headless and never needs to touch the service.
    private fun registerKeepAliveChannel(flutterEngine: FlutterEngine) {
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "soleux.device_manager/keep_alive"
        ).setMethodCallHandler { call, result ->
            try {
                when (call.method) {
                    "start" -> {
                        startKeepAliveService(
                            call.argument("moduleCount") ?: 0,
                            call.argument("title"),
                            call.argument("text"),
                        )
                        result.success(true)
                    }
                    "stop" -> {
                        stopKeepAliveService()
                        result.success(true)
                    }
                    "isRunning" -> {
                        result.success(ModuleKeepAliveService.isRunning(this))
                    }
                    "isIgnoringBatteryOptimizations" -> {
                        result.success(isIgnoringBatteryOptimizations())
                    }
                    "requestIgnoreBatteryOptimizations" -> {
                        requestIgnoreBatteryOptimizations()
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            } catch (e: Exception) {
                result.error("KEEP_ALIVE", e.message, null)
            }
        }
    }

    // Starts (or updates) the persistent keep-alive foreground service. The
    // app is in the foreground when the user launches it, so this is an
    // allowed foreground service start on every supported Android version.
    private fun startKeepAliveService(moduleCount: Int, title: String?, text: String?) {
        val intent = Intent(this, ModuleKeepAliveService::class.java).apply {
            action = ModuleKeepAliveService.ACTION_START
            putExtra(ModuleKeepAliveService.EXTRA_MODULE_COUNT, moduleCount)
            putExtra(ModuleKeepAliveService.EXTRA_TITLE, title)
            putExtra(ModuleKeepAliveService.EXTRA_TEXT, text)
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            startForegroundService(intent)
        } else {
            startService(intent)
        }
    }

    private fun stopKeepAliveService() {
        val intent = Intent(this, ModuleKeepAliveService::class.java).apply {
            action = ModuleKeepAliveService.ACTION_STOP
        }
        startService(intent)
    }

    // Whether the app is already exempt from battery optimization (Doze /
    // App Standby), used by the opt-in flow in Settings.
    private fun isIgnoringBatteryOptimizations(): Boolean {
        val power =
            applicationContext.getSystemService(Context.POWER_SERVICE) as PowerManager
        return power.isIgnoringBatteryOptimizations(applicationContext.packageName)
    }

    // Opens the system dialog asking the user to exempt the app from battery
    // optimizations. Opt-in only - never called automatically; the caller must
    // be a visible activity (this MethodChannel lives on the Activity).
    private fun requestIgnoreBatteryOptimizations() {
        val intent = Intent(
            Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS,
            Uri.parse("package:$packageName")
        )
        startActivity(intent)
    }

    // WiFi NICs drop broadcast/multicast frames unless the app holds a
    // WifiManager.MulticastLock; without it UDP device discovery silently
    // fails on Android phones. Requires CHANGE_WIFI_MULTICAST_STATE.
    private fun acquireMulticastLock() {
        val lock = multicastLock
        if (lock != null && lock.isHeld) return
        val wifi =
            applicationContext.getSystemService(Context.WIFI_SERVICE) as WifiManager
        val newLock = wifi.createMulticastLock("soleux-device-manager-discovery")
        newLock.setReferenceCounted(true)
        newLock.acquire()
        multicastLock = newLock
    }

    private fun releaseMulticastLock() {
        val lock = multicastLock
        if (lock != null && lock.isHeld) {
            lock.release()
        }
    }

    // Android 13+ makes NEARBY_WIFI_DEVICES a runtime permission; from Android
    // 14 (targetSdk 34+) WifiManager.createMulticastLock throws a
    // SecurityException without it, which silently kills UDP discovery.
    private fun requestNearbyWifiPermission(result: MethodChannel.Result) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) {
            result.success(true)
            return
        }
        if (checkSelfPermission(Manifest.permission.NEARBY_WIFI_DEVICES) ==
            PackageManager.PERMISSION_GRANTED
        ) {
            result.success(true)
            return
        }
        val previous = nearbyWifiPermissionContinuation
        if (previous != null) {
            // A request is already in flight; resolve the older one as denied.
            previous.success(false)
        }
        nearbyWifiPermissionContinuation = result
        requestPermissions(
            arrayOf(Manifest.permission.NEARBY_WIFI_DEVICES),
            REQUEST_NEARBY_WIFI
        )
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<String>,
        grantResults: IntArray
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        val granted = grantResults.isNotEmpty() &&
            grantResults[0] == PackageManager.PERMISSION_GRANTED
        when (requestCode) {
            REQUEST_NEARBY_WIFI -> {
                nearbyWifiPermissionContinuation?.success(granted)
                nearbyWifiPermissionContinuation = null
            }
            REQUEST_LOCAL_NETWORK -> {
                localNetworkPermissionContinuation?.success(granted)
                localNetworkPermissionContinuation = null
            }
        }
    }

    // Android 16 (API 36, targetSdk 36) gates every packet to the local LAN
    // (UDP discovery, TCP command/status, local MQTT) behind a runtime
    // permission; without the grant the discovery broadcast never egresses.
    private fun requestLocalNetworkPermission(result: MethodChannel.Result) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.BAKLAVA) {
            result.success(true)
            return
        }
        if (checkSelfPermission("android.permission.ACCESS_LOCAL_NETWORK") ==
            PackageManager.PERMISSION_GRANTED
        ) {
            result.success(true)
            return
        }
        val previous = localNetworkPermissionContinuation
        if (previous != null) {
            // A request is already in flight; resolve the older one as denied.
            previous.success(false)
        }
        localNetworkPermissionContinuation = result
        requestPermissions(
            arrayOf("android.permission.ACCESS_LOCAL_NETWORK"),
            REQUEST_LOCAL_NETWORK
        )
    }

    // Returns the active network's IPv4 link address (interface name, address,
    // and CIDR prefix length) for the Dart-side directed-broadcast math.
    // Reading /proc/net/route is blocked by SELinux for untrusted_app, so the
    // prefix is sourced from ConnectivityManager.LinkProperties instead.
    // Requires API 23+; returns null (Dart falls back to /24 + global
    // broadcast) on older releases. Needs ACCESS_NETWORK_STATE.
    private fun activeIpv4LinkInfo(): Map<String, Any>? {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) {
            return null
        }
        val cm =
            applicationContext.getSystemService(Context.CONNECTIVITY_SERVICE)
                as ConnectivityManager
        val network = cm.activeNetwork ?: return null
        val lp = cm.getLinkProperties(network) ?: return null
        for (link in lp.linkAddresses) {
            val address = link.address ?: continue
            if (address is Inet4Address) {
                return mapOf(
                    "interface" to (lp.interfaceName ?: ""),
                    "ip" to address.hostAddress,
                    "prefix" to link.prefixLength
                )
            }
        }
        return null
    }

    companion object {
        private const val REQUEST_NEARBY_WIFI = 0x1001
        private const val REQUEST_LOCAL_NETWORK = 0x1002
    }
}