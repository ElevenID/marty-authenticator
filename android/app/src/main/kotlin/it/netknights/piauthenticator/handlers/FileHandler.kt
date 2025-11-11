package it.netknights.piauthenticator.handlers

import android.content.Context
import android.net.Uri
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel.Result
import java.io.ObjectInputStream

/**
 * Handles file reading operations for the Flutter application.
 * Specifically handles reading JSON data from files using ObjectInputStream.
 */
class FileHandler(private val context: Context) {

    /**
     * Handles method calls related to file operations.
     * Currently supports reading JSON data from a file path.
     *
     * @param call The method call containing the method name and arguments
     * @param result The result callback to return success/error responses
     */
    fun handleCall(call: MethodCall, result: Result) {
        when (call.method) {
            "json" -> readJsonFromFile(call, result)
            else -> result.error("UNAVAILABLE", "Method ${call.method} not implemented", null)
        }
    }

    /**
     * Reads JSON data from a file using the provided URI path.
     *
     * @param call The method call containing path argument
     * @param result The result callback
     */
    private fun readJsonFromFile(call: MethodCall, result: Result) {
        try {
            val args = call.arguments as? Map<String, String>
                ?: throw IllegalArgumentException("Arguments must be a map")

            val path = args["path"] as? String
                ?: throw IllegalArgumentException("Path argument is required")

            val uri = Uri.parse(path)
            val inputStream = context.contentResolver.openInputStream(uri)
                ?: throw IllegalArgumentException("Cannot open input stream for path: $path")

            val input = ObjectInputStream(inputStream)
            val entries = input.readObject() as? Map<String, *>
                ?: throw IllegalArgumentException("File content is not a valid Map")

            result.success(entries)
        } catch (e: Exception) {
            result.error("FILE_READ_ERROR", "Failed to read file: ${e.message}", e.toString())
        }
    }
}
