package com.soleux.sdm

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import android.net.ConnectivityManager
import android.net.wifi.WifiManager
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.net.Inet4Address

class MainActivity : FlutterActivity() {
    private var multicastLock: WifiManager.MulticastLock? = null
    private var nearbyWifiPermissionContinuation: MethodChannel.Result? = null

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
                    else -> result.notImplemented()
                }
            } catch (e: Exception) {
                result.error("WIFI_LOCK", e.message, null)
            }
        }
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
        if (requestCode == REQUEST_NEARBY_WIFI) {
            val granted = grantResults.isNotEmpty() &&
                grantResults[0] == PackageManager.PERMISSION_GRANTED
            nearbyWifiPermissionContinuation?.success(granted)
            nearbyWifiPermissionContinuation = null
        }
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
    }
}