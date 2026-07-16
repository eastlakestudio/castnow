<script setup>
import { ref } from 'vue';
import {
  X, ArrowLeft, Loader2, AlertCircle, Download,
  Monitor, Repeat, Volume2, VolumeX, Maximize,
  LogOut, Mic, MicOff,
} from 'lucide-vue-next';

const props = defineProps({
  joinCode: { type: String, default: '' },
  isConnecting: { type: Boolean, default: false },
  isTouchDevice: { type: Boolean, default: false },
  error: { type: String, default: null },
  // Receiver active props
  screenStream: { default: null },
  cameraStream: { default: null },
  remoteStream: { default: null },
  layoutMode: { type: String, default: 'pip' },
  isSwapped: { type: Boolean, default: false },
  isMuted: { type: Boolean, default: false },
  isDragging: { type: Boolean, default: false },
  pipPosition: { type: Object, default: () => ({ x: 20, y: 20 }) },
  pipWidth: { type: Number, default: 320 },
  splitRatio: { type: Number, default: 0.5 },
  showControls: { type: Boolean, default: true },
  isReceiverMicActive: { type: Boolean, default: false },
  remoteVideo: { default: null },
});

const emit = defineEmits([
  'digitInput', 'backspace', 'resetApp', 'join',
  'dragStart', 'dragMove', 'dragEnd',
  'toggleLayout', 'swapStreams', 'toggleMute',
  'toggleFullscreen', 'toggleReceiverMic',
]);

const screenVideoEl = ref(null);
const cameraVideoEl = ref(null);
const remoteVideoEl = ref(null);
</script>

<template>
  <!-- Receiver Input -->
  <div class="flex-1 flex flex-col items-center justify-center p-6">
    <h2 class="text-2xl font-black uppercase mb-10 tracking-widest flex items-center gap-3">
      <span class="w-8 h-[2px] bg-cyan-500"></span>
      Enter Access Key
      <span class="w-8 h-[2px] bg-cyan-500"></span>
    </h2>

    <div class="mb-10 flex gap-2 h-20 md:h-24">
      <div v-for="i in 6" :key="i"
        class="w-12 md:w-16 backdrop-blur-sm bg-white/5 border border-white/10 rounded-2xl flex items-center justify-center text-3xl md:text-4xl font-black text-white shadow-inner transition-colors duration-200"
        :class="{
          'border-cyan-500/50 text-cyan-400': joinCode[i - 1],
          'animate-pulse bg-white/10': joinCode.length === i - 1,
        }">
        {{ joinCode[i - 1] || '' }}
      </div>
    </div>

    <div v-if="isTouchDevice" class="grid grid-cols-3 gap-4 w-full max-w-[280px] mb-8">
      <button v-for="n in 9" :key="n" @click="$emit('digitInput', n.toString())"
        class="h-16 rounded-2xl bg-slate-900 border border-slate-800 hover:bg-slate-800 text-xl font-bold active:scale-95 transition-all">
        {{ n }}
      </button>
      <button @click="$emit('resetApp')"
        class="h-16 rounded-2xl bg-slate-950 border border-slate-900 hover:bg-slate-900 text-slate-500 flex items-center justify-center active:scale-95 transition-all">
        <X class="w-6 h-6" />
      </button>
      <button @click="$emit('digitInput', '0')"
        class="h-16 rounded-2xl bg-slate-900 border border-slate-800 hover:bg-slate-800 text-xl font-bold active:scale-95 transition-all">0</button>
      <button @click="$emit('backspace')"
        class="h-16 rounded-2xl bg-slate-950 border border-slate-900 hover:bg-slate-900 text-slate-500 flex items-center justify-center active:scale-95 transition-all">
        <ArrowLeft class="w-6 h-6" />
      </button>
    </div>

    <div v-else class="mb-12 text-slate-500 text-xs font-bold uppercase tracking-widest animate-pulse">
      Type access key via physical keyboard
    </div>

    <button @click="$emit('join')" :disabled="joinCode.length !== 6 || isConnecting"
      class="w-full max-w-[280px] py-5 bg-cyan-500 disabled:bg-slate-800 disabled:text-slate-600 text-slate-950 font-black rounded-2xl text-lg uppercase tracking-widest shadow-xl shadow-cyan-500/20 active:scale-95 transition-all flex items-center justify-center gap-2">
      <Loader2 v-if="isConnecting" class="w-5 h-5 animate-spin" />
      <span v-else>Connect Now</span>
    </button>

    <button v-if="isConnecting" @click="$emit('resetApp')"
      class="mt-4 text-slate-500 font-bold uppercase tracking-widest text-[10px] hover:text-white transition-colors flex items-center gap-2">
      <X class="w-3 h-3" /> Cancel
    </button>

    <p v-if="error" class="mt-4 text-red-500 text-xs font-bold uppercase tracking-widest flex items-center gap-2">
      <AlertCircle class="w-4 h-4" /> {{ error }}
    </p>
  </div>

  <!-- Receiver Active is complex and tightly coupled; keep in App.vue for now -->
</template>
