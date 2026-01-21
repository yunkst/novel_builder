package com.example.novel_app

import android.content.Context
import android.media.AudioAttributes
import android.media.AudioFocusRequest
import android.media.AudioManager
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.speech.tts.TextToSpeech
import android.speech.tts.UtteranceProgressListener
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import java.util.Locale
import java.util.UUID

/// TTS插件 - Android原生实现
class TtsPlugin(private val context: Context) : MethodCallHandler {
    private var tts: TextToSpeech? = null
    private var initialized = false
    private var audioManager: AudioManager? = null
    private var focusRequest: AudioFocusRequest? = null
    private var methodChannel: MethodChannel? = null

    companion object {
        private const val CHANNEL = "com.example.novel_app/tts"
    }

    fun setMethodChannel(channel: MethodChannel) {
        this.methodChannel = channel
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "initialize" -> initializeTts(result)
            "speak" -> {
                val text = call.argument<String>("text")
                if (text != null) {
                    speak(text, result)
                } else {
                    result.error("INVALID_ARGUMENT", "Text is required", null)
                }
            }
            "pause" -> pause(result)
            "resume" -> resume(result)
            "stop" -> stop(result)
            "setSpeechRate" -> {
                val rate = call.argument<Double>("rate") ?: 1.0
                setRate(rate, result)
            }
            "setPitch" -> {
                val pitch = call.argument<Double>("pitch") ?: 1.0
                setPitch(pitch, result)
            }
            "setVolume" -> {
                val volume = call.argument<Double>("volume") ?: 1.0
                setVolume(volume, result)
            }
            "getVoices" -> getVoices(result)
            "setVoice" -> {
                val voiceId = call.argument<String>("voiceId")
                if (voiceId != null) {
                    setVoice(voiceId, result)
                } else {
                    result.error("INVALID_ARGUMENT", "Voice ID is required", null)
                }
            }
            else -> result.notImplemented()
        }
    }

    /// 初始化TTS引擎
    private fun initializeTts(result: MethodChannel.Result) {
        try {
            audioManager = context.getSystemService(Context.AUDIO_SERVICE) as AudioManager

            tts = TextToSpeech(context) { status ->
                if (status == TextToSpeech.SUCCESS) {
                    // 设置默认语言为中文
                    val langResult = tts?.setLanguage(Locale.CHINA)
                    if (langResult == TextToSpeech.LANG_MISSING_DATA || langResult == TextToSpeech.LANG_NOT_SUPPORTED) {
                        // 如果中文不支持，尝试使用系统默认语言
                        tts?.setLanguage(Locale.getDefault())
                    }

                    // 设置音频属性
                    setAudioAttributes()

                    initialized = true
                    result.success(true)
                } else {
                    initialized = false
                    result.success(false)
                }
            }

            // 设置朗读完成监听
            tts?.setOnUtteranceProgressListener(object : UtteranceProgressListener() {
                override fun onStart(utteranceId: String?) {
                    android.util.Log.d("TtsPlugin", "onStart: utteranceId=$utteranceId, thread=${Thread.currentThread().name}")
                    // 确保在主线程执行回调
                    Handler(Looper.getMainLooper()).post {
                        notifySpeakStart(utteranceId)
                    }
                }

                override fun onDone(utteranceId: String?) {
                    android.util.Log.d("TtsPlugin", "onDone: utteranceId=$utteranceId, thread=${Thread.currentThread().name}")
                    // 确保在主线程执行回调
                    Handler(Looper.getMainLooper()).post {
                        notifySpeakComplete(utteranceId)
                    }
                }

                override fun onError(utteranceId: String?) {
                    android.util.Log.e("TtsPlugin", "onError: utteranceId=$utteranceId, thread=${Thread.currentThread().name}")
                    // 确保在主线程执行回调
                    Handler(Looper.getMainLooper()).post {
                        notifySpeakError(utteranceId ?: "Unknown error")
                    }
                }

                // API 21+ 需要重写此方法
                override fun onStop(utteranceId: String?, interrupted: Boolean) {
                    android.util.Log.d("TtsPlugin", "onStop: utteranceId=$utteranceId, interrupted=$interrupted, thread=${Thread.currentThread().name}")
                    super.onStop(utteranceId, interrupted)
                }
            })
        } catch (e: Exception) {
            e.printStackTrace()
            result.success(false)
        }
    }

    /// 设置音频属性
    private fun setAudioAttributes() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
            tts?.setAudioAttributes(
                AudioAttributes.Builder()
                    .setUsage(AudioAttributes.USAGE_MEDIA)
                    .setContentType(AudioAttributes.CONTENT_TYPE_SPEECH)
                    .build()
            )
        } else {
            @Suppress("DEPRECATION")
            tts?.setSpeechRate(1.0f)
        }
    }

    /// 请求音频焦点
    private fun requestAudioFocus(): Boolean {
        if (audioManager == null) return false

        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val audioAttributes = AudioAttributes.Builder()
                .setUsage(AudioAttributes.USAGE_MEDIA)
                .setContentType(AudioAttributes.CONTENT_TYPE_SPEECH)
                .build()

            focusRequest = AudioFocusRequest.Builder(AudioManager.AUDIOFOCUS_GAIN)
                .setAudioAttributes(audioAttributes)
                .setAcceptsDelayedFocusGain(true)
                .setOnAudioFocusChangeListener { focusChange ->
                    when (focusChange) {
                        AudioManager.AUDIOFOCUS_LOSS -> {
                            // 永久失去焦点，停止播放
                            tts?.stop()
                            abandonAudioFocus()
                        }
                        AudioManager.AUDIOFOCUS_LOSS_TRANSIENT -> {
                            // 暂时失去焦点，暂停播放
                            tts?.stop()
                        }
                        AudioManager.AUDIOFOCUS_GAIN -> {
                            // 重新获得焦点，恢复播放
                            // 实际的恢复由Flutter层控制
                        }
                    }
                }
                .build()

            val result = audioManager?.requestAudioFocus(focusRequest!!)
            result == AudioManager.AUDIOFOCUS_REQUEST_GRANTED
        } else {
            @Suppress("DEPRECATION")
            val result = audioManager?.requestAudioFocus(
                { focusChange ->
                    when (focusChange) {
                        AudioManager.AUDIOFOCUS_LOSS -> {
                            tts?.stop()
                            // 释放音频焦点
                            audioManager?.abandonAudioFocus { }
                        }
                        AudioManager.AUDIOFOCUS_LOSS_TRANSIENT -> {
                            tts?.stop()
                        }
                        AudioManager.AUDIOFOCUS_GAIN -> {
                            // 实际的恢复由Flutter层控制
                        }
                    }
                },
                AudioManager.STREAM_MUSIC,
                AudioManager.AUDIOFOCUS_GAIN
            )
            result == AudioManager.AUDIOFOCUS_REQUEST_GRANTED
        }
    }

    /// 释放音频焦点
    private fun abandonAudioFocus() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            focusRequest?.let {
                audioManager?.abandonAudioFocusRequest(it)
            }
            focusRequest = null
        } else {
            @Suppress("DEPRECATION")
            audioManager?.abandonAudioFocus { }
        }
    }

    /// 朗读文本
    private fun speak(text: String, result: MethodChannel.Result) {
        if (!initialized) {
            result.error("NOT_INITIALIZED", "TTS not initialized", null)
            return
        }

        try {
            // 请求音频焦点
            requestAudioFocus()

            val utteranceId = UUID.randomUUID().toString()

            android.util.Log.d("TtsPlugin", "speak: text长度=${text.length}, utteranceId=$utteranceId")

            // API 21+ 使用空的Bundle，utteranceId通过参数传递
            val params = android.os.Bundle()
            val speakResult = tts?.speak(text, TextToSpeech.QUEUE_ADD, params, utteranceId)
            android.util.Log.d("TtsPlugin", "speak结果: $speakResult")
            if (speakResult == TextToSpeech.SUCCESS) {
                result.success(utteranceId)
            } else {
                android.util.Log.e("TtsPlugin", "speak失败: result=$speakResult")
                result.error("SPEAK_FAILED", "Failed to start speaking", null)
            }
        } catch (e: Exception) {
            android.util.Log.e("TtsPlugin", "speak异常", e)
            e.printStackTrace()
            result.error("SPEAK_ERROR", e.message, null)
        }
    }

    /// 暂停朗读
    private fun pause(result: MethodChannel.Result) {
        if (!initialized) {
            result.success(null)
            return
        }

        try {
            val stopResult = tts?.stop()
            result.success(null)
        } catch (e: Exception) {
            e.printStackTrace()
            result.error("PAUSE_ERROR", e.message, null)
        }
    }

    /// 继续朗读
    private fun resume(result: MethodChannel.Result) {
        if (!initialized) {
            result.success(null)
            return
        }

        try {
            // TTS没有直接的resume方法，需要重新调用speak
            // 这里只是返回成功，实际的resume由Flutter层控制
            result.success(null)
        } catch (e: Exception) {
            e.printStackTrace()
            result.error("RESUME_ERROR", e.message, null)
        }
    }

    /// 停止朗读
    private fun stop(result: MethodChannel.Result) {
        if (!initialized) {
            result.success(null)
            return
        }

        try {
            tts?.stop()
            abandonAudioFocus()
            result.success(null)
        } catch (e: Exception) {
            e.printStackTrace()
            result.error("STOP_ERROR", e.message, null)
        }
    }

    /// 设置语速
    private fun setRate(rate: Double, result: MethodChannel.Result) {
        if (!initialized) {
            result.success(null)
            return
        }

        try {
            val speechRate = rate.toFloat()
            tts?.setSpeechRate(speechRate)
            result.success(null)
        } catch (e: Exception) {
            e.printStackTrace()
            result.error("SET_RATE_ERROR", e.message, null)
        }
    }

    /// 设置音调
    private fun setPitch(pitch: Double, result: MethodChannel.Result) {
        if (!initialized) {
            result.success(null)
            return
        }

        try {
            val pitchValue = pitch.toFloat()
            tts?.setPitch(pitchValue)
            result.success(null)
        } catch (e: Exception) {
            e.printStackTrace()
            result.error("SET_PITCH_ERROR", e.message, null)
        }
    }

    /// 设置音量
    private fun setVolume(volume: Double, result: MethodChannel.Result) {
        if (!initialized) {
            result.success(null)
            return
        }

        try {
            val volumeValue = volume.toFloat()
            // TTS API不直接支持设置音量，这里记录但不实际设置
            // 音量控制可以通过AudioManager实现
            result.success(null)
        } catch (e: Exception) {
            e.printStackTrace()
            result.error("SET_VOLUME_ERROR", e.message, null)
        }
    }

    /// 获取可用语音列表
    private fun getVoices(result: MethodChannel.Result) {
        if (!initialized) {
            result.error("NOT_INITIALIZED", "TTS not initialized", null)
            return
        }

        try {
            val voices = tts?.voices?.map { voice ->
                mapOf(
                    "id" to (voice.name ?: ""),
                    "name" to (voice.locale?.displayName ?: ""),
                    "locale" to (voice.locale?.toString() ?: ""),
                    "language" to (voice.locale?.language ?: "")
                )
            }
            result.success(voices)
        } catch (e: Exception) {
            e.printStackTrace()
            result.error("GET_VOICES_ERROR", e.message, null)
        }
    }

    /// 设置语音
    private fun setVoice(voiceId: String, result: MethodChannel.Result) {
        if (!initialized) {
            result.success(null)
            return
        }

        try {
            val voice = tts?.voices?.find { it.name == voiceId }
            if (voice != null) {
                tts?.setVoice(voice)
                result.success(null)
            } else {
                result.error("VOICE_NOT_FOUND", "Voice not found: $voiceId", null)
            }
        } catch (e: Exception) {
            e.printStackTrace()
            result.error("SET_VOICE_ERROR", e.message, null)
        }
    }

    /// 通知：朗读开始
    private fun notifySpeakStart(utteranceId: String?) {
        android.util.Log.d("TtsPlugin", "notifySpeakStart: utteranceId=$utteranceId")
        methodChannel?.invokeMethod("onSpeakStart", utteranceId)
    }

    /// 通知：朗读完成
    private fun notifySpeakComplete(utteranceId: String?) {
        android.util.Log.d("TtsPlugin", "notifySpeakComplete: utteranceId=$utteranceId")
        methodChannel?.invokeMethod("onSpeakComplete", utteranceId)
    }

    /// 通知：朗读错误
    private fun notifySpeakError(error: String) {
        android.util.Log.e("TtsPlugin", "notifySpeakError: error=$error")
        methodChannel?.invokeMethod("onError", error)
    }

    /// 释放资源
    fun dispose() {
        tts?.stop()
        tts?.shutdown()
        abandonAudioFocus()
        tts = null
        initialized = false
    }
}
