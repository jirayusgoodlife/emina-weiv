package com.animeview.anime_view

import android.content.Context
import android.net.nsd.NsdManager
import android.net.nsd.NsdServiceInfo
import android.net.wifi.WifiManager
import android.os.Handler
import android.os.Looper
import android.util.Log
import io.flutter.plugin.common.MethodChannel
import java.io.IOException
import java.io.OutputStream
import java.net.DatagramPacket
import java.net.DatagramSocket
import java.net.HttpURLConnection
import java.net.InetAddress
import java.net.InetSocketAddress
import java.net.SocketTimeoutException
import java.net.URI
import java.net.URL
import java.nio.ByteBuffer
import java.nio.ByteOrder
import java.util.concurrent.ConcurrentHashMap
import java.util.concurrent.ConcurrentLinkedQueue
import java.util.concurrent.CopyOnWriteArrayList
import java.util.concurrent.CountDownLatch
import java.util.concurrent.Executors
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicBoolean
import javax.net.ssl.SSLContext
import javax.net.ssl.SSLSocket
import javax.net.ssl.TrustManager
import javax.net.ssl.X509TrustManager
import org.json.JSONArray
import org.json.JSONObject

/**
 * CastService — Dual-protocol casting service supporting:
 * 1. Google Cast (Chromecast / Google TV / Android TV) via mDNS + Cast V2 TLS protocol
 * 2. DLNA / UPnP MediaRenderer (Samsung Smart TV, LG webOS TV, Sony, etc.) via SSDP + SOAP
 *
 * Automatically discovers TVs with human-readable names and handles playback controls.
 */
class CastService(private val context: Context) {

    companion object {
        private const val TAG = "CastService"
        private const val CAST_SERVICE_TYPE = "_googlecast._tcp."
        private const val CAST_SERVICE_TYPE_NO_DOT = "_googlecast._tcp"
        private const val DEFAULT_MEDIA_RECEIVER_APP_ID = "CC1AD845"
        private const val CAST_PORT = 8009
    }

    data class CastDevice(
        val id: String,
        val name: String,
        val host: InetAddress?,
        val hostAddress: String,
        val port: Int,
        val model: String = "",
        val type: String = "chromecast", // "chromecast" or "dlna"
        val avTransportControlUrl: String? = null,
        val renderingControlUrl: String? = null
    )

    private val mainHandler = Handler(Looper.getMainLooper())
    private val executor = Executors.newCachedThreadPool()

    // Discovery state
    private var nsdManager: NsdManager? = null
    private var discoveryListener: NsdManager.DiscoveryListener? = null
    private val discoveredDevices = CopyOnWriteArrayList<CastDevice>()
    private var isDiscovering = false
    private var multicastLock: WifiManager.MulticastLock? = null

    // Sequential resolve queue to prevent NsdManager errorCode 3 (FAILURE_ALREADY_ACTIVE)
    private val resolveQueue = ConcurrentLinkedQueue<NsdServiceInfo>()
    private val isResolving = AtomicBoolean(false)

    // SSDP / DLNA state
    private var ssdpThread: Thread? = null
    private var ssdpSocket: DatagramSocket? = null
    private val processedLocations = ConcurrentHashMap.newKeySet<String>()
    private var dlnaPollThread: Thread? = null

    // Cast V2 connection state
    private var castSocket: SSLSocket? = null
    private var outputStream: OutputStream? = null
    private var connectedDevice: CastDevice? = null
    private var transportId: String? = null
    private var mediaSessionId: Int = 0
    private var requestId: Int = 1
    private var receiverThread: Thread? = null
    private var isConnected = false
    private var pendingLaunchLatch: CountDownLatch? = null

    var methodChannel: MethodChannel? = null

    // =================== UNIFIED DISCOVERY ===================

    fun startDiscovery() {
        stopDiscovery()
        discoveredDevices.clear()
        processedLocations.clear()
        resolveQueue.clear()
        isResolving.set(false)
        isDiscovering = true

        try {
            val wifiManager = context.applicationContext.getSystemService(Context.WIFI_SERVICE) as? WifiManager
            multicastLock = wifiManager?.createMulticastLock("CastMulticastLock")?.apply {
                setReferenceCounted(false)
                acquire()
            }
        } catch (e: Exception) {
            Log.w(TAG, "Could not acquire multicast lock: ${e.message}")
        }

        startChromecastDiscovery()
        startSsdpDiscovery()
    }

    fun stopDiscovery() {
        isDiscovering = false

        stopChromecastDiscovery()
        stopSsdpDiscovery()

        try {
            if (multicastLock?.isHeld == true) {
                multicastLock?.release()
            }
        } catch (_: Exception) {}
        multicastLock = null
    }

    fun getDiscoveredDevices(): List<Map<String, Any>> {
        return discoveredDevices.map { device ->
            mapOf(
                "id" to device.id,
                "name" to device.name,
                "host" to device.hostAddress,
                "port" to device.port,
                "model" to device.model,
                "type" to device.type
            )
        }
    }

    // =================== CHROMECAST DISCOVERY ===================

    private fun startChromecastDiscovery() {
        nsdManager = context.getSystemService(Context.NSD_SERVICE) as? NsdManager
        if (nsdManager == null) return

        discoveryListener = object : NsdManager.DiscoveryListener {
            override fun onDiscoveryStarted(serviceType: String) {
                Log.d(TAG, "Chromecast discovery started: $serviceType")
            }

            override fun onServiceFound(serviceInfo: NsdServiceInfo) {
                Log.d(TAG, "Found mDNS service: ${serviceInfo.serviceName}")
                enqueueResolve(serviceInfo)
            }

            override fun onServiceLost(serviceInfo: NsdServiceInfo) {
                discoveredDevices.removeAll { it.id == serviceInfo.serviceName && it.type == "chromecast" }
                notifyDevicesUpdated()
            }

            override fun onDiscoveryStopped(serviceType: String) {
                Log.d(TAG, "Chromecast discovery stopped")
            }

            override fun onStartDiscoveryFailed(serviceType: String, errorCode: Int) {
                Log.e(TAG, "Chromecast discovery start failed for $serviceType: $errorCode")
                if (serviceType.endsWith(".")) {
                    try {
                        nsdManager?.discoverServices(CAST_SERVICE_TYPE_NO_DOT, NsdManager.PROTOCOL_DNS_SD, discoveryListener)
                    } catch (_: Exception) {}
                }
            }

            override fun onStopDiscoveryFailed(serviceType: String, errorCode: Int) {
                Log.e(TAG, "Chromecast discovery stop failed: $errorCode")
            }
        }

        try {
            nsdManager?.discoverServices(CAST_SERVICE_TYPE, NsdManager.PROTOCOL_DNS_SD, discoveryListener)
        } catch (e: Exception) {
            Log.e(TAG, "Failed to start Chromecast discovery with dot: ${e.message}")
            try {
                nsdManager?.discoverServices(CAST_SERVICE_TYPE_NO_DOT, NsdManager.PROTOCOL_DNS_SD, discoveryListener)
            } catch (e2: Exception) {
                Log.e(TAG, "Failed to start Chromecast discovery without dot: ${e2.message}")
            }
        }
    }

    private fun stopChromecastDiscovery() {
        try {
            discoveryListener?.let { nsdManager?.stopServiceDiscovery(it) }
        } catch (e: Exception) {
            Log.w(TAG, "Error stopping Chromecast discovery: ${e.message}")
        }
        discoveryListener = null
        resolveQueue.clear()
        isResolving.set(false)
    }

    private fun enqueueResolve(serviceInfo: NsdServiceInfo) {
        resolveQueue.add(serviceInfo)
        processNextResolve()
    }

    private fun processNextResolve() {
        if (!isDiscovering) return
        if (!isResolving.compareAndSet(false, true)) return

        val next = resolveQueue.poll()
        if (next == null) {
            isResolving.set(false)
            return
        }

        val timeoutRunnable = Runnable {
            if (isResolving.compareAndSet(true, false)) {
                Log.w(TAG, "Resolve timed out for ${next.serviceName}")
                processNextResolve()
            }
        }
        mainHandler.postDelayed(timeoutRunnable, 3000)

        try {
            nsdManager?.resolveService(next, object : NsdManager.ResolveListener {
                override fun onResolveFailed(serviceInfo: NsdServiceInfo, errorCode: Int) {
                    mainHandler.removeCallbacks(timeoutRunnable)
                    Log.w(TAG, "Resolve failed for ${serviceInfo.serviceName}: $errorCode")
                    isResolving.set(false)
                    mainHandler.postDelayed({ processNextResolve() }, 100)
                }

                override fun onServiceResolved(serviceInfo: NsdServiceInfo) {
                    mainHandler.removeCallbacks(timeoutRunnable)
                    handleResolvedChromecast(serviceInfo)
                    isResolving.set(false)
                    mainHandler.postDelayed({ processNextResolve() }, 100)
                }
            })
        } catch (e: Exception) {
            mainHandler.removeCallbacks(timeoutRunnable)
            Log.w(TAG, "Error in resolveService: ${e.message}")
            isResolving.set(false)
            mainHandler.postDelayed({ processNextResolve() }, 100)
        }
    }

    private fun handleResolvedChromecast(serviceInfo: NsdServiceInfo) {
        val host = serviceInfo.host ?: return
        val port = if (serviceInfo.port > 0) serviceInfo.port else CAST_PORT

        // TXT records extraction:
        // 'fn' is the TV Friendly Name set by user (e.g., "Living Room TV", "ทีวีห้องนอน")
        // 'md' is the Model Name (e.g., "Chromecast", "Chromecast with Google TV", "Mi TV")
        // 'id' is the unique device identifier
        val fn = serviceInfo.attributes["fn"]?.let { bytes ->
            try { String(bytes, Charsets.UTF_8).trim() } catch (_: Exception) { null }
        }
        val md = serviceInfo.attributes["md"]?.let { bytes ->
            try { String(bytes, Charsets.UTF_8).trim() } catch (_: Exception) { null }
        }
        val rawId = serviceInfo.attributes["id"]?.let { bytes ->
            try { String(bytes, Charsets.UTF_8).trim() } catch (_: Exception) { null }
        }

        val name = if (!fn.isNullOrBlank()) fn else (if (!md.isNullOrBlank()) md else serviceInfo.serviceName)
        val model = md ?: "Google Cast"
        val id = if (!rawId.isNullOrBlank()) rawId else serviceInfo.serviceName

        val device = CastDevice(
            id = id,
            name = name,
            host = host,
            hostAddress = host.hostAddress.orEmpty(),
            port = port,
            model = model,
            type = "chromecast"
        )

        // Deduplicate
        val existingIndex = discoveredDevices.indexOfFirst { it.id == device.id || it.hostAddress == device.hostAddress }
        if (existingIndex == -1) {
            discoveredDevices.add(device)
            notifyDeviceFound(device)
        } else {
            // Prefer friendly name if updated
            discoveredDevices[existingIndex] = device
            notifyDevicesUpdated()
        }
    }

    // =================== DLNA / SSDP DISCOVERY ===================

    private fun startSsdpDiscovery() {
        stopSsdpDiscovery()
        ssdpThread = Thread {
            try {
                val socket = DatagramSocket()
                socket.soTimeout = 2500
                ssdpSocket = socket

                val group = InetAddress.getByName("239.255.255.250")
                val searchTargets = listOf(
                    "urn:schemas-upnp-org:device:MediaRenderer:1",
                    "urn:schemas-upnp-org:service:AVTransport:1",
                    "urn:dial-multiscreen-org:service:dial:1",
                    "ssdp:all"
                )

                for (repeat in 0..1) {
                    for (st in searchTargets) {
                        val msg = "M-SEARCH * HTTP/1.1\r\n" +
                                "HOST: 239.255.255.250:1900\r\n" +
                                "MAN: \"ssdp:discover\"\r\n" +
                                "MX: 3\r\n" +
                                "ST: $st\r\n\r\n"
                        val bytes = msg.toByteArray(Charsets.UTF_8)
                        val packet = DatagramPacket(bytes, bytes.size, group, 1900)
                        try {
                            socket.send(packet)
                        } catch (e: Exception) {
                            Log.w(TAG, "Error sending SSDP M-SEARCH: ${e.message}")
                        }
                    }
                    if (repeat == 0) Thread.sleep(100)
                }

                val buf = ByteArray(8192)
                val startTime = System.currentTimeMillis()

                while (isDiscovering && !Thread.currentThread().isInterrupted && (System.currentTimeMillis() - startTime < 12000)) {
                    try {
                        val packet = DatagramPacket(buf, buf.size)
                        socket.receive(packet)
                        val response = String(packet.data, 0, packet.length, Charsets.UTF_8)
                        handleSsdpResponse(response)
                    } catch (_: SocketTimeoutException) {
                        // Expected periodic timeout
                    } catch (e: Exception) {
                        if (isDiscovering) Log.d(TAG, "SSDP receive error: ${e.message}")
                        break
                    }
                }
            } catch (e: Exception) {
                Log.w(TAG, "SSDP loop exception: ${e.message}")
            } finally {
                try { ssdpSocket?.close() } catch (_: Exception) {}
                ssdpSocket = null
            }
        }
        ssdpThread?.isDaemon = true
        ssdpThread?.start()
    }

    private fun stopSsdpDiscovery() {
        try { ssdpSocket?.close() } catch (_: Exception) {}
        ssdpSocket = null
        ssdpThread?.interrupt()
        ssdpThread = null
    }

    private fun handleSsdpResponse(response: String) {
        val lines = response.split("\r\n", "\n")
        var location: String? = null

        for (line in lines) {
            val colon = line.indexOf(':')
            if (colon > 0) {
                val key = line.substring(0, colon).trim().uppercase()
                val value = line.substring(colon + 1).trim()
                if (key == "LOCATION") {
                    location = value
                    break
                }
            }
        }

        if (location.isNullOrBlank()) return
        if (!processedLocations.add(location)) return // already processed

        executor.execute {
            try {
                val url = URL(location)
                val conn = url.openConnection() as HttpURLConnection
                conn.connectTimeout = 3000
                conn.readTimeout = 3000
                val xml = conn.inputStream.bufferedReader(Charsets.UTF_8).use { it.readText() }
                conn.disconnect()

                parseDlnaDeviceXml(xml, location)
            } catch (e: Exception) {
                Log.d(TAG, "Failed to load DLNA device XML ($location): ${e.message}")
            }
        }
    }

    private fun parseDlnaDeviceXml(xml: String, locationUrl: String) {
        try {
            val friendlyName = extractXmlTag(xml, "friendlyName")
            if (friendlyName.isNullOrBlank()) return

            val avTransportControl = extractControlUrl(xml, "AVTransport", locationUrl)
            if (avTransportControl == null) {
                // Check if this is a Google Cast / DIAL device responding to SSDP
                val deviceType = extractXmlTag(xml, "deviceType") ?: ""
                val manufacturer = extractXmlTag(xml, "manufacturer") ?: ""
                val modelName = extractXmlTag(xml, "modelName") ?: ""
                val isGoogleCast = deviceType.contains("dial", ignoreCase = true) ||
                        manufacturer.contains("Google", ignoreCase = true) ||
                        modelName.contains("Eureka", ignoreCase = true) ||
                        modelName.contains("Chromecast", ignoreCase = true)

                if (isGoogleCast) {
                    val uri = URI(locationUrl)
                    val host = uri.host ?: ""
                    val udn = extractXmlTag(xml, "UDN") ?: locationUrl

                    val castDevice = CastDevice(
                        id = udn,
                        name = friendlyName,
                        host = try { InetAddress.getByName(host) } catch (_: Exception) { null },
                        hostAddress = host,
                        port = CAST_PORT,
                        model = if (modelName == "Eureka Dongle") "Chromecast" else (if (modelName.isNotEmpty()) modelName else "Google Cast"),
                        type = "chromecast"
                    )

                    val existingIndex = discoveredDevices.indexOfFirst {
                        it.id == castDevice.id || it.hostAddress == castDevice.hostAddress
                    }
                    if (existingIndex == -1) {
                        discoveredDevices.add(castDevice)
                        notifyDeviceFound(castDevice)
                    } else {
                        discoveredDevices[existingIndex] = castDevice
                        notifyDevicesUpdated()
                    }
                }
                return
            }

            val renderingControl = extractControlUrl(xml, "RenderingControl", locationUrl)
            val modelName = extractXmlTag(xml, "modelName") ?: "Smart TV"
            val udn = extractXmlTag(xml, "UDN") ?: locationUrl

            val uri = URI(locationUrl)
            val host = uri.host ?: ""
            val port = if (uri.port > 0) uri.port else 80

            val device = CastDevice(
                id = udn,
                name = friendlyName,
                host = try { InetAddress.getByName(host) } catch (_: Exception) { null },
                hostAddress = host,
                port = port,
                model = modelName,
                type = "dlna",
                avTransportControlUrl = avTransportControl,
                renderingControlUrl = renderingControl
            )

            // Deduplicate
            val existingIndex = discoveredDevices.indexOfFirst {
                it.id == device.id || (it.hostAddress == device.hostAddress && it.name == device.name)
            }

            if (existingIndex == -1) {
                discoveredDevices.add(device)
                notifyDeviceFound(device)
            } else {
                // Keep Chromecast entry if already exists, else update
                if (discoveredDevices[existingIndex].type != "chromecast") {
                    discoveredDevices[existingIndex] = device
                    notifyDevicesUpdated()
                }
            }
        } catch (e: Exception) {
            Log.w(TAG, "Error parsing DLNA XML: ${e.message}")
        }
    }

    // =================== CONNECTION MANAGEMENT ===================

    fun connectToDevice(deviceId: String, callback: (Boolean, String?) -> Unit) {
        val device = discoveredDevices.find { it.id == deviceId }
        if (device == null) {
            callback(false, "Device not found")
            return
        }

        if (device.type == "dlna") {
            connectDlna(device, callback)
        } else {
            connectChromecast(device, callback)
        }
    }

    private fun connectDlna(device: CastDevice, callback: (Boolean, String?) -> Unit) {
        executor.execute {
            try {
                disconnect()
                connectedDevice = device
                isConnected = true
                mainHandler.post { callback(true, null) }
                notifyConnectionChanged(true, device)
            } catch (e: Exception) {
                isConnected = false
                mainHandler.post { callback(false, e.message) }
            }
        }
    }

    private fun connectChromecast(device: CastDevice, callback: (Boolean, String?) -> Unit) {
        executor.execute {
            try {
                disconnect()

                // Create TLS socket (trust all certs for Cast protocol)
                val sslContext = SSLContext.getInstance("TLS")
                sslContext.init(null, arrayOf<TrustManager>(object : X509TrustManager {
                    override fun checkClientTrusted(chain: Array<java.security.cert.X509Certificate>?, authType: String?) {}
                    override fun checkServerTrusted(chain: Array<java.security.cert.X509Certificate>?, authType: String?) {}
                    override fun getAcceptedIssuers(): Array<java.security.cert.X509Certificate> = arrayOf()
                }), null)

                val port = if (device.port > 0) device.port else CAST_PORT
                val targetHost = device.host ?: InetAddress.getByName(device.hostAddress)

                val socket = sslContext.socketFactory.createSocket() as SSLSocket
                socket.tcpNoDelay = true
                socket.keepAlive = true
                socket.connect(InetSocketAddress(targetHost, port), 10000)
                socket.soTimeout = 0
                socket.startHandshake()

                castSocket = socket
                outputStream = socket.outputStream
                connectedDevice = device
                isConnected = true

                // Start receiving Cast V2 messages
                startReceiver(socket)

                // 1. Virtual connection to device receiver
                sendCastMessage(
                    sourceId = "sender-0",
                    destinationId = "receiver-0",
                    namespace = "urn:x-cast:com.google.cast.tp.connection",
                    payload = """{"type":"CONNECT"}"""
                )

                // 2. Query status
                sendCastMessage(
                    sourceId = "sender-0",
                    destinationId = "receiver-0",
                    namespace = "urn:x-cast:com.google.cast.receiver",
                    payload = """{"type":"GET_STATUS","requestId":${requestId++}}"""
                )

                // 3. Launch Default Media Receiver app
                val latch = CountDownLatch(1)
                pendingLaunchLatch = latch

                sendCastMessage(
                    sourceId = "sender-0",
                    destinationId = "receiver-0",
                    namespace = "urn:x-cast:com.google.cast.receiver",
                    payload = """{"type":"LAUNCH","appId":"$DEFAULT_MEDIA_RECEIVER_APP_ID","requestId":${requestId++}}"""
                )

                // Wait up to 12 seconds for the Media Receiver to launch and return transportId
                val launched = latch.await(12, TimeUnit.SECONDS)
                pendingLaunchLatch = null

                if (!launched || transportId.isNullOrEmpty()) {
                    throw IOException("Timeout waiting for TV to launch media receiver")
                }

                mainHandler.post { callback(true, null) }
                notifyConnectionChanged(true, device)

            } catch (e: Exception) {
                Log.e(TAG, "Chromecast connection failed: ${e.message}")
                handleDisconnect()
                mainHandler.post { callback(false, e.message) }
            }
        }
    }

    fun disconnect() {
        stopDlnaPolling()

        try {
            if (isConnected && castSocket != null) {
                sendCastMessage(
                    sourceId = "sender-0",
                    destinationId = "receiver-0",
                    namespace = "urn:x-cast:com.google.cast.tp.connection",
                    payload = """{"type":"CLOSE"}"""
                )
            }
        } catch (_: Exception) {}

        isConnected = false
        transportId = null
        mediaSessionId = 0
        receiverThread?.interrupt()
        receiverThread = null
        pendingLaunchLatch?.countDown()
        pendingLaunchLatch = null

        try { castSocket?.close() } catch (_: Exception) {}
        castSocket = null
        outputStream = null

        val wasConnected = connectedDevice != null
        connectedDevice = null
        if (wasConnected) {
            notifyConnectionChanged(false, null)
        }
    }

    // =================== MEDIA CONTROL ===================

    fun loadMedia(
        url: String,
        title: String,
        subtitle: String = "",
        thumbnailUrl: String = "",
        contentType: String = "video/mp4",
        startPosition: Double = 0.0,
        callback: (Boolean, String?) -> Unit
    ) {
        val currentDevice = connectedDevice
        if (!isConnected || currentDevice == null) {
            callback(false, "Not connected to a TV")
            return
        }

        if (currentDevice.type == "dlna") {
            loadMediaDlna(currentDevice, url, title, subtitle, thumbnailUrl, contentType, startPosition, callback)
        } else {
            loadMediaChromecast(url, title, subtitle, thumbnailUrl, contentType, startPosition, callback)
        }
    }

    private fun loadMediaChromecast(
        url: String,
        title: String,
        subtitle: String,
        thumbnailUrl: String,
        contentType: String,
        startPosition: Double,
        callback: (Boolean, String?) -> Unit
    ) {
        executor.execute {
            try {
                // Wait briefly if transportId is still establishing
                if (transportId == null && isConnected) {
                    for (i in 0 until 15) {
                        Thread.sleep(200)
                        if (transportId != null) break
                    }
                }

                if (!isConnected || transportId == null) {
                    mainHandler.post { callback(false, "Not connected to Cast media receiver") }
                    return@execute
                }

                val mediaInfo = JSONObject().apply {
                    put("contentId", url)
                    put("contentType", contentType)
                    put("streamType", "BUFFERED")
                    if (contentType.contains("mpegurl")) {
                        put("hlsSegmentFormat", "ts")
                        put("hlsVideoSegmentFormat", "ts")
                    }
                    put("metadata", JSONObject().apply {
                        put("type", 0)
                        put("metadataType", 0)
                        put("title", title)
                        put("subtitle", subtitle)
                        if (thumbnailUrl.isNotEmpty()) {
                            put("images", JSONArray().put(JSONObject().apply {
                                put("url", thumbnailUrl)
                            }))
                        }
                    })
                }

                val loadPayload = JSONObject().apply {
                    put("type", "LOAD")
                    put("media", mediaInfo)
                    put("autoplay", true)
                    put("currentTime", startPosition)
                    put("requestId", requestId++)
                }

                sendCastMessage(
                    sourceId = "sender-0",
                    destinationId = transportId!!,
                    namespace = "urn:x-cast:com.google.cast.media",
                    payload = loadPayload.toString()
                )

                mainHandler.post { callback(true, null) }

            } catch (e: Exception) {
                Log.e(TAG, "Load media error: ${e.message}")
                mainHandler.post { callback(false, e.message) }
            }
        }
    }

    private fun loadMediaDlna(
        device: CastDevice,
        url: String,
        title: String,
        subtitle: String,
        thumbnailUrl: String,
        contentType: String,
        startPosition: Double,
        callback: (Boolean, String?) -> Unit
    ) {
        val controlUrl = device.avTransportControlUrl
        if (controlUrl == null) {
            mainHandler.post { callback(false, "TV does not support AVTransport control") }
            return
        }

        executor.execute {
            try {
                // 1. Stop previous playback
                sendSoapAction(controlUrl, "Stop", """
                    <u:Stop xmlns:u="urn:schemas-upnp-org:service:AVTransport:1">
                        <InstanceID>0</InstanceID>
                    </u:Stop>
                """.trimIndent())

                // 2. SetAVTransportURI
                val escapedUrl = escapeXml(url)
                val escapedTitle = escapeXml(title)
                val escapedSubtitle = escapeXml(subtitle)
                val escapedThumb = escapeXml(thumbnailUrl)

                val didl = """
                    <DIDL-Lite xmlns="urn:schemas-upnp-org:metadata-1-0/DIDL-Lite/" xmlns:dc="http://purl.org/dc/elements/1.1/" xmlns:upnp="urn:schemas-upnp-org:metadata-1-0/upnp/">
                        <item id="0" parentID="-1" restricted="1">
                            <dc:title>$escapedTitle</dc:title>
                            <dc:creator>$escapedSubtitle</dc:creator>
                            <upnp:class>object.item.videoItem</upnp:class>
                            ${if (escapedThumb.isNotEmpty()) "<upnp:albumArtURI>$escapedThumb</upnp:albumArtURI>" else ""}
                            <res protocolInfo="http-get:*:$contentType:*">$escapedUrl</res>
                        </item>
                    </DIDL-Lite>
                """.trimIndent()
                val escapedDidl = escapeXml(didl)

                val setUriBody = """
                    <u:SetAVTransportURI xmlns:u="urn:schemas-upnp-org:service:AVTransport:1">
                        <InstanceID>0</InstanceID>
                        <CurrentURI>$escapedUrl</CurrentURI>
                        <CurrentURIMetaData>$escapedDidl</CurrentURIMetaData>
                    </u:SetAVTransportURI>
                """.trimIndent()

                val setRes = sendSoapAction(controlUrl, "SetAVTransportURI", setUriBody)
                if (setRes == null) {
                    mainHandler.post { callback(false, "Failed to send video to TV") }
                    return@execute
                }

                // 3. Play
                val playBody = """
                    <u:Play xmlns:u="urn:schemas-upnp-org:service:AVTransport:1">
                        <InstanceID>0</InstanceID>
                        <Speed>1</Speed>
                    </u:Play>
                """.trimIndent()
                sendSoapAction(controlUrl, "Play", playBody)

                // 4. Seek if starting at offset
                if (startPosition > 1.0) {
                    Thread.sleep(1000)
                    val targetTime = formatDuration(startPosition)
                    val seekBody = """
                        <u:Seek xmlns:u="urn:schemas-upnp-org:service:AVTransport:1">
                            <InstanceID>0</InstanceID>
                            <Unit>REL_TIME</Unit>
                            <Target>$targetTime</Target>
                        </u:Seek>
                    """.trimIndent()
                    sendSoapAction(controlUrl, "Seek", seekBody)
                }

                startDlnaPolling(controlUrl)
                mainHandler.post { callback(true, null) }
                notifyMediaStatus("PLAYING", startPosition, 0.0)

            } catch (e: Exception) {
                Log.e(TAG, "DLNA loadMedia error: ${e.message}")
                mainHandler.post { callback(false, e.message) }
            }
        }
    }

    fun play() {
        val currentDevice = connectedDevice ?: return
        if (currentDevice.type == "dlna") {
            currentDevice.avTransportControlUrl?.let { controlUrl ->
                executor.execute {
                    sendSoapAction(controlUrl, "Play", """
                        <u:Play xmlns:u="urn:schemas-upnp-org:service:AVTransport:1">
                            <InstanceID>0</InstanceID>
                            <Speed>1</Speed>
                        </u:Play>
                    """.trimIndent())
                    notifyMediaStatus("PLAYING", 0.0, 0.0)
                }
            }
        } else {
            sendMediaCommand("PLAY")
        }
    }

    fun pause() {
        val currentDevice = connectedDevice ?: return
        if (currentDevice.type == "dlna") {
            currentDevice.avTransportControlUrl?.let { controlUrl ->
                executor.execute {
                    sendSoapAction(controlUrl, "Pause", """
                        <u:Pause xmlns:u="urn:schemas-upnp-org:service:AVTransport:1">
                            <InstanceID>0</InstanceID>
                        </u:Pause>
                    """.trimIndent())
                    notifyMediaStatus("PAUSED", 0.0, 0.0)
                }
            }
        } else {
            sendMediaCommand("PAUSE")
        }
    }

    fun stop() {
        val currentDevice = connectedDevice ?: return
        if (currentDevice.type == "dlna") {
            stopDlnaPolling()
            currentDevice.avTransportControlUrl?.let { controlUrl ->
                executor.execute {
                    sendSoapAction(controlUrl, "Stop", """
                        <u:Stop xmlns:u="urn:schemas-upnp-org:service:AVTransport:1">
                            <InstanceID>0</InstanceID>
                        </u:Stop>
                    """.trimIndent())
                    notifyMediaStatus("IDLE", 0.0, 0.0)
                }
            }
        } else {
            sendMediaCommand("STOP")
        }
    }

    fun seek(position: Double) {
        val currentDevice = connectedDevice ?: return
        if (currentDevice.type == "dlna") {
            currentDevice.avTransportControlUrl?.let { controlUrl ->
                executor.execute {
                    val targetTime = formatDuration(position)
                    sendSoapAction(controlUrl, "Seek", """
                        <u:Seek xmlns:u="urn:schemas-upnp-org:service:AVTransport:1">
                            <InstanceID>0</InstanceID>
                            <Unit>REL_TIME</Unit>
                            <Target>$targetTime</Target>
                        </u:Seek>
                    """.trimIndent())
                }
            }
        } else {
            if (!isConnected || transportId == null || mediaSessionId <= 0) return
            executor.execute {
                try {
                    val payload = JSONObject().apply {
                        put("type", "SEEK")
                        put("mediaSessionId", mediaSessionId)
                        put("currentTime", position)
                        put("requestId", requestId++)
                    }
                    sendCastMessage(
                        sourceId = "sender-0",
                        destinationId = transportId!!,
                        namespace = "urn:x-cast:com.google.cast.media",
                        payload = payload.toString()
                    )
                } catch (e: Exception) {
                    Log.e(TAG, "Seek error: ${e.message}")
                }
            }
        }
    }

    fun setVolume(volume: Double) {
        val currentDevice = connectedDevice ?: return
        if (currentDevice.type == "dlna") {
            currentDevice.renderingControlUrl?.let { controlUrl ->
                executor.execute {
                    val volPercent = (volume.coerceIn(0.0, 1.0) * 100).toInt()
                    sendRenderingSoapAction(controlUrl, "SetVolume", """
                        <u:SetVolume xmlns:u="urn:schemas-upnp-org:service:RenderingControl:1">
                            <InstanceID>0</InstanceID>
                            <Channel>Master</Channel>
                            <DesiredVolume>$volPercent</DesiredVolume>
                        </u:SetVolume>
                    """.trimIndent())
                }
            }
        } else {
            if (!isConnected) return
            executor.execute {
                try {
                    val payload = JSONObject().apply {
                        put("type", "SET_VOLUME")
                        put("volume", JSONObject().apply {
                            put("level", volume.coerceIn(0.0, 1.0))
                        })
                        put("requestId", requestId++)
                    }
                    sendCastMessage(
                        sourceId = "sender-0",
                        destinationId = "receiver-0",
                        namespace = "urn:x-cast:com.google.cast.receiver",
                        payload = payload.toString()
                    )
                } catch (e: Exception) {
                    Log.e(TAG, "Set volume error: ${e.message}")
                }
            }
        }
    }

    private fun sendMediaCommand(type: String) {
        if (!isConnected || transportId == null || mediaSessionId <= 0) return
        executor.execute {
            try {
                val payload = JSONObject().apply {
                    put("type", type)
                    put("mediaSessionId", mediaSessionId)
                    put("requestId", requestId++)
                }
                sendCastMessage(
                    sourceId = "sender-0",
                    destinationId = transportId!!,
                    namespace = "urn:x-cast:com.google.cast.media",
                    payload = payload.toString()
                )
            } catch (e: Exception) {
                Log.e(TAG, "Media command $type error: ${e.message}")
            }
        }
    }

    // =================== DLNA POLLING & SOAP HELPERS ===================

    private fun startDlnaPolling(controlUrl: String) {
        stopDlnaPolling()
        dlnaPollThread = Thread {
            try {
                while (isConnected && connectedDevice?.type == "dlna" && !Thread.currentThread().isInterrupted) {
                    Thread.sleep(1500)
                    if (!isConnected || connectedDevice?.type != "dlna") break

                    val infoXml = sendSoapAction(controlUrl, "GetPositionInfo", """
                        <u:GetPositionInfo xmlns:u="urn:schemas-upnp-org:service:AVTransport:1">
                            <InstanceID>0</InstanceID>
                        </u:GetPositionInfo>
                    """.trimIndent())

                    if (infoXml != null) {
                        val relTimeStr = extractXmlTag(infoXml, "RelTime")
                        val trackDurStr = extractXmlTag(infoXml, "TrackDuration")
                        val pos = parseDurationSeconds(relTimeStr)
                        val dur = parseDurationSeconds(trackDurStr)

                        notifyMediaStatus("PLAYING", pos, dur)
                    }
                }
            } catch (_: InterruptedException) {
            } catch (e: Exception) {
                Log.d(TAG, "DLNA poll stopped: ${e.message}")
            }
        }
        dlnaPollThread?.isDaemon = true
        dlnaPollThread?.start()
    }

    private fun stopDlnaPolling() {
        dlnaPollThread?.interrupt()
        dlnaPollThread = null
    }

    private fun sendSoapAction(controlUrl: String, action: String, bodyXml: String): String? {
        var conn: HttpURLConnection? = null
        return try {
            val url = URL(controlUrl)
            conn = url.openConnection() as HttpURLConnection
            conn.requestMethod = "POST"
            conn.connectTimeout = 4000
            conn.readTimeout = 4000
            conn.doOutput = true
            conn.setRequestProperty("Content-Type", "text/xml; charset=\"utf-8\"")
            conn.setRequestProperty("SOAPAction", "\"urn:schemas-upnp-org:service:AVTransport:1#$action\"")

            val envelope = """<?xml version="1.0" encoding="utf-8"?><s:Envelope xmlns:s="http://schemas.xmlsoap.org/soap/envelope/" s:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/"><s:Body>$bodyXml</s:Body></s:Envelope>"""
            val bytes = envelope.toByteArray(Charsets.UTF_8)
            conn.setFixedLengthStreamingMode(bytes.size)
            conn.outputStream.use { it.write(bytes) }

            val code = conn.responseCode
            if (code in 200..299) {
                conn.inputStream.bufferedReader(Charsets.UTF_8).use { it.readText() }
            } else {
                Log.w(TAG, "SOAP $action failed ($code)")
                null
            }
        } catch (e: Exception) {
            Log.w(TAG, "SOAP $action error: ${e.message}")
            null
        } finally {
            conn?.disconnect()
        }
    }

    private fun sendRenderingSoapAction(controlUrl: String, action: String, bodyXml: String): String? {
        var conn: HttpURLConnection? = null
        return try {
            val url = URL(controlUrl)
            conn = url.openConnection() as HttpURLConnection
            conn.requestMethod = "POST"
            conn.connectTimeout = 3000
            conn.readTimeout = 3000
            conn.doOutput = true
            conn.setRequestProperty("Content-Type", "text/xml; charset=\"utf-8\"")
            conn.setRequestProperty("SOAPAction", "\"urn:schemas-upnp-org:service:RenderingControl:1#$action\"")

            val envelope = """<?xml version="1.0" encoding="utf-8"?><s:Envelope xmlns:s="http://schemas.xmlsoap.org/soap/envelope/" s:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/"><s:Body>$bodyXml</s:Body></s:Envelope>"""
            val bytes = envelope.toByteArray(Charsets.UTF_8)
            conn.setFixedLengthStreamingMode(bytes.size)
            conn.outputStream.use { it.write(bytes) }

            val code = conn.responseCode
            if (code in 200..299) {
                conn.inputStream.bufferedReader(Charsets.UTF_8).use { it.readText() }
            } else null
        } catch (_: Exception) {
            null
        } finally {
            conn?.disconnect()
        }
    }

    private fun extractControlUrl(xml: String, serviceKeyword: String, baseUrl: String): String? {
        val serviceTagOpen = "<service>"
        val serviceTagClose = "</service>"
        var searchIdx = 0

        while (searchIdx < xml.length) {
            val start = xml.indexOf(serviceTagOpen, searchIdx)
            if (start == -1) break
            val end = xml.indexOf(serviceTagClose, start)
            if (end == -1) break

            val serviceXml = xml.substring(start, end + serviceTagClose.length)
            val serviceType = extractXmlTag(serviceXml, "serviceType") ?: ""

            if (serviceType.contains(serviceKeyword, ignoreCase = true)) {
                val controlUrlRaw = extractXmlTag(serviceXml, "controlURL")
                if (!controlUrlRaw.isNullOrBlank()) {
                    return resolveUrl(baseUrl, controlUrlRaw)
                }
            }

            searchIdx = end + serviceTagClose.length
        }
        return null
    }

    private fun resolveUrl(base: String, relative: String): String {
        return try {
            URI(base).resolve(relative).toString()
        } catch (_: Exception) {
            if (relative.startsWith("/")) {
                val uri = URI(base)
                "${uri.scheme}://${uri.host}:${if (uri.port > 0) uri.port else 80}$relative"
            } else {
                "$base/$relative"
            }
        }
    }

    private fun extractXmlTag(xml: String, tag: String): String? {
        val openTag = "<$tag"
        val closeTag = "</$tag>"
        val startIdx = xml.indexOf(openTag)
        if (startIdx == -1) return null
        val contentStart = xml.indexOf('>', startIdx)
        if (contentStart == -1) return null
        val endIdx = xml.indexOf(closeTag, contentStart)
        if (endIdx == -1) return null
        return xml.substring(contentStart + 1, endIdx).trim()
    }

    private fun escapeXml(s: String): String {
        return s.replace("&", "&amp;")
            .replace("<", "&lt;")
            .replace(">", "&gt;")
            .replace("\"", "&quot;")
            .replace("'", "&apos;")
    }

    private fun parseDurationSeconds(timeStr: String?): Double {
        if (timeStr.isNullOrBlank() || timeStr == "NOT_IMPLEMENTED") return 0.0
        val parts = timeStr.split(":")
        return try {
            when (parts.size) {
                3 -> parts[0].toDouble() * 3600 + parts[1].toDouble() * 60 + parts[2].toDouble()
                2 -> parts[0].toDouble() * 60 + parts[1].toDouble()
                1 -> parts[0].toDouble()
                else -> 0.0
            }
        } catch (_: Exception) {
            0.0
        }
    }

    private fun formatDuration(seconds: Double): String {
        val sec = seconds.toInt().coerceAtLeast(0)
        val h = sec / 3600
        val m = (sec % 3600) / 60
        val s = sec % 60
        return String.format("%02d:%02d:%02d", h, m, s)
    }

    // =================== CAST V2 PROTOCOL ===================

    private fun sendCastMessage(
        sourceId: String,
        destinationId: String,
        namespace: String,
        payload: String
    ) {
        val os = outputStream ?: return

        synchronized(os) {
            try {
                val sourceBytes = sourceId.toByteArray(Charsets.UTF_8)
                val destBytes = destinationId.toByteArray(Charsets.UTF_8)
                val nsBytes = namespace.toByteArray(Charsets.UTF_8)
                val payloadBytes = payload.toByteArray(Charsets.UTF_8)

                val protoMessage = buildProtobuf(sourceBytes, destBytes, nsBytes, payloadBytes)

                val lengthPrefix = ByteBuffer.allocate(4)
                    .order(ByteOrder.BIG_ENDIAN)
                    .putInt(protoMessage.size)
                    .array()

                os.write(lengthPrefix)
                os.write(protoMessage)
                os.flush()
            } catch (e: Exception) {
                Log.e(TAG, "Failed to send Cast message: ${e.message}")
            }
        }
    }

    private fun buildProtobuf(
        sourceId: ByteArray,
        destinationId: ByteArray,
        namespace: ByteArray,
        payload: ByteArray
    ): ByteArray {
        val buffer = mutableListOf<Byte>()

        // protocol_version = 0
        buffer.add(0x08.toByte())
        buffer.add(0x00.toByte())

        // source_id
        buffer.add(0x12.toByte())
        buffer.addAll(encodeVarint(sourceId.size))
        buffer.addAll(sourceId.toList())

        // destination_id
        buffer.add(0x1A.toByte())
        buffer.addAll(encodeVarint(destinationId.size))
        buffer.addAll(destinationId.toList())

        // namespace
        buffer.add(0x22.toByte())
        buffer.addAll(encodeVarint(namespace.size))
        buffer.addAll(namespace.toList())

        // payload_type = 0 (STRING)
        buffer.add(0x28.toByte())
        buffer.add(0x00.toByte())

        // payload_utf8 (field 6, wire type 2: (6 << 3) | 2 = 50 = 0x32)
        buffer.add(0x32.toByte())
        buffer.addAll(encodeVarint(payload.size))
        buffer.addAll(payload.toList())

        return buffer.toByteArray()
    }

    private fun encodeVarint(value: Int): List<Byte> {
        val result = mutableListOf<Byte>()
        var v = value
        while (v > 0x7F) {
            result.add((v and 0x7F or 0x80).toByte())
            v = v ushr 7
        }
        result.add((v and 0x7F).toByte())
        return result
    }

    private fun startReceiver(socket: SSLSocket) {
        receiverThread = Thread {
            try {
                val inputStream = socket.inputStream
                val lengthBuffer = ByteArray(4)

                while (!Thread.currentThread().isInterrupted && isConnected) {
                    var bytesRead = 0
                    while (bytesRead < 4) {
                        val read = inputStream.read(lengthBuffer, bytesRead, 4 - bytesRead)
                        if (read < 0) {
                            handleDisconnect()
                            return@Thread
                        }
                        bytesRead += read
                    }

                    val messageLength = ByteBuffer.wrap(lengthBuffer)
                        .order(ByteOrder.BIG_ENDIAN)
                        .int

                    if (messageLength <= 0 || messageLength > 1024 * 1024) {
                        continue
                    }

                    val messageBuffer = ByteArray(messageLength)
                    bytesRead = 0
                    while (bytesRead < messageLength) {
                        val read = inputStream.read(messageBuffer, bytesRead, messageLength - bytesRead)
                        if (read < 0) {
                            handleDisconnect()
                            return@Thread
                        }
                        bytesRead += read
                    }

                    parseAndHandleMessage(messageBuffer)
                }
            } catch (e: Exception) {
                if (isConnected) {
                    Log.e(TAG, "Cast receiver error: ${e.message}")
                    handleDisconnect()
                }
            }
        }
        receiverThread?.isDaemon = true
        receiverThread?.start()

        startHeartbeat()
    }

    private fun parseAndHandleMessage(data: ByteArray) {
        try {
            var offset = 0
            var namespace = ""
            var payload = ""
            var sourceId = ""

            while (offset < data.size) {
                val tag = data[offset].toInt() and 0xFF
                offset++

                val fieldNumber = tag ushr 3
                val wireType = tag and 0x07

                when (wireType) {
                    0 -> { // varint
                        var shift = 0
                        while (offset < data.size) {
                            val b = data[offset].toInt() and 0xFF
                            offset++
                            if (b and 0x80 == 0) break
                            shift += 7
                        }
                    }
                    1 -> { // 64-bit
                        offset += 8
                    }
                    2 -> { // length-delimited
                        var length = 0
                        var shift = 0
                        while (offset < data.size) {
                            val b = data[offset].toInt() and 0xFF
                            offset++
                            length = length or ((b and 0x7F) shl shift)
                            if (b and 0x80 == 0) break
                            shift += 7
                        }
                        if (offset + length <= data.size) {
                            val strValue = String(data, offset, length, Charsets.UTF_8)
                            when (fieldNumber) {
                                2 -> sourceId = strValue
                                4 -> namespace = strValue
                                6 -> payload = strValue // payload_utf8
                                7 -> payload = strValue // payload_binary fallback
                            }
                            offset += length
                        } else {
                            break
                        }
                    }
                    5 -> { // 32-bit
                        offset += 4
                    }
                    else -> break
                }
            }

            if (payload.isNotEmpty()) {
                handleCastPayload(namespace, payload, sourceId)
            }
        } catch (e: Exception) {
            Log.w(TAG, "Failed to parse Cast message: ${e.message}")
        }
    }

    private fun handleCastPayload(namespace: String, payload: String, sourceId: String) {
        try {
            Log.d(TAG, "Cast received: [$namespace] $payload")
            val json = JSONObject(payload)
            val type = json.optString("type", "")

            when (namespace) {
                "urn:x-cast:com.google.cast.tp.heartbeat" -> {
                    if (type == "PING") {
                        sendCastMessage(
                            sourceId = "sender-0",
                            destinationId = sourceId,
                            namespace = "urn:x-cast:com.google.cast.tp.heartbeat",
                            payload = """{"type":"PONG"}"""
                        )
                    }
                }
                "urn:x-cast:com.google.cast.receiver" -> {
                    if (type == "RECEIVER_STATUS") {
                        val status = json.optJSONObject("status")
                        val apps = status?.optJSONArray("applications")
                        if (apps != null && apps.length() > 0) {
                            var targetApp: JSONObject? = null
                            for (i in 0 until apps.length()) {
                                val a = apps.getJSONObject(i)
                                if (a.optString("appId") == DEFAULT_MEDIA_RECEIVER_APP_ID) {
                                    targetApp = a
                                    break
                                }
                            }
                            if (targetApp == null) {
                                for (i in 0 until apps.length()) {
                                    val a = apps.getJSONObject(i)
                                    if (!a.optBoolean("isIdleScreen", false) && a.optString("transportId").isNotEmpty()) {
                                        targetApp = a
                                        break
                                    }
                                }
                            }
                            if (targetApp == null) {
                                targetApp = apps.getJSONObject(0)
                            }

                            val newTransportId = targetApp.optString("transportId", "")
                            if (newTransportId.isNotEmpty()) {
                                if (transportId != newTransportId) {
                                    transportId = newTransportId
                                    sendCastMessage(
                                        sourceId = "sender-0",
                                        destinationId = newTransportId,
                                        namespace = "urn:x-cast:com.google.cast.tp.connection",
                                        payload = """{"type":"CONNECT"}"""
                                    )
                                }
                                pendingLaunchLatch?.countDown()
                            }
                        }

                        val volume = status?.optJSONObject("volume")
                        if (volume != null) {
                            val level = volume.optDouble("level", -1.0)
                            val muted = volume.optBoolean("muted", false)
                            if (level >= 0) {
                                notifyCastVolume(level, muted)
                            }
                        }
                    } else if (type == "LAUNCH_ERROR") {
                        Log.e(TAG, "Chromecast reported LAUNCH_ERROR: $payload")
                        pendingLaunchLatch?.countDown()
                    }
                }
                "urn:x-cast:com.google.cast.media" -> {
                    if (type == "MEDIA_STATUS") {
                        val statusArray = json.optJSONArray("status")
                        if (statusArray != null && statusArray.length() > 0) {
                            val mediaStatus = statusArray.getJSONObject(0)
                            mediaSessionId = mediaStatus.optInt("mediaSessionId", mediaSessionId)
                            val playerState = mediaStatus.optString("playerState", "UNKNOWN")
                            val currentTime = mediaStatus.optDouble("currentTime", 0.0)
                            val duration = mediaStatus.optJSONObject("media")?.optDouble("duration", 0.0) ?: 0.0

                            notifyMediaStatus(playerState, currentTime, duration)
                        }
                    } else if (type == "LOAD_FAILED") {
                        Log.e(TAG, "TV reported LOAD_FAILED: $payload")
                        notifyMediaStatus("IDLE", 0.0, 0.0)
                    }
                }
            }
        } catch (e: Exception) {
            Log.w(TAG, "Error handling payload: ${e.message}")
        }
    }

    private fun startHeartbeat() {
        executor.execute {
            try {
                while (isConnected && connectedDevice?.type == "chromecast") {
                    Thread.sleep(5000)
                    if (isConnected && connectedDevice?.type == "chromecast") {
                        sendCastMessage(
                            sourceId = "sender-0",
                            destinationId = "receiver-0",
                            namespace = "urn:x-cast:com.google.cast.tp.heartbeat",
                            payload = """{"type":"PING"}"""
                        )
                    }
                }
            } catch (_: InterruptedException) {}
        }
    }

    private fun handleDisconnect() {
        isConnected = false
        connectedDevice = null
        transportId = null
        mediaSessionId = 0
        try { castSocket?.close() } catch (_: Exception) {}
        castSocket = null
        outputStream = null
        stopDlnaPolling()
        notifyConnectionChanged(false, null)
    }

    // =================== FLUTTER NOTIFICATIONS ===================

    private fun notifyDeviceFound(device: CastDevice) {
        mainHandler.post {
            methodChannel?.invokeMethod("onCastDeviceFound", mapOf(
                "id" to device.id,
                "name" to device.name,
                "host" to device.hostAddress,
                "port" to device.port,
                "model" to device.model,
                "type" to device.type
            ))
        }
    }

    private fun notifyDevicesUpdated() {
        mainHandler.post {
            methodChannel?.invokeMethod("onCastDevicesUpdated", getDiscoveredDevices())
        }
    }

    private fun notifyConnectionChanged(connected: Boolean, device: CastDevice?) {
        mainHandler.post {
            methodChannel?.invokeMethod("onCastConnectionChanged", mapOf(
                "connected" to connected,
                "deviceName" to (device?.name ?: ""),
                "deviceId" to (device?.id ?: "")
            ))
        }
    }

    private fun notifyMediaStatus(state: String, currentTime: Double, duration: Double) {
        mainHandler.post {
            methodChannel?.invokeMethod("onCastMediaStatus", mapOf(
                "state" to state,
                "position" to currentTime,
                "duration" to duration
            ))
        }
    }

    private fun notifyCastVolume(level: Double, muted: Boolean) {
        mainHandler.post {
            methodChannel?.invokeMethod("onCastVolumeChanged", mapOf(
                "level" to level,
                "muted" to muted
            ))
        }
    }

    fun isConnected(): Boolean = isConnected
    fun getConnectedDeviceName(): String = connectedDevice?.name ?: ""

    fun destroy() {
        stopDiscovery()
        disconnect()
        executor.shutdownNow()
    }
}
