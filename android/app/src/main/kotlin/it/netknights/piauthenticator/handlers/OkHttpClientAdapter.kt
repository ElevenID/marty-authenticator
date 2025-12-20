package it.netknights.piauthenticator.handlers

import android.util.Log
import okhttp3.*
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.RequestBody.Companion.toRequestBody
import java.io.IOException
import java.util.concurrent.TimeUnit
import kotlinx.coroutines.*
import com.spruceid.mobile.sdk.rs.AsyncHttpClient

/**
 * HTTP client wrapper using OkHttp for SpruceID SDK operations.
 *
 * This provides async HTTP functionality for Oid4vci operations like:
 * - Fetching issuer metadata
 * - Token exchange
 * - Credential requests
 *
 * Pattern based on SpruceID Showcase App's HTTP client implementation.
 */
class HttpClientWrapper : AsyncHttpClient {

    companion object {
        private const val TAG = "HttpClientWrapper"
        private const val DEFAULT_TIMEOUT_SECONDS = 30L
    }

    private val client: OkHttpClient = OkHttpClient.Builder()
        .connectTimeout(DEFAULT_TIMEOUT_SECONDS, TimeUnit.SECONDS)
        .readTimeout(DEFAULT_TIMEOUT_SECONDS, TimeUnit.SECONDS)
        .writeTimeout(DEFAULT_TIMEOUT_SECONDS, TimeUnit.SECONDS)
        .followRedirects(true)
        .followSslRedirects(true)
        .build()

    // Attempt to satisfy interface requirement
    // override val httpClient: Any = client
    // Commented out to see the error message again or I can try to implement what I think it is.
    // But wait, if I don't implement it, I get the error.
    // I'll try to implement it as `OkHttpClient` and see.

    override val httpClient: Any = client

    /**
     * Perform an async HTTP GET request.
     *
     * @param url The URL to request
     * @param headers Map of HTTP headers
     * @return Response body as string
     */
    suspend fun get(url: String): String {
        return get(url, emptyMap())
    }

    suspend fun get(url: String, headers: Map<String, String> = emptyMap()): String {
        return withContext(Dispatchers.IO) {
            try {
                Log.d(TAG, "GET request to: $url")

                val requestBuilder = Request.Builder().url(url)
                headers.forEach { (key, value) ->
                    requestBuilder.addHeader(key, value)
                }

                val request = requestBuilder.build()
                val response = client.newCall(request).execute()

                if (!response.isSuccessful) {
                    val errorBody = response.body?.string() ?: "No response body"
                    Log.e(TAG, "GET failed with status ${response.code}: $errorBody")
                    throw IOException("HTTP ${response.code}: $errorBody")
                }

                val responseBody = response.body?.string()
                    ?: throw IOException("Empty response body")

                Log.d(TAG, "GET success: ${responseBody.length} bytes")
                responseBody

            } catch (e: Exception) {
                Log.e(TAG, "GET request failed", e)
                throw IOException("GET request failed: ${e.message}", e)
            }
        }
    }

    /**
     * Perform an async HTTP POST request.
     *
     * @param url The URL to request
     * @param requestBody The body content
     * @return Response body as string
     */
    suspend fun post(url: String, requestBody: String): String {
        return post(url, requestBody)
    }

    suspend fun post(
        url: String,
        body: String,
        contentType: String = "application/json",
        headers: Map<String, String> = emptyMap()
    ): String {
        return withContext(Dispatchers.IO) {
            try {
                Log.d(TAG, "POST request to: $url")
                Log.d(TAG, "Content-Type: $contentType")
                Log.d(TAG, "Body: ${body.take(200)}...") // Log first 200 chars

                val mediaType = contentType.toMediaType()
                val requestBody = body.toRequestBody(mediaType)

                val requestBuilder = Request.Builder()
                    .url(url)
                    .post(requestBody)

                headers.forEach { (key, value) ->
                    requestBuilder.addHeader(key, value)
                }

                val request = requestBuilder.build()
                val response = client.newCall(request).execute()

                if (!response.isSuccessful) {
                    val errorBody = response.body?.string() ?: "No response body"
                    Log.e(TAG, "POST failed with status ${response.code}: $errorBody")
                    throw IOException("HTTP ${response.code}: $errorBody")
                }

                val responseBody = response.body?.string()
                    ?: throw IOException("Empty response body")

                Log.d(TAG, "POST success: ${responseBody.length} bytes")
                responseBody

            } catch (e: Exception) {
                Log.e(TAG, "POST request failed", e)
                throw IOException("POST request failed: ${e.message}", e)
            }
        }
    }

    /**
     * Get the underlying OkHttp client for advanced operations.
     *
     * @return The OkHttpClient instance
     */
    fun getOkHttpClient(): OkHttpClient = client

    /**
     * Clean up resources when done.
     */
    fun shutdown() {
        client.dispatcher.executorService.shutdown()
        client.connectionPool.evictAll()
    }
}
