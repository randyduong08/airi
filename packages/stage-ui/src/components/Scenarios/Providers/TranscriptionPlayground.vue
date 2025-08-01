<script setup lang="ts">
import type { GenerateTranscriptionResult } from '@xsai/generate-transcription'

import { FieldRange, FieldSelect } from '@proj-airi/ui'
import { until } from '@vueuse/core'
import { computed, onUnmounted, ref, watch } from 'vue'
import { useI18n } from 'vue-i18n'

import { useAudioRecorder } from '../../../composables/audio/audio-recorder'
import { useAudioDevice } from '../../../composables/audio/device'
import { LevelMeter, TestDummyMarker, ThresholdMeter } from '../../Gadgets'
import { Button } from '../../Misc'

const props = defineProps<{
  // Provider-specific handlers (provided from parent)
  generateTranscription: (input: File) => Promise<GenerateTranscriptionResult<'json' | 'verbose_json', undefined>>
  // Current state
  apiKeyConfigured?: boolean
}>()

const { t } = useI18n()
const { audioInputs, selectedAudioInput, stream, stopStream, startStream } = useAudioDevice()

const speakingThreshold = ref(25) // 0-100 (for volume-based fallback)
const isMonitoring = ref(false)
const isSpeaking = ref(false)

const errorMessage = ref<string>('')

const audioContext = ref<AudioContext>()
const analyser = ref<AnalyserNode>()
const dataArray = ref<Uint8Array>()
const animationFrame = ref<number>()
const volumeLevel = ref(0) // 0-100

const audios = ref<Blob[]>([])
const audioCleanups = ref<(() => void)[]>([])
const audioURLs = computed(() => {
  return audios.value.map((blob) => {
    const url = URL.createObjectURL(blob)
    audioCleanups.value.push(() => URL.revokeObjectURL(url))
    return url
  })
})
const transcriptions = ref<string[]>([])

const { startRecord, stopRecord, onStopRecord } = useAudioRecorder(stream)

// Audio monitoring
async function setupAudioMonitoring() {
  try {
    // Clean up existing connections
    await stopAudioMonitoring()

    await startStream()
    await until(stream).toBeTruthy()

    // Create audio context
    audioContext.value = new AudioContext()
    const source = audioContext.value.createMediaStreamSource(stream.value!)

    // Create analyser for volume detection
    analyser.value = audioContext.value.createAnalyser()
    analyser.value.fftSize = 256
    analyser.value.smoothingTimeConstant = 0.3

    // Connect audio graph
    source.connect(analyser.value)

    // Set up data array for analysis
    const bufferLength = analyser.value.frequencyBinCount
    dataArray.value = new Uint8Array(bufferLength)

    // Start audio analysis loop
    startAudioAnalysis()
  }
  catch (error) {
    console.error('Error setting up audio monitoring:', error)
    errorMessage.value = error instanceof Error ? error.message : String(error)
  }
}

async function stopAudioMonitoring() {
  // Stop animation frame
  if (animationFrame.value) {
    cancelAnimationFrame(animationFrame.value)
    animationFrame.value = undefined
  }

  // Stop media stream
  if (stream.value) {
    stream.value.getTracks().forEach(track => track.stop())
    stream.value = undefined
  }

  // Close audio context
  if (audioContext.value) {
    await audioContext.value.close()
    audioContext.value = undefined
  }

  await stopRecord()
  await stopStream()

  analyser.value = undefined
  dataArray.value = undefined
  volumeLevel.value = 0
  isSpeaking.value = false
}

function startAudioAnalysis() {
  const analyze = () => {
    if (!analyser.value || !dataArray.value)
      return

    // Get frequency data for volume visualization
    analyser.value.getByteFrequencyData(dataArray.value)

    // Calculate RMS volume level
    let sum = 0
    for (let i = 0; i < dataArray.value.length; i++) {
      sum += dataArray.value[i] * dataArray.value[i]
    }
    const rms = Math.sqrt(sum / dataArray.value.length)
    volumeLevel.value = Math.min(100, (rms / 255) * 100 * 3) // Amplify for better visualization

    isSpeaking.value = volumeLevel.value > speakingThreshold.value

    animationFrame.value = requestAnimationFrame(analyze)
  }

  analyze()
}

watch(selectedAudioInput, async () => {
  if (isMonitoring.value) {
    await setupAudioMonitoring()
  }
})

watch(audioInputs, () => {
  if (!selectedAudioInput.value && audioInputs.value.length > 0) {
    selectedAudioInput.value = audioInputs.value.find(input => input.deviceId === 'default')?.deviceId || audioInputs.value[0].deviceId
  }
})

// Monitoring toggle
async function toggleMonitoring() {
  if (!isMonitoring.value) {
    onStopRecord(async (recording) => {
      try {
        if (recording && recording.size > 0) {
          audios.value.push(recording)
          const res = await props.generateTranscription(new File([recording], 'recording.wav'))
          transcriptions.value.push(res.text)
        }
      }
      catch (err) {
        errorMessage.value = err instanceof Error ? err.message : String(err)
        console.error('Error generating transcription:', errorMessage.value)
      }
    })

    await setupAudioMonitoring()
    await startRecord()
    isMonitoring.value = true
  }
  else {
    await stopAudioMonitoring()
    await stopRecord()

    isMonitoring.value = false
  }
}

// Speaking indicator with enhanced VAD visualization
const speakingIndicatorClass = computed(() => {
  // Volume-based: simple green/white
  return isSpeaking.value
    ? 'bg-green-500 shadow-lg shadow-green-500/50'
    : 'bg-white dark:bg-neutral-900 border-2 border-neutral-300 dark:border-neutral-600'
})

onUnmounted(() => {
  stopAudioMonitoring()
})
</script>

<template>
  <div w-full pt-1>
    <h2 class="mb-4 text-lg text-neutral-500 md:text-2xl dark:text-neutral-400" w-full>
      <div class="inline-flex items-center gap-4">
        <TestDummyMarker />
        <div>
          {{ t('settings.pages.providers.provider.transcriptions.playground.title') }}
        </div>
      </div>
    </h2>

    <!-- Audio Input Selection -->
    <div mb-2>
      <FieldSelect
        v-model="selectedAudioInput"
        label="Audio Input Device"
        description="Select the audio input device for your hearing module."
        :options="audioInputs.map(input => ({
          label: input.label || input.deviceId,
          value: input.deviceId,
        }))"
        placeholder="Select an audio input device"
        layout="vertical"
        h-fit w-full
      />
    </div>

    <Button class="my-4" w-full @click="toggleMonitoring">
      {{ isMonitoring ? 'Stop Monitoring' : 'Start Monitoring' }}
    </Button>

    <div>
      <div v-for="(audio, index) in audioURLs" :key="index" class="mb-2">
        <audio :src="audio" controls class="w-full" />
        <div v-if="transcriptions[index]" class="mt-2 text-sm text-neutral-500 dark:text-neutral-400">
          {{ transcriptions[index] }}
        </div>
      </div>
    </div>

    <!-- Audio Level Visualization -->
    <div class="space-y-3">
      <!-- Volume Meter -->
      <LevelMeter :level="volumeLevel" label="Input Level" />

      <!-- VAD Probability Meter (when VAD model is active) -->
      <ThresholdMeter
        :value="volumeLevel / 100"
        :threshold="speakingThreshold / 100"
        label="Probability of Speech"
        below-label="Silence"
        above-label="Speech"
        threshold-label="Detection threshold"
      />

      <div class="space-y-3">
        <FieldRange
          v-model="speakingThreshold"
          label="Sensitivity"
          description="Adjust the threshold for speech detection"
          :min="1"
          :max="80"
          :step="1"
          :format-value="value => `${value}%`"
        />
      </div>

      <!-- Speaking Indicator -->
      <div class="flex items-center gap-3">
        <div
          class="h-4 w-4 rounded-full transition-all duration-200"
          :class="speakingIndicatorClass"
        />
        <span class="text-sm font-medium">
          {{ isSpeaking ? 'Speaking Detected' : 'Silence' }}
        </span>
      </div>
    </div>
  </div>
</template>
