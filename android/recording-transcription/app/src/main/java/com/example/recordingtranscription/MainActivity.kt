package com.example.recordingtranscription

import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Bundle
import android.speech.RecognitionListener
import android.speech.RecognizerIntent
import android.speech.SpeechRecognizer
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.activity.viewModels
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Button
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Switch
import androidx.compose.material3.SwitchDefaults
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp
import androidx.core.content.ContextCompat
import com.example.recordingtranscription.ui.theme.RecorderTheme
import java.io.File

class MainActivity : ComponentActivity() {

  private val viewModel: RecorderViewModel by viewModels()

  override fun onCreate(savedInstanceState: Bundle?) {
    super.onCreate(savedInstanceState)

    setContent {
      val context = LocalContext.current
      val uiState by viewModel.uiState.collectAsState()
      val hasSpeechRecognizer = remember { SpeechRecognizer.isRecognitionAvailable(context) }
      val recorderController = remember { RecorderController(context) }
      val partialTranscription = remember { mutableStateOf("") }
      val recordingsDir = remember { File(context.filesDir, "recordings") }
      val speechRecognizer = remember {
        if (hasSpeechRecognizer) SpeechRecognizer.createSpeechRecognizer(context) else null
      }
      val recognitionIntent = remember {
        Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH).apply {
          putExtra(RecognizerIntent.EXTRA_LANGUAGE_MODEL, RecognizerIntent.LANGUAGE_MODEL_FREE_FORM)
          putExtra(RecognizerIntent.EXTRA_PARTIAL_RESULTS, true)
          putExtra(RecognizerIntent.EXTRA_MAX_RESULTS, 5)
        }
      }

      var hasRecordPermission by remember {
        mutableStateOf(
          ContextCompat.checkSelfPermission(
            context,
            Manifest.permission.RECORD_AUDIO,
          ) == PackageManager.PERMISSION_GRANTED,
        )
      }

      val permissionLauncher = rememberLauncherForActivityResult(
        ActivityResultContracts.RequestPermission(),
      ) { granted ->
        hasRecordPermission = granted
        if (!granted) {
          viewModel.abortSession("Microphone permission is required to record audio")
        }
      }

      DisposableEffect(speechRecognizer) {
        val recognizer = speechRecognizer
        if (recognizer != null) {
          recognizer.setRecognitionListener(
            object : RecognitionListener {
              override fun onReadyForSpeech(params: Bundle?) = Unit

              override fun onBeginningOfSpeech() = Unit

              override fun onRmsChanged(rmsdB: Float) = Unit

              override fun onBufferReceived(buffer: ByteArray?) = Unit

              override fun onEndOfSpeech() {
                val state = viewModel.uiState.value
                if (state.isRecording && state.transcriptionEnabled) {
                  recognizer.startListening(recognitionIntent)
                }
              }

              override fun onError(error: Int) {
                partialTranscription.value = ""
                viewModel.reportError("Transcription error: ${speechErrorMessage(error)}")
                val state = viewModel.uiState.value
                if (state.isRecording && state.transcriptionEnabled && error in restartableErrors) {
                  recognizer.cancel()
                  recognizer.startListening(recognitionIntent)
                }
              }

              override fun onResults(results: Bundle?) {
                val text = results
                  ?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)
                  ?.firstOrNull()
                  ?.trim()
                  .orEmpty()
                if (text.isNotBlank()) {
                  viewModel.appendFinalTranscription(text)
                }
                partialTranscription.value = ""
                val state = viewModel.uiState.value
                if (state.isRecording && state.transcriptionEnabled) {
                  recognizer.startListening(recognitionIntent)
                }
              }

              override fun onPartialResults(partialResults: Bundle?) {
                val text = partialResults
                  ?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)
                  ?.firstOrNull()
                  ?.trim()
                  .orEmpty()
                val state = viewModel.uiState.value
                if (state.isRecording && state.transcriptionEnabled) {
                  partialTranscription.value = text
                }
              }

              override fun onEvent(eventType: Int, params: Bundle?) = Unit
            },
          )
        }

        onDispose {
          speechRecognizer?.stopListening()
          speechRecognizer?.cancel()
          speechRecognizer?.destroy()
          recorderController.cancelRecording()
        }
      }

      RecorderTheme(useDarkTheme = isSystemInDarkTheme()) {
        RecorderScreen(
          uiState = uiState,
          partialTranscript = partialTranscription.value,
          hasRecordPermission = hasRecordPermission,
          transcriptionAvailable = hasSpeechRecognizer,
          recordingsDirPath = recordingsDir.absolutePath,
          onRequestPermission = {
            permissionLauncher.launch(Manifest.permission.RECORD_AUDIO)
          },
          onToggleRecording = { enableTranscription ->
            if (!hasRecordPermission) {
              permissionLauncher.launch(Manifest.permission.RECORD_AUDIO)
              return@RecorderScreen
            }

            if (!uiState.isRecording) {
              val audioFile = runCatching { recorderController.startRecording() }
                .onFailure { throwable ->
                  viewModel.abortSession("Could not start recording: ${throwable.message}")
                }
                .getOrNull()

              if (audioFile != null) {
                viewModel.startSession(transcriptionEnabled = enableTranscription)
                partialTranscription.value = ""
                if (enableTranscription) {
                  if (speechRecognizer == null) {
                    viewModel.abortSession("Speech recognition is not supported on this device")
                  } else {
                    speechRecognizer.stopListening()
                    speechRecognizer.cancel()
                    speechRecognizer.startListening(recognitionIntent)
                  }
                }
              }
            } else {
              speechRecognizer?.stopListening()
              speechRecognizer?.cancel()
              val audioFile = recorderController.stopRecording()
              viewModel.finishSession(audioFile)
              partialTranscription.value = ""
            }
          },
        )
      }

      LaunchedEffect(uiState.lastError) {
        val error = uiState.lastError
        if (error != null) {
          // Show a toast for simplicity.
          android.widget.Toast.makeText(context, error, android.widget.Toast.LENGTH_LONG).show()
          viewModel.consumeError()
        }
      }
    }
  }
}

@Composable
private fun RecorderScreen(
  uiState: RecordingUiState,
  partialTranscript: String,
  hasRecordPermission: Boolean,
  transcriptionAvailable: Boolean,
  recordingsDirPath: String,
  onRequestPermission: () -> Unit,
  onToggleRecording: (Boolean) -> Unit,
) {
  var transcriptionEnabled by rememberSaveable { mutableStateOf(transcriptionAvailable) }

  LaunchedEffect(transcriptionAvailable) {
    if (!transcriptionAvailable) {
      transcriptionEnabled = false
    }
  }

  Column(
    modifier = Modifier
      .fillMaxSize()
      .padding(24.dp)
      .verticalScroll(rememberScrollState()),
    verticalArrangement = Arrangement.Top,
  ) {
    Text(
      text = "Recording Studio",
      style = MaterialTheme.typography.headlineMedium,
    )
    Spacer(modifier = Modifier.height(8.dp))
    Text(
      text = "Capture audio clips and optionally auto-generate transcripts. Files are stored under app-specific storage in the recordings folder.",
      style = MaterialTheme.typography.bodyMedium,
    )
    Spacer(modifier = Modifier.height(8.dp))
    Text(
      text = "Storage: ${recordingsDirPath}",
      style = MaterialTheme.typography.bodySmall,
    )
    Spacer(modifier = Modifier.height(24.dp))

    if (!hasRecordPermission) {
      Card(colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.errorContainer)) {
        Column(modifier = Modifier.padding(16.dp)) {
          Text(
            text = "Microphone access is blocked.",
            style = MaterialTheme.typography.bodyLarge,
            color = MaterialTheme.colorScheme.onErrorContainer,
          )
          Spacer(modifier = Modifier.height(8.dp))
          Button(onClick = onRequestPermission) {
            Text("Grant Permission")
          }
        }
      }
      Spacer(modifier = Modifier.height(16.dp))
    }

    Row(
      modifier = Modifier.fillMaxWidth(),
      horizontalArrangement = Arrangement.SpaceBetween,
      verticalAlignment = Alignment.CenterVertically,
    ) {
      Text("Transcription", style = MaterialTheme.typography.titleMedium)
      Switch(
        checked = transcriptionEnabled && transcriptionAvailable,
        onCheckedChange = { checked ->
          transcriptionEnabled = checked
        },
        colors = SwitchDefaults.colors(checkedThumbColor = MaterialTheme.colorScheme.primary),
        enabled = transcriptionAvailable,
      )
    }

    if (!transcriptionAvailable) {
      Text(
        text = "Speech recognition services are not available on this device.",
        style = MaterialTheme.typography.bodySmall,
        color = MaterialTheme.colorScheme.error,
      )
    }

    Spacer(modifier = Modifier.height(24.dp))

    Button(
      onClick = { onToggleRecording(transcriptionEnabled && transcriptionAvailable) },
      modifier = Modifier.fillMaxWidth(),
    ) {
      Text(if (uiState.isRecording) "Stop Recording" else "Start Recording")
    }

    Spacer(modifier = Modifier.height(24.dp))

    Card {
      Column(modifier = Modifier.padding(16.dp)) {
        Text("Live transcription", style = MaterialTheme.typography.titleMedium)
        Spacer(modifier = Modifier.height(8.dp))
        val liveText = buildString {
          if (uiState.liveTranscription.isNotBlank()) {
            append(uiState.liveTranscription)
          }
          if (partialTranscript.isNotBlank()) {
            if (isNotEmpty()) append('\n')
            append("...")
            append(partialTranscript)
          }
        }
        Text(
          text = if (liveText.isBlank()) "No transcript yet." else liveText,
          style = MaterialTheme.typography.bodyMedium,
        )
      }
    }

    Spacer(modifier = Modifier.height(24.dp))

    if (uiState.lastSavedRecording != null) {
      Text("Latest capture", style = MaterialTheme.typography.titleMedium)
      Spacer(modifier = Modifier.height(8.dp))
      SavedRecordingCard(uiState.lastSavedRecording!!)
      Spacer(modifier = Modifier.height(24.dp))
    }

    Text("History", style = MaterialTheme.typography.titleMedium)
    Spacer(modifier = Modifier.height(8.dp))
    if (uiState.completedRecordings.isEmpty()) {
      Text("No recordings yet.", style = MaterialTheme.typography.bodyMedium)
    } else {
      uiState.completedRecordings.forEach { recording ->
        SavedRecordingCard(recording)
        Spacer(modifier = Modifier.height(12.dp))
      }
    }
  }
}

@Composable
private fun SavedRecordingCard(recording: CompletedRecording) {
  Card(modifier = Modifier.fillMaxWidth()) {
    Column(modifier = Modifier.padding(16.dp)) {
      Text(
        text = "Audio: ${recording.audioPath}",
        style = MaterialTheme.typography.bodyMedium,
      )
      if (recording.transcriptionPath != null) {
        Spacer(modifier = Modifier.height(4.dp))
        Text(
          text = "Transcript: ${recording.transcriptionPath}",
          style = MaterialTheme.typography.bodyMedium,
        )
        if (recording.transcriptPreview.isNotBlank()) {
          Spacer(modifier = Modifier.height(8.dp))
          Text(
            text = recording.transcriptPreview,
            style = MaterialTheme.typography.bodySmall,
          )
        }
      } else {
        Spacer(modifier = Modifier.height(4.dp))
        Text(
          text = "Transcription disabled for this session.",
          style = MaterialTheme.typography.bodySmall,
        )
      }
    }
  }
}

private val restartableErrors = setOf(
  SpeechRecognizer.ERROR_NO_MATCH,
  SpeechRecognizer.ERROR_SPEECH_TIMEOUT,
)

private fun speechErrorMessage(code: Int): String = when (code) {
  SpeechRecognizer.ERROR_AUDIO -> "Audio recording issue"
  SpeechRecognizer.ERROR_CLIENT -> "Client error"
  SpeechRecognizer.ERROR_INSUFFICIENT_PERMISSIONS -> "Permission denied"
  SpeechRecognizer.ERROR_NETWORK -> "Network error"
  SpeechRecognizer.ERROR_NETWORK_TIMEOUT -> "Network timeout"
  SpeechRecognizer.ERROR_NO_MATCH -> "No speech recognised"
  SpeechRecognizer.ERROR_RECOGNIZER_BUSY -> "Recognizer busy"
  SpeechRecognizer.ERROR_SERVER -> "Server error"
  SpeechRecognizer.ERROR_SPEECH_TIMEOUT -> "Speech timeout"
  else -> "Unknown error ($code)"
}
