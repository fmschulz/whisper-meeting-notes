package com.example.recordingtranscription

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import java.io.File
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch

class RecorderViewModel : ViewModel() {

  private val _uiState = MutableStateFlow(RecordingUiState())
  val uiState: StateFlow<RecordingUiState> = _uiState

  fun startSession(transcriptionEnabled: Boolean) {
    _uiState.update { state ->
      state.copy(
        isRecording = true,
        transcriptionEnabled = transcriptionEnabled,
        liveTranscription = "",
        lastError = null,
        lastSavedRecording = null,
      )
    }
  }

  fun abortSession(errorMessage: String) {
    _uiState.update { state ->
      state.copy(
        isRecording = false,
        lastError = errorMessage,
      )
    }
  }

  fun appendFinalTranscription(text: String) {
    if (text.isBlank()) return
    val sanitized = text.trim()
    _uiState.update { state ->
      if (!state.isRecording) state else {
        val joined = when {
          state.liveTranscription.isBlank() -> sanitized
          else -> state.liveTranscription + "\n" + sanitized
        }
        state.copy(liveTranscription = joined, lastError = null)
      }
    }
  }

  fun reportError(message: String) {
    _uiState.update { state ->
      state.copy(lastError = message)
    }
  }

  fun finishSession(audioFile: File?) {
    if (audioFile == null) {
      _uiState.update { state ->
        state.copy(
          isRecording = false,
          lastError = "Recording failed",
        )
      }
      return
    }

    val transcriptText = _uiState.value.liveTranscription.trim()
    viewModelScope.launch(Dispatchers.IO) {
      val transcriptionFile = if (transcriptText.isNotEmpty()) {
        val baseName = audioFile.name.substringBeforeLast('.', audioFile.name)
        val file = File(audioFile.parentFile, "$baseName-transcript.txt")
        file.writeText(transcriptText)
        file
      } else {
        null
      }

      val completed = CompletedRecording(
        audioPath = audioFile.absolutePath,
        transcriptionPath = transcriptionFile?.absolutePath,
        transcriptPreview = transcriptText.take(200),
      )

      _uiState.update { state ->
        state.copy(
          isRecording = false,
          lastError = null,
          liveTranscription = transcriptText,
          lastSavedRecording = completed,
          completedRecordings = listOf(completed) + state.completedRecordings,
        )
      }
    }
  }

  fun consumeError(): String? {
    val error = _uiState.value.lastError
    _uiState.update { state -> state.copy(lastError = null) }
    return error
  }
}

data class RecordingUiState(
  val isRecording: Boolean = false,
  val transcriptionEnabled: Boolean = false,
  val liveTranscription: String = "",
  val lastError: String? = null,
  val lastSavedRecording: CompletedRecording? = null,
  val completedRecordings: List<CompletedRecording> = emptyList(),
 )

data class CompletedRecording(
  val audioPath: String,
  val transcriptionPath: String?,
  val transcriptPreview: String,
 )
