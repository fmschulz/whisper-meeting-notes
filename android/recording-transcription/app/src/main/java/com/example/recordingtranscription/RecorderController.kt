package com.example.recordingtranscription

import android.content.Context
import android.media.MediaRecorder
import android.os.Build
import java.io.File
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

class RecorderController(private val context: Context) {

  private var mediaRecorder: MediaRecorder? = null
  private var currentFile: File? = null

  private val timeFormatter = SimpleDateFormat("yyyyMMdd-HHmmss", Locale.US)

  fun startRecording(): File {
    check(mediaRecorder == null) { "Recorder is already running" }

    val recordingsDir = File(context.filesDir, "recordings")
    if (!recordingsDir.exists()) {
      recordingsDir.mkdirs()
    }

    val audioFile = File(recordingsDir, "rec-${timeFormatter.format(Date())}.m4a")

    val recorder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
      MediaRecorder(context)
    } else {
      @Suppress("DEPRECATION")
      MediaRecorder()
    }

    recorder.apply {
      setAudioSource(MediaRecorder.AudioSource.MIC)
      setOutputFormat(MediaRecorder.OutputFormat.MPEG_4)
      setAudioEncoder(MediaRecorder.AudioEncoder.AAC)
      setAudioEncodingBitRate(128_000)
      setAudioSamplingRate(44_100)
      setOutputFile(audioFile.absolutePath)
      prepare()
      start()
    }

    mediaRecorder = recorder
    currentFile = audioFile
    return audioFile
  }

  fun stopRecording(): File? {
    val recorder = mediaRecorder ?: return null
    val audioFile = currentFile

    runCatching {
      recorder.stop()
    }.onFailure {
      audioFile?.delete()
    }
    recorder.reset()
    recorder.release()

    mediaRecorder = null
    currentFile = null

    return audioFile
  }

  fun cancelRecording() {
    val recorder = mediaRecorder ?: return
    runCatching {
      recorder.stop()
    }
    recorder.reset()
    recorder.release()
    currentFile?.delete()
    mediaRecorder = null
    currentFile = null
  }
}
