package com.devniket.instaplus

import android.app.Activity
import android.content.ActivityNotFoundException
import android.content.Intent
import android.net.Uri
import androidx.core.content.FileProvider
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import java.io.File

class InstagramSharePlugin : FlutterPlugin, MethodCallHandler, ActivityAware {
    private lateinit var channel: MethodChannel
    private var activity: Activity? = null

    override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        channel = MethodChannel(flutterPluginBinding.binaryMessenger, "instagram_share_channel")
        channel.setMethodCallHandler(this)
    }

    override fun onMethodCall(call: MethodCall, result: Result) {
        if (call.method == "shareToInstagramStory") {
            val imagePath: String? = call.argument("imagePath")
            val appId: String? = call.argument("appId")
            
            if (imagePath == null || appId == null) {
                result.error("INVALID_ARGUMENTS", "Image path and app ID are required", null)
                return
            }
            
            shareToInstagramStory(imagePath, appId, result)
        } else {
            result.notImplemented()
        }
    }

    private fun shareToInstagramStory(imagePath: String, appId: String, result: Result) {
        try {
            val file = File(imagePath)
            val contentUri = FileProvider.getUriForFile(
                activity!!.applicationContext,
                activity!!.applicationContext.packageName + ".fileprovider",
                file
            )
            
            val intent = Intent("com.instagram.share.ADD_TO_STORY")
            intent.putExtra("source_application", appId)
            intent.setDataAndType(contentUri, "image/*")
            intent.flags = Intent.FLAG_GRANT_READ_URI_PERMISSION
            
            // Verify the intent will resolve to at least one activity
            if (activity!!.packageManager.resolveActivity(intent, 0) != null) {
                activity!!.startActivity(intent)
                result.success("success")
            } else {
                result.error("NO_INSTAGRAM", "Instagram app is not installed", null)
            }
        } catch (e: Exception) {
            result.error("SHARE_FAILED", e.message, null)
        }
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activity = binding.activity
    }

    override fun onDetachedFromActivityForConfigChanges() {
        activity = null
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        activity = binding.activity
    }

    override fun onDetachedFromActivity() {
        activity = null
    }
} 