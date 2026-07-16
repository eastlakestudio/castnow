<script setup>
import { ref, watch, nextTick, computed, onMounted, onUnmounted } from 'vue';
import { inject as injectAnalytics } from '@vercel/analytics';
import {
  Monitor, Repeat, Info, Globe, Volume2, VolumeX, Maximize,
  Zap, Shield, Mic, MicOff, LogOut, CheckCircle2, AlertCircle,
} from 'lucide-vue-next';
import { useMediaStream } from './composables/useMediaStream';
import { useWebRTC } from './composables/useWebRTC';
import { useLayout } from './composables/useLayout';
import SenderView from './components/SenderView.vue';
import ReceiverView from './components/ReceiverView.vue';
import InfoModal from './components/InfoModal.vue';
import LandingView from './components/LandingView.vue';
import SourceSelectView from './components/SourceSelectView.vue';

const STATES = {
  LANDING: 'LANDING',
  SOURCE_SELECT: 'SOURCE_SELECT',
  SENDER: 'SENDER',
  RECEIVER_INPUT: 'RECEIVER_INPUT',
  RECEIVER_ACTIVE: 'RECEIVER_ACTIVE',
  BROADCAST_ENDED: 'BROADCAST_ENDED',
};

// --- App-level state ---
const appState = ref(STATES.LANDING);
const showInfo = ref(null);
const showFirefoxGuide = ref(false);
const showProModal = ref(false);
const activationCode = ref('');
const activeCode = ref('');
const proExpiresAt = ref(null);
const toast = ref({ show: false, message: '', type: 'info' });
const showEndedDialog = ref(false);
const showControls = ref(true);
let controlsTimeout = null;
let toastTimeout = null;

// --- Composables ---
const media = useMediaStream();
const layout = useLayout();
const webrtc = useWebRTC(media.getIceServers);

// --- Destructure for template compatibility ---
const {
  castingMode, facingMode, localStream, localVideo,
  localScreenStream, localCameraStream, localScreenVideo, localCameraVideo,
  isMicMuted, selectedSources, videoDevices, hasMultipleCameras,
} = media;

const {
  peerId, peerInstance, isConnecting, error, lastReceiverInfo,
  joinCode, remoteStream, screenStream, cameraStream,
  screenVideo, cameraVideo, remoteVideo,
  isReceiverMicActive, receiverMicStream, receiverAudioStream,
  receiverAudioElement, activeReceiverCall,
} = webrtc;

const {
  layoutMode, isSwapped, pipPosition, pipWidth, splitRatio,
  dragType, isDragging, isMuted, isTouchDevice, isMobile,
} = layout;

const receiverRoot = ref(null);
const remoteDeviceInfo = ref('');

// --- Toast ---
const showToast = (message, type = 'info', duration = 3000) => {
  if (toastTimeout) clearTimeout(toastTimeout);
  toast.value = { show: true, message, type };
  toastTimeout = setTimeout(() => { toast.value.show = false; }, duration);
};

// --- Sender: Start Casting ---
const handleStartCasting = async () => {
  try {
    isConnecting.value = true;
    error.value = null;

    if (!window.isSecureContext && /iPad|iPhone|iPod/.test(navigator.userAgent)) {
      showToast('HTTPS is required for camera/mic on iPad/Mobile Safari. Please use a secure connection.', 'error', 8000);
      isConnecting.value = false;
      return;
    }

    if (selectedSources.value.includes('screen')) {
      if (!navigator.mediaDevices || !navigator.mediaDevices.getDisplayMedia) {
        showToast('Screen sharing not supported on this device.', 'error', 5000);
        isConnecting.value = false;
        return;
      }
    }

    const combinedStream = await media.captureMediaStreams();
    localStream.value = combinedStream;
    appState.value = STATES.SENDER;

    webrtc.startSenderPeer(
      Math.floor(100000 + Math.random() * 900000).toString(),
      localStream,
      showFirefoxGuide,
      showToast,
      (s) => { appState.value = s; },
      STATES,
    );

    // Bind screen share ended callback
    if (localScreenStream.value) {
      const videoTrack = localScreenStream.value.getVideoTracks()[0];
      if (videoTrack) videoTrack.onended = () => resetApp();
    }
  } catch (err) {
    console.error(err);
    if (err.name === 'NotAllowedError') {
      error.value = null;
    } else if (err.message === 'screen_share_unsupported') {
      // Already handled
    } else {
      error.value = 'Device access denied or not supported.';
    }
    isConnecting.value = false;
  }
};

// --- Receiver: Join ---
const handleJoin = async () => {
  if (joinCode.value.length !== 6) return;
  isConnecting.value = true;
  error.value = null;

  try {
    const audioStream = await navigator.mediaDevices.getUserMedia({ audio: true });
    audioStream.getAudioTracks().forEach(t => t.enabled = false);
    receiverMicStream.value = audioStream;
    isReceiverMicActive.value = false;
  } catch (err) {
    console.warn('Could not pre-allocate receiver microphone', err);
  }

  webrtc.startReceiverPeer(
    joinCode.value,
    (s) => { appState.value = s; },
    STATES,
    showToast,
  );
};

// --- Shared ---
const resetApp = (forceLanding = false) => {
  media.stopAllStreams();
  webrtc.cleanUpStreams();
  webrtc.closeActiveCalls();
  webrtc.destroyPeer();
  webrtc.persistTrial();
  media.resetMediaState();
  webrtc.resetState();

  if (forceLanding || appState.value !== STATES.BROADCAST_ENDED) {
    appState.value = STATES.LANDING;
  }
};

// --- Keyboard ---
const handleDigitInput = (digit) => {
  if (joinCode.value.length < 6) joinCode.value += digit;
};
const handleBackspace = () => { joinCode.value = joinCode.value.slice(0, -1); };

const handleKeyDown = (e) => {
  if (appState.value !== STATES.RECEIVER_INPUT || isConnecting.value) return;
  if (/^[0-9]$/.test(e.key)) handleDigitInput(e.key);
  else if (e.key === 'Backspace') handleBackspace();
  else if (e.key === 'Enter') handleJoin();
  else if (e.key === 'Escape') resetApp();
};

onMounted(async () => {
  window.addEventListener('keydown', handleKeyDown);
  await media.enumerateDevices();
});

onUnmounted(() => {
  window.removeEventListener('keydown', handleKeyDown);
});

// --- Toggle functions (delegate to composables) ---
const toggleMic = () => media.toggleMic();
const toggleCamera = async () => {
  const result = await media.toggleCamera();
  if (result.switched) {
    showToast('Camera lens switched', 'success');
  } else if (result.error) {
    showToast('Camera switch failed', 'error');
  }
};
const toggleReceiverMic = async () => {
  await webrtc.toggleReceiverMic(showToast);
};

// Toggle mute for playback
const toggleMute = () => layout.toggleMute();
const toggleLayout = () => layout.toggleLayout();
const swapStreams = () => layout.swapStreams();
const toggleFullscreen = () => layout.toggleFullscreen(receiverRoot.value);
</script>

<template>
  <div class="min-h-[100dvh] flex flex-col bg-slate-950 text-slate-50 font-sans selection:bg-amber-500/30">
    <header v-if="appState !== STATES.RECEIVER_ACTIVE"
      class="flex items-center justify-between px-6 py-4 border-b border-slate-800/50 backdrop-blur-md sticky top-0 z-50">
      <div class="flex items-center gap-3 cursor-pointer group" @click="resetApp">
        <img src="/icon.svg" alt="CastNow"
          class="w-10 h-10 rounded-xl shadow-lg shadow-amber-500/10 group-hover:scale-105 transition-transform duration-300" />
        <span class="bg-gradient-to-r from-slate-100 to-slate-400 bg-clip-text text-xl font-black italic uppercase tracking-tight text-transparent pr-1">CastNow</span>
      </div>
      <div class="flex items-center gap-4">
        <button @click="showInfo = 'source'"
          class="flex items-center gap-2 px-4 py-2 bg-slate-900 border border-slate-800 rounded-xl hover:border-slate-600 transition-all group">
          <Globe class="w-4 h-4 text-slate-500 group-hover:text-amber-500 transition-colors" />
          <span class="text-[10px] font-black uppercase tracking-widest text-slate-400 group-hover:text-white transition-colors">Source</span>
        </button>
      </div>
    </header>

    <!-- Firefox Privacy Guide Overlay -->
    <div v-if="showFirefoxGuide"
      class="fixed inset-0 z-[100] bg-slate-950/90 backdrop-blur-xl flex flex-col items-center justify-center p-6 text-center">
      <div class="bg-slate-900 border border-slate-800 p-8 rounded-[3rem] max-w-md w-full shadow-2xl relative overflow-hidden">
        <div class="absolute top-0 left-1/2 -translate-x-1/2 w-32 h-1 bg-amber-500 blur-sm"></div>
        <div class="w-20 h-20 bg-amber-500/10 rounded-full flex items-center justify-center mx-auto mb-6">
          <Shield class="w-10 h-10 text-amber-500" />
        </div>
        <h3 class="text-2xl font-black uppercase mb-4 text-white">Firefox Detected</h3>
        <p class="text-slate-400 text-sm mb-6 leading-relaxed">Firefox's "Enhanced Tracking Protection" is blocking the P2P connection.</p>
        <div class="bg-black/50 rounded-xl p-4 mb-8 border border-white/5 text-left text-xs text-slate-300 space-y-3">
          <div class="flex items-center gap-3">
            <div class="w-6 h-6 flex items-center justify-center bg-slate-800 rounded-full font-bold text-amber-500">1</div>
            <span>Click the Shield Icon 🛡️ in the URL bar.</span>
          </div>
          <div class="flex items-center gap-3">
            <div class="w-6 h-6 flex items-center justify-center bg-slate-800 rounded-full font-bold text-amber-500">2</div>
            <span>Toggle the switch to OFF.</span>
          </div>
        </div>
        <button @click="() => { showFirefoxGuide = false; window.location.reload(); }"
          class="w-full py-4 bg-amber-500 hover:bg-amber-400 text-slate-950 font-black rounded-xl uppercase tracking-widest transition-all active:scale-95">
          I've Fixed It · Retry
        </button>
      </div>
    </div>

    <main class="flex-1 flex flex-col relative overflow-hidden">
      <Transition name="fade" mode="out-in">
        <!-- Landing -->
        <LandingView v-if="appState === STATES.LANDING"
          @navigate="(s) => appState = s"
          @showInfo="(info) => showInfo = info" />

        <!-- Source Selection -->
        <SourceSelectView v-else-if="appState === STATES.SOURCE_SELECT"
          :selectedSources="selectedSources"
          @toggleSource="media.toggleSource"
          @startBroadcast="handleStartCasting"
          @navigate="(s) => appState = s" />

        <!-- Sender View -->
        <SenderView v-else-if="appState === STATES.SENDER"
          :peerId="peerId"
          :isMicMuted="isMicMuted"
          :facingMode="facingMode"
          :selectedSources="selectedSources"
          :hasMultipleCameras="hasMultipleCameras"
          :localScreenStream="localScreenStream"
          :localCameraStream="localCameraStream"
          :localVideo="localVideo"
          :lastReceiverInfo="lastReceiverInfo"
          @toggleMic="toggleMic"
          @toggleCamera="toggleCamera"
          @resetApp="resetApp" />

        <!-- Receiver Input -->
        <ReceiverView v-else-if="appState === STATES.RECEIVER_INPUT"
          :joinCode="joinCode"
          :isConnecting="isConnecting"
          :isTouchDevice="isTouchDevice"
          :error="error"
          @digitInput="handleDigitInput"
          @backspace="handleBackspace"
          @resetApp="resetApp"
          @join="handleJoin" />

        <!-- Broadcast Ended -->
        <div v-else-if="appState === STATES.BROADCAST_ENDED"
          class="flex-1 flex items-center justify-center p-6 bg-slate-950">
          <div class="w-full max-w-sm bg-slate-900 border border-slate-800 rounded-[3rem] p-10 text-center shadow-2xl">
            <div class="w-24 h-24 bg-amber-500/10 rounded-full flex items-center justify-center mx-auto mb-8 animate-bounce">
              <Info class="w-12 h-12 text-amber-500" />
            </div>
            <h3 class="text-3xl font-black uppercase mb-4 tracking-tight text-white">Broadcast Ended</h3>
            <p class="text-slate-400 text-base mb-10 font-medium">The session has been terminated by the broadcaster.</p>
            <button @click="resetApp(true)"
              class="w-full py-6 bg-amber-500 text-slate-950 font-black rounded-2xl uppercase tracking-widest text-sm active:scale-95 transition-all shadow-xl shadow-amber-500/20">
              Back to Home
            </button>
          </div>
        </div>

        <!-- Receiver Active (kept inline due to complex drag/PiP interactions) -->
        <div v-else-if="appState === STATES.RECEIVER_ACTIVE"
          ref="receiverRoot"
          class="fixed inset-0 bg-black flex items-center justify-center overflow-hidden"
          @mousemove="layout.handleDragMove"
          @mouseup="layout.handleDragEnd"
          @touchstart="layout.handleDragStart($event, 'move-pip')"
          @touchmove.prevent="layout.handleDragMove"
          @touchend="layout.handleDragEnd">

          <div :class="['relative w-full h-full flex ease-in-out',
                        layoutMode === 'side-by-side' ? 'p-2 gap-0' : '',
                        isDragging ? 'no-transition' : 'transition-all duration-500']">

            <div v-if="cameraStream && screenStream"
                 :class="['relative overflow-hidden bg-slate-900 flex items-center justify-center',
                          layoutMode === 'pip' ? 'w-full h-full' : 'rounded-2xl',
                          isDragging ? 'no-transition' : 'transition-all duration-500']"
                 :style="layoutMode === 'side-by-side' ? { width: (splitRatio * 100) + '%' } : (layoutMode === 'pip' && isSwapped ? 'order: 2' : '')">
              <video ref="screenVideo" autoplay playsinline :muted="isMuted" class="max-w-full max-h-full object-contain" />
              <div v-if="layoutMode === 'side-by-side'" class="absolute bottom-4 left-4 bg-black/50 backdrop-blur-sm px-2 py-1 rounded-lg text-[10px] font-bold text-white uppercase tracking-widest">{{ isSwapped ? 'Camera' : 'Screen' }}</div>
            </div>

            <div v-if="layoutMode === 'side-by-side' && cameraStream && screenStream"
                 @mousedown="layout.handleDragStart($event, 'splitter')"
                 @touchstart.passive="layout.handleDragStart($event, 'splitter')"
                 class="w-2 hover:w-4 -mx-1 hover:-mx-2 z-30 cursor-col-resize flex items-center justify-center transition-all group">
              <div class="h-12 w-1 bg-white/20 rounded-full group-hover:bg-amber-500 transition-colors"></div>
            </div>

            <div v-if="cameraStream && screenStream"
                 :class="['overflow-hidden shadow-2xl group flex items-center justify-center',
                          isDragging ? 'no-transition' : 'transition-all duration-500',
                          layoutMode === 'pip' ? 'absolute rounded-xl border border-white/20 cursor-move z-20 hover:border-amber-500/50' : 'relative rounded-2xl bg-slate-900']"
                 :style="layoutMode === 'pip' ? { left: pipPosition.x + 'px', top: pipPosition.y + 'px', width: pipWidth + 'px', height: 'auto', order: isSwapped ? 1 : 2, transition: isDragging ? 'none' : 'all 0.5s ease-in-out' } : { width: ((1 - splitRatio) * 100) + '%' }"
                 @mousedown="layout.handleDragStart($event, 'move-pip')"
                 @touchstart="layout.handleDragStart($event, 'move-pip')">
              <video ref="cameraVideo" autoplay playsinline :muted="isMuted" class="max-w-full max-h-full object-contain pointer-events-none" />
              <div v-if="layoutMode === 'side-by-side'" class="absolute bottom-4 left-4 bg-black/50 backdrop-blur-sm px-2 py-1 rounded-lg text-[10px] font-bold text-white uppercase tracking-widest">{{ isSwapped ? 'Screen' : 'Camera' }}</div>
              <div v-if="layoutMode === 'pip'" @mousedown.stop="layout.handleDragStart($event, 'resize-pip')"
                   class="absolute bottom-0 right-0 w-8 h-8 cursor-nwse-resize flex items-end justify-end p-1 group/resize">
                <div class="w-4 h-4 text-white/40 group-hover/resize:text-amber-500 transition-colors">
                  <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="3" stroke-linecap="round" stroke-linejoin="round"><path d="M15 19l4-4M10 19l9-9"/></svg>
                </div>
              </div>
              <div v-if="layoutMode === 'pip'" class="absolute top-2 right-2 p-1 bg-black/40 rounded-full opacity-0 group-hover:opacity-100 transition-opacity">
                <Maximize class="w-3 h-3 text-white" />
              </div>
            </div>

            <video v-if="!cameraStream || !screenStream" ref="remoteVideo" autoplay playsinline :muted="isMuted" class="w-full h-full object-contain" />
          </div>

          <div class="absolute bottom-0 left-0 w-full h-48 z-40 group/controls"
               @mouseenter="showControls = true"
               @mouseleave="showControls = false">
            <Transition name="fade">
              <div v-if="showControls"
                class="absolute bottom-10 left-1/2 -translate-x-1/2 flex items-center gap-6 z-50 p-3 bg-black/60 backdrop-blur-2xl rounded-[2.5rem] border border-white/10 shadow-2xl pointer-events-auto">
                <button @click="resetApp"
                  class="flex items-center gap-2 px-5 py-3 bg-red-500 text-white rounded-full hover:bg-red-600 transition-all font-black text-xs uppercase tracking-widest active:scale-95">
                  <LogOut class="w-4 h-4" /> Leave
                </button>
                <div class="w-px h-8 bg-white/10"></div>
                <div class="flex items-center gap-2">
                  <template v-if="cameraStream && screenStream">
                    <button @click="toggleLayout" title="Toggle Layout"
                      class="p-4 bg-white/5 rounded-full text-white hover:bg-amber-500 hover:text-slate-950 transition-all active:scale-95 group">
                      <Monitor v-if="layoutMode === 'pip'" class="w-6 h-6" />
                      <div v-else class="flex gap-0.5"><div class="w-2.5 h-4 bg-current rounded-sm"></div><div class="w-2.5 h-4 bg-current rounded-sm"></div></div>
                    </button>
                    <button @click="swapStreams" title="Swap Streams"
                      class="p-4 bg-white/5 rounded-full text-white hover:bg-amber-500 hover:text-slate-950 transition-all active:scale-95">
                      <Repeat class="w-6 h-6" />
                    </button>
                  </template>
                  <button @click="toggleMute"
                    class="p-4 bg-white/5 rounded-full text-white hover:bg-white/10 transition-all active:scale-95"
                    :class="{ 'bg-red-500/20 text-red-500': isMuted }">
                    <component :is="isMuted ? VolumeX : Volume2" class="w-6 h-6" />
                  </button>
                  <button @click="toggleFullscreen"
                    class="p-4 bg-white/5 rounded-full text-white hover:bg-white/10 transition-all active:scale-95">
                    <Maximize class="w-6 h-6" />
                  </button>
                  <div class="w-px h-8 bg-white/10 mx-2"></div>
                  <button @click="toggleReceiverMic"
                    class="p-4 rounded-full transition-all active:scale-95 flex items-center gap-2 group"
                    :class="isReceiverMicActive ? 'bg-amber-500 text-slate-950' : 'bg-white/5 text-white hover:bg-white/10'">
                    <Mic v-if="isReceiverMicActive" class="w-6 h-6" />
                    <MicOff v-else class="w-6 h-6 opacity-60" />
                    <span v-if="isReceiverMicActive" class="text-[10px] font-black uppercase pr-2">Microphone</span>
                  </button>
                </div>
              </div>
            </Transition>
          </div>
        </div>
      </Transition>

      <audio ref="receiverAudioElement" autoplay playsinline webkit-playsinline class="opacity-0 pointer-events-none absolute h-0 w-0"></audio>
    </main>

    <!-- Info Modal -->
    <InfoModal :visible="showInfo" @close="showInfo = null" />

    <!-- Toast -->
    <Transition name="fade">
      <div v-if="toast.show"
        class="fixed bottom-10 left-1/2 -translate-x-1/2 z-[200] px-6 py-3 rounded-2xl shadow-2xl backdrop-blur-md border animate-in slide-in-from-bottom-5 duration-300"
        :class="{ 'bg-amber-500/90 text-slate-950 border-amber-400': toast.type === 'success', 'bg-red-500/90 text-white border-red-400': toast.type === 'error', 'bg-slate-800/90 text-white border-slate-700': toast.type === 'info' }">
        <div class="flex items-center gap-3">
          <Zap v-if="toast.type === 'success'" class="w-4 h-4 fill-current" />
          <AlertCircle v-else-if="toast.type === 'error'" class="w-4 h-4" />
          <Info v-else class="w-4 h-4" />
          <span class="font-bold text-sm tracking-tight">{{ toast.message }}</span>
        </div>
      </div>
    </Transition>
  </div>
</template>

<style scoped>
.fade-enter-active, .fade-leave-active { transition: all 0.4s cubic-bezier(0.4, 0, 0.2, 1); }
.fade-enter-from { opacity: 0; transform: translateY(10px); }
.fade-leave-to { opacity: 0; transform: translateY(-10px); }
.grid { transition: all 0.5s cubic-bezier(0.16, 1, 0.3, 1); }
video { transition: opacity 0.5s; }
.no-transition, .no-transition * { transition: none !important; }
.grid { transition: filter 0.3s ease; }
.cursor-move:active { cursor: grabbing; }
.transition-all { transition-property: all; transition-timing-function: cubic-bezier(0.4, 0, 0.2, 1); transition-duration: 500ms; }
</style>
