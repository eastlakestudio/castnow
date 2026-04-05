<script setup>
import { ref, onUnmounted, watch, nextTick, computed, onMounted } from "vue";
import { useI18n } from "vue-i18n";
import { setLocale } from "./i18n";
import { inject as injectAnalytics } from "@vercel/analytics";
import {
  Monitor,
  X,
  Copy,
  Check,
  AlertCircle,
  Loader2,
  Camera,
  Repeat,
  Info,
  Activity,
  Globe,
  Download,
  Play,
  ArrowLeft,
  Volume2,
  VolumeX,
  Maximize,
  Smartphone,
  Zap,
  Shield,
  Apple,
  Mic,
  MicOff,
  LogOut,
  CheckCircle2,
} from "lucide-vue-next";

const { t, locale } = useI18n();

const STATES = {
  LANDING: "LANDING",
  SOURCE_SELECT: "SOURCE_SELECT",
  SENDER: "SENDER",
  RECEIVER_INPUT: "RECEIVER_INPUT",
  RECEIVER_ACTIVE: "RECEIVER_ACTIVE",
  BROADCAST_ENDED: "BROADCAST_ENDED",
};

const appState = ref(STATES.LANDING);
const isPro = ref(true); // Web version is now free for everyone
const castingMode = ref("screen");
const facingMode = ref("user");
const isConnecting = ref(false);
const error = ref(null);
const peerId = ref("");
const peerInstance = ref(null);
const localStream = ref(null);
const localVideo = ref(null);
const activeConnections = ref([]);
const isMicMuted = ref(true); // Default to muted per user request

// Receiver Refs
const joinCode = ref("");
const remoteStream = ref(null);
const screenStream = ref(null);
const cameraStream = ref(null);
const screenVideo = ref(null);
const cameraVideo = ref(null);

// Sender Preview Refs
const localScreenStream = ref(null);
const localCameraStream = ref(null);
const localScreenVideo = ref(null);
const localCameraVideo = ref(null);

const isMuted = ref(false);
const showControls = ref(true);
const showEndedDialog = ref(false);
const remoteDeviceInfo = ref(""); // Metadata from Broadcaster

// Layout State
const layoutMode = ref("pip"); // 'pip' | 'side-by-side'
const isSwapped = ref(false); // Swap which stream is primary
const pipPosition = ref({ x: 20, y: 20 });
const pipWidth = ref(320); // Default PiP width
const splitRatio = ref(0.5); // Default 50/50 split
const dragType = ref(null); // 'move-pip', 'resize-pip', 'splitter'
const isDragging = ref(false);
let pendingDragUpdate = false;
const dragOffset = ref({ x: 0, y: 0 });
const isReceiverMicActive = ref(false); // Receiver side intercom toggle
const receiverMicStream = ref(null);
const receiverAudioStream = ref(null); // Sender side: audio stream from receiver
const receiverAudioElement = ref(null);
const activeReceiverCall = ref(null); // Track the active call for the receiver
const activeTalkbackCall = ref(null); // Track the outgoing intercom call

const videoDevices = ref([]);
const hasMultipleCameras = computed(() => videoDevices.value.length > 1);

// Sender Multi-Source State
const selectedSources = ref(["screen", "camera", "mic"]); // ['screen', 'camera', 'mic'] enabled by default
const showInfo = ref(null); // 'source', 'privacy', 'terms'
const showProModal = ref(false);
const showFirefoxGuide = ref(false);
const activationCode = ref("");
const activeCode = ref("");
const proExpiresAt = ref(null);
const remainingSeconds = ref(180); // 3 minutes limit applied (previously 30)
const toast = ref({ show: false, message: "", type: "info" });
const receiverRoot = ref(null);
let controlsTimeout = null;
let sessionInterval = null;
let toastTimeout = null;

// 监听收到的音频流（发送端听接收端的对讲）
watch([receiverAudioElement, receiverAudioStream], ([el, stream]) => {
  if (el && stream) {
    el.srcObject = stream;
    el.muted = false; // Ensure not muted
    el.volume = 1.0; // Ensure full volume
    el.play().then(() => {
      console.log("🔊 [WEBRTC] Intercom audio playback started successfully");
    }).catch(e => {
      console.error("❌ [WEBRTC] Broadcaster audio playback failed (Auto-play policy?):", e);
      // Fallback: If blocked, we might need a "Click to Hear" button or similar interaction
    });
  }
});

// 监听视频元素的挂载，确保 stream 能正确绑定
watch([localVideo, localStream], ([el, stream]) => {
  if (el && stream) el.srcObject = stream;
});
watch([localScreenVideo, localScreenStream], ([el, stream]) => {
  if (el && stream) el.srcObject = stream;
});
watch([localCameraVideo, localCameraStream], ([el, stream]) => {
  if (el && stream) el.srcObject = stream;
});

const setupRemoteVideo = (el, stream) => {
  if (!el || !stream) return;
  el.srcObject = stream;
  el.muted = isMuted.value;
  el.setAttribute("playsinline", "true");
  el.setAttribute("webkit-playsinline", "true");
  el.play().catch(e => console.log("Autoplay blocked", e));
};

watch([screenVideo, screenStream], ([el, stream]) => setupRemoteVideo(el, stream));
watch([cameraVideo, cameraStream], ([el, stream]) => setupRemoteVideo(el, stream));

// Fallback for generic remoteStream (if metadata fails or single stream)
const remoteVideo = ref(null);
watch([remoteVideo, remoteStream], ([el, stream]) => {
  // Bind if we are in the single-stream fallback (either screen or camera sub-stream is missing)
  if (el && stream && (!screenStream.value || !cameraStream.value)) {
    setupRemoteVideo(el, stream);
  }
});

const showToast = (message, type = "info", duration = 3000) => {
  if (toastTimeout) clearTimeout(toastTimeout);
  toast.value = { show: true, message, type };
  toastTimeout = setTimeout(() => {
    toast.value.show = false;
  }, duration);
};

const toggleLanguage = () => {
  const newLocale = locale.value === "zh" ? "en" : "zh";
  setLocale(newLocale);
};

// Pro modal logic removed



// Environment Detection
const isTouchDevice = computed(() => {
  if (typeof window === "undefined") return false;
  return "ontouchstart" in window || navigator.maxTouchPoints > 0;
});

const isMobile = computed(() => {
  if (typeof navigator === "undefined") return false;
  return /Android|webOS|iPhone|iPad|iPod|BlackBerry|IEMobile|Opera Mini/i.test(navigator.userAgent);
});

const getOS = () => {
  const ua = navigator.userAgent;
  if (/Windows/i.test(ua)) return "Windows";
  if (/Mac/i.test(ua)) return "macOS";
  if (/Linux/i.test(ua)) return "Linux";
  if (/Android/i.test(ua)) return "Android";
  if (/iPhone|iPad|iPod/i.test(ua)) return "iOS";
  return "System";
};

const getBrowser = () => {
  const ua = navigator.userAgent;
  if (/Chrome/i.test(ua)) return "Chrome";
  if (/Safari/i.test(ua) && !/Chrome/i.test(ua)) return "Safari";
  if (/Firefox/i.test(ua)) return "Firefox";
  if (/Edg/i.test(ua)) return "Edge";
  return "Browser";
};

const getDeviceInfo = () => {
  return { type: "dev", os: getOS(), browser: getBrowser() };
};

// --- WebRTC Core ---
const getIceServers = () => {
  return [
    { urls: "stun:stun.l.google.com:19302" },
    { urls: "stun:stun.miwifi.com:3478" },
    { urls: "stun:stun.cdn.aliyun.com:3478" },
    { urls: "stun:stun.cloudflare.com:3478" },
    { urls: "stun:stun.tuna.tsinghua.edu.cn:3478" },
  ];
};

// --- Sender Logic ---
const handlePeerError = (err) => {
  console.error("PeerJS Error:", err);
  if (err.type === 'unavailable-id') {
    error.value = t('errors.code_collision');
  } else if (err.type === 'peer-unavailable') {
    // Receiver side issue usually
  } else if (err.type === 'network') {
    error.value = t('errors.network_error');
  } else if (err.type === 'browser-incompatible' || (err.message && err.message.includes('not support WebRTC'))) {
    // Firefox Block Detection
    showFirefoxGuide.value = true;
    error.value = null; // Hide generic error
    return;
  } else {
    error.value = `${t('errors.conn_failed')}: ${err.message}`;
  }
  isConnecting.value = false;
};

const toggleSource = (source) => {
  const index = selectedSources.value.indexOf(source);
  if (index > -1) {
    // If removing a video source, ensure the other one is still present
    if (source === 'screen' || source === 'camera') {
      const otherVideo = source === 'screen' ? 'camera' : 'screen';
      if (!selectedSources.value.includes(otherVideo)) {
        // This is the last video source, do not remove
        return;
      }
    }
    selectedSources.value.splice(index, 1);
  } else {
    selectedSources.value.push(source);
  }
};

const handleStartCasting = async () => {
  try {
    isConnecting.value = true;
    error.value = null;

    // iPad/iOS Safari HTTPS Check
    if (!window.isSecureContext && /iPad|iPhone|iPod/.test(navigator.userAgent)) {
      showToast(t('errors.secure_context_required'), "error", 8000);
      isConnecting.value = false;
      return;
    }

    let combinedStream = new MediaStream();

    // 1. Screen Share (Ordered first to ensure Screen is Video Track 0)
    if (selectedSources.value.includes('screen')) {
      if (!navigator.mediaDevices || !navigator.mediaDevices.getDisplayMedia) {
        showToast(t('errors.screen_share_unsupported'), "error", 5000);
        isConnecting.value = false;
        return;
      }
      const ss = await navigator.mediaDevices.getDisplayMedia({
        video: { cursor: "always" },
        audio: false, // DISABLE: As found, Tab audio creates incompatible multi-audio SDPs on iOS.
      });
      
      // Add Video Track first
      ss.getVideoTracks().forEach(t => combinedStream.addTrack(t));
      // DISCARD Screen Audio: As previously found, multi-audio tracks cause iOS negotiation failure.
      // We explicitly DO NOT add ss.getAudioTracks() here.
      
      localScreenStream.value = new MediaStream(ss.getVideoTracks());
      // Stop broadcast if screen share is stopped via browser UI
      ss.getVideoTracks()[0].onended = () => resetApp();
    }

    // 2. Camera Share (Ordered second to ensure Camera is Video Track 1)
    if (selectedSources.value.includes('camera')) {
      const cs = await navigator.mediaDevices.getUserMedia({
        video: {
          facingMode: facingMode.value,
          width: { ideal: 1280 },
          height: { ideal: 720 },
        },
        audio: false, // Mic is handled separately below for clarity
      });
      cs.getVideoTracks().forEach(t => {
        localCameraStream.value = new MediaStream([t]);
        combinedStream.addTrack(t);
      });
    }

    // 3. Microphone (The SOLE source of audio for the broadcast stream)
    if (selectedSources.value.includes('mic')) {
      try {
        const as = await navigator.mediaDevices.getUserMedia({ 
          audio: {
            echoCancellation: true,
            noiseSuppression: true,
            autoGainControl: true
          } 
        });
        as.getAudioTracks().forEach(t => {
          t.enabled = !isMicMuted.value;
          combinedStream.addTrack(t); // This should be the ONLY audio track in the stream
          console.log("🎙️ [WEBRTC] Added microphone track:", t.label);
        });
      } catch (e) {
        console.error("Failed to capture microphone", e);
        showToast(t('errors.mic_access_failed'), "error");
      }
    }

    localStream.value = combinedStream;
    appState.value = STATES.SENDER;

    const code = Math.floor(100000 + Math.random() * 900000).toString();
    const peer = new window.Peer(code, {
      debug: 1,
      config: { 
        iceServers: getIceServers(),
        sdpSemantics: 'unified-plan'
      },
    });

    peerInstance.value = peer;
    peer.on("open", (id) => {
      peerId.value = id;
      isConnecting.value = false;
    });
    // 2. Active Push: When a receiver connects via DataConnection, we PUSH the video stream
    peer.on("connection", (conn) => {
      activeConnections.value.push(conn);
      conn.on("open", () => {
        const stream = localStream.value;
        if (stream) {
          console.log(`🚀 [WEBRTC] INITIATING FORWARD VIDEO CALL TO ${conn.peer} | Tracks: V=${stream.getVideoTracks().length}, A=${stream.getAudioTracks().length}`);
          if (stream.getVideoTracks().length < 2 && selectedSources.value.includes('screen') && selectedSources.value.includes('camera')) {
            console.warn("⚠️ [WEBRTC] Potential multi-track issue: Expecting 2 videos but stream only has 1!");
          }
          const call = peer.call(conn.peer, stream);
          setupCallHandlers(call);
        }
      });
      conn.on("close", () => {
        activeConnections.value = activeConnections.value.filter(c => c.peer !== conn.peer);
      });
    });

    // 3. Passive Listen: Handle incoming talkback calls from Receivers (Intercom)
    peer.on("call", (call) => {
      console.log("📞 [PEER] Broadcaster received incoming intercom/direct call from:", call.peer);
      
      // ANSWER with local stream to provide audio return, but the primary video is sent via forward call
      call.answer(localStream.value); 
      
      call.on("stream", (rs) => {
        console.log("🎙️ [WEBRTC] Broadcaster received talkback stream | Audio Tracks:", rs.getAudioTracks().length);
        receiverAudioStream.value = rs;
      });
      call.on("close", () => {
        receiverAudioStream.value = null;
      });
    });

    peer.on("error", handlePeerError);
  } catch (err) {
    console.error(err);
    if (err.name === "NotAllowedError") {
      error.value = null;
    } else {
      error.value = t('errors.device_denied');
    }
    isConnecting.value = false;
  }
};

const setupCallHandlers = (call) => {
  call.on("stream", (rs) => {
    console.log("🎙️ [WEBRTC] Broadcaster received talkback stream");
    if (rs.getAudioTracks().length > 0) {
      receiverAudioStream.value = rs;
    }
  });

  // Also listen to raw ontrack for dynamically added tracks
  if (call.peerConnection) {
    call.peerConnection.ontrack = (event) => {
      console.log("🎙️ [WEBRTC] Broadcaster detected new track:", event.track.kind);
      if (event.track.kind === 'audio') {
        const stream = event.streams[0] || new MediaStream([event.track]);
        receiverAudioStream.value = stream;
      }
    };
  }

  call.on("error", (err) => {
    console.error("Call Error:", err);
  });
  
  call.on("close", () => {
    activeConnections.value = activeConnections.value.filter(c => c.peer !== call.peer);
  });
};

const toggleReceiverMic = async () => {
  if (isDragging.value) return;

  if (!receiverMicStream.value) {
    showToast(t('errors.mic_access_failed'), "error");
    return;
  }

  isReceiverMicActive.value = !isReceiverMicActive.value;
  receiverMicStream.value.getAudioTracks().forEach(t => {
    t.enabled = isReceiverMicActive.value;
  });
  
  if (isReceiverMicActive.value) {
    showToast(t('receiver.mic_on'), "success");
  } else {
    showToast(t('receiver.mic_off'), "info");
  }
};

const toggleCamera = async () => {
  if (!selectedSources.value.includes('camera') || !localStream.value || !localCameraStream.value) return;
  
  const oldMode = facingMode.value;
  facingMode.value = facingMode.value === "user" ? "environment" : "user";

  try {
    const newStream = await navigator.mediaDevices.getUserMedia({
      video: { facingMode: facingMode.value, width: { ideal: 1280 }, height: { ideal: 720 } },
      audio: false 
    });

    const newVideoTrack = newStream.getVideoTracks()[0];
    const oldCameraTrackId = localCameraStream.value.getVideoTracks()[0]?.id;
    
    // 1. Update Preview
    localCameraStream.value = new MediaStream([newVideoTrack]);

    // 2. Identify the old camera track in localStream (the combined stream)
    // We use the ID from our preview stream to be 100% certain
    const oldCameraTrack = localStream.value.getVideoTracks().find(t => t.id === oldCameraTrackId);

    if (oldCameraTrack) {
      oldCameraTrack.stop();
      localStream.value.removeTrack(oldCameraTrack);
    }
    localStream.value.addTrack(newVideoTrack);

    // 3. Inform existing connections. PeerJS requires re-calling to replace stream mid-session
    activeConnections.value.forEach((conn) => {
      const call = peerInstance.value.call(conn.peer, localStream.value);
      setupCallHandlers(call);
    });

    showToast(t('sender.camera_switched'), "success");
  } catch (err) {
    facingMode.value = oldMode;
    showToast(t('errors.camera_switch_failed'), "error");
  }
};

// --- Receiver Logic ---
const handleDigitInput = (digit) => {
  if (joinCode.value.length < 6) joinCode.value += digit;
};

const handleBackspace = () => {
  joinCode.value = joinCode.value.slice(0, -1);
};

const handleKeyDown = (e) => {
  if (appState.value !== STATES.RECEIVER_INPUT) return;
  if (isConnecting.value) return;

  if (/^[0-9]$/.test(e.key)) {
    handleDigitInput(e.key);
  } else if (e.key === "Backspace") {
    handleBackspace();
  } else if (e.key === "Enter") {
    handleJoin();
  } else if (e.key === "Escape") {
    resetApp();
  }
};

onMounted(async () => {
  window.addEventListener("keydown", handleKeyDown);
  
  // Detect cameras
  try {
    const devices = await navigator.mediaDevices.enumerateDevices();
    videoDevices.value = devices.filter(d => d.kind === 'videoinput');
  } catch (e) {
    console.error("Device detection failed", e);
  }
});

onUnmounted(() => {
  window.removeEventListener("keydown", handleKeyDown);
});

const handleJoin = async () => {
  if (joinCode.value.length !== 6) return;

  isConnecting.value = true;
  error.value = null;

  // Pre-allocate the microphone stream up front to establish a solid bi-directional SDP blueprint.
  try {
    const audioStream = await navigator.mediaDevices.getUserMedia({ audio: true });
    audioStream.getAudioTracks().forEach(t => t.enabled = false);
    receiverMicStream.value = audioStream;
    isReceiverMicActive.value = false;
  } catch (err) {
    console.warn("Could not pre-allocate receiver microphone", err);
  }

  // Viewer needs their own Peer ID to receive the call
  const peer = new window.Peer({
    config: { 
      iceServers: getIceServers(),
      sdpSemantics: 'unified-plan'
    },
  });

  peerInstance.value = peer;

  peer.on("open", (id) => {
    console.log("🚀 [PEER] Viewer Peer Open, ID:", id);
    const conn = peer.connect(joinCode.value, { serialization: 'json' });
    console.log("📡 [PEER] Attempting to connect to Broadcaster:", joinCode.value);

    conn.on("open", () => {
      console.log("🤝 [DATA] Connection to Broadcaster OPEN");
      const info = getDeviceInfo();
      setTimeout(() => conn.send(info), 500);
      appState.value = STATES.RECEIVER_ACTIVE;
      isConnecting.value = false;
    });

    conn.on("data", (data) => {
      console.log("📥 [DATA] Received from Broadcaster:", data);
      try {
        const payload = typeof data === "string" ? JSON.parse(data) : data;
        if (payload && payload.type === "dev") {
          remoteDeviceInfo.value = `${payload.os} ${payload.model || ""}`.trim();
        }
      } catch (e) {
        console.error("Data Parse Error:", e);
      }
    });

    conn.on("close", () => {
      console.log("⛔ [DATA] Connection CLOSED");
      appState.value = STATES.BROADCAST_ENDED;
      resetApp();
    });
    
    conn.on("error", (err) => {
      console.error("❌ [DATA] Error:", err);
    });
  });

    // 2. Wait for Broadcaster to call us with the stream
    peer.on("call", (call) => {
      activeReceiverCall.value = call;
      // Answer with the local mic stream if active (Intercom)
      call.answer(receiverMicStream.value || undefined); 
      
      call.on("stream", (rs) => {
        console.log("📥 [WEBRTC] Received remote stream:", rs.id);
        
        // Potential fix for black screen: ensure tracks are enabled and wait for unmute
        rs.getTracks().forEach(t => {
          t.enabled = true;
          t.onunmute = () => {
            console.log(`✅ Track ${t.kind} unmuted`);
            // Force re-assignment to trigger watchers if needed
            remoteStream.value = new MediaStream(rs.getTracks());
          };
          if (t.readyState === 'ended') console.warn(`⚠️ track ${t.kind} is ended`);
        });

        remoteStream.value = rs;

        // Extract tracks for splitting
        const videoTracks = rs.getVideoTracks();
        const audioTracks = rs.getAudioTracks();

        console.log(`📥 [WEBRTC] Tracks - Video: ${videoTracks.length}, Audio: ${audioTracks.length}`);

        if (videoTracks.length > 0) {
          // Track 0 is Screen
          screenStream.value = new MediaStream([videoTracks[0], ...audioTracks]);
          console.log("📺 [WEBRTC] Assigned Screen Stream:", videoTracks[0].label);
          // Wait for track to be active
          videoTracks[0].onunmute = () => {
             console.log("📺 [WEBRTC] Screen track unmuted");
          };
        }
        
        if (videoTracks.length > 1) {
          // Track 1 is Camera
          cameraStream.value = new MediaStream([videoTracks[1]]);
          console.log("📷 [WEBRTC] Assigned Camera Stream:", videoTracks[1].label);
        } else {
          cameraStream.value = null;
        }
      });
    });

  peer.on("error", (err) => {
    handlePeerError(err);
    if (!showFirefoxGuide.value) {
      joinCode.value = "";
    }
  });
};

const toggleLayout = () => {
  layoutMode.value = layoutMode.value === "pip" ? "side-by-side" : "pip";
};

const swapStreams = () => {
  isSwapped.value = !isSwapped.value;
};

// Drag implementation for PiP & Splitter
const handleDragStart = (e, type = 'move-pip') => {
  if (layoutMode.value === 'side-by-side' && type !== 'splitter') return;
  
  isDragging.value = true;
  dragType.value = type;
  
  const clientX = e.type.includes('touch') ? e.touches[0].clientX : e.clientX;
  const clientY = e.type.includes('touch') ? e.touches[0].clientY : e.clientY;
  
  if (type === 'move-pip') {
    dragOffset.value = {
      x: clientX - pipPosition.value.x,
      y: clientY - pipPosition.value.y
    };
  } else if (type === 'resize-pip') {
    dragOffset.value = {
      x: clientX,
      width: pipWidth.value
    };
  } else if (type === 'splitter') {
    dragOffset.value = {
      x: clientX
    };
  }
};

const handleDragMove = (e) => {
  if (!isDragging.value) return;
  if (pendingDragUpdate) return;

  const clientX = e.type.includes('touch') ? e.touches[0].clientX : e.clientX;
  const clientY = e.type.includes('touch') ? e.touches[0].clientY : e.clientY;

  pendingDragUpdate = true;
  requestAnimationFrame(() => {
    if (dragType.value === 'move-pip') {
      pipPosition.value = {
        x: clientX - dragOffset.value.x,
        y: clientY - dragOffset.value.y
      };
    } else if (dragType.value === 'resize-pip') {
      const deltaX = clientX - dragOffset.value.x;
      pipWidth.value = Math.max(160, dragOffset.value.width + deltaX);
    } else if (dragType.value === 'splitter') {
      const totalWidth = window.innerWidth;
      splitRatio.value = Math.min(0.9, Math.max(0.1, clientX / totalWidth));
    }
    pendingDragUpdate = false;
  });
};

const handleDragEnd = () => {
  isDragging.value = false;
  dragType.value = null;
};

const toggleMute = () => {
  isMuted.value = !isMuted.value;
};

const toggleMic = () => {
  if (localStream.value) {
    isMicMuted.value = !isMicMuted.value;
    localStream.value.getAudioTracks().forEach((track) => {
      track.enabled = !isMicMuted.value;
    });
  }
};

const toggleFullscreen = () => {
  if (!document.fullscreenElement && receiverRoot.value) {
    receiverRoot.value
      .requestFullscreen()
      .catch((err) => console.log(err));
  } else if (document.fullscreenElement) {
    document.exitFullscreen();
  }
};

const handleMouseMove = (e) => {
  // Logic removed in favor of mouseenter/mouseleave on sensing zone
};

// --- Shared ---
const resetApp = (forceLanding = false) => {
  // Stop ALL active streams to prevent "camera residue" or mic usage lights staying on
  const streamsToStop = [
    localStream.value,
    localScreenStream.value,
    localCameraStream.value,
    remoteStream.value,
    screenStream.value,
    cameraStream.value,
    receiverMicStream.value,
    receiverAudioStream.value
  ];

  streamsToStop.forEach(s => {
    if (s && s.getTracks) {
      s.getTracks().forEach(t => {
        t.stop();
        console.log(`Stopped track: ${t.label}`);
      });
    }
  });

  if (peerInstance.value) {
    peerInstance.value.destroy();
    peerInstance.value = null;
  }

  if (sessionInterval) {
    clearInterval(sessionInterval);
    sessionInterval = null;
  }

  if (forceLanding || appState.value !== STATES.BROADCAST_ENDED) {
    appState.value = STATES.LANDING;
  }

  peerId.value = "";
  localStream.value = null;
  localScreenStream.value = null;
  localCameraStream.value = null;
  remoteStream.value = null;
  screenStream.value = null;
  cameraStream.value = null;
  activeReceiverCall.value = null;
  joinCode.value = "";
  isConnecting.value = false;
  error.value = null;
};

</script>

<template>
  <div class="min-h-[100dvh] flex flex-col bg-slate-950 text-slate-50 font-sans selection:bg-amber-500/30">
    <header v-if="appState !== STATES.RECEIVER_ACTIVE"
      class="flex items-center justify-between px-6 py-4 border-b border-slate-800/50 backdrop-blur-md sticky top-0 z-50">
      <div class="flex items-center gap-3 cursor-pointer group" @click="resetApp">
        <!-- Logo Icon -->
        <img src="/icon.svg" alt="CastNow"
          class="w-10 h-10 rounded-xl shadow-lg shadow-amber-500/10 group-hover:scale-105 transition-transform duration-300" />
        <span
          class="bg-gradient-to-r from-slate-100 to-slate-400 bg-clip-text text-xl font-black italic uppercase tracking-tight text-transparent pr-1">CastNow</span>

      </div>
      <div class="flex items-center gap-4">
        <!-- Language Switcher -->
        <button @click="toggleLanguage"
          class="flex items-center gap-1.5 px-3 py-1.5 bg-slate-900 border border-slate-800 rounded-full hover:border-amber-500/50 transition-all text-[10px] font-black uppercase tracking-widest text-slate-400 group">
          <Globe class="w-3.5 h-3.5 text-slate-500 group-hover:text-amber-500 transition-colors" />
          <span :class="{ 'text-white': locale === 'zh' }">中文</span>
          <span class="text-slate-700">/</span>
          <span :class="{ 'text-white': locale === 'en' }">EN</span>
        </button>

        <div class="w-px h-4 bg-slate-800 hidden md:block"></div>

        <button @click="showInfo = 'source'"
          class="flex items-center gap-2 px-4 py-2 bg-slate-900 border border-slate-800 rounded-xl hover:border-slate-600 transition-all group">
          <Globe class="w-4 h-4 text-slate-500 group-hover:text-amber-500 transition-colors" />
          <span class="text-[10px] font-black uppercase tracking-widest text-slate-400 group-hover:text-white transition-colors">{{ $t('landing.source') }}</span>
        </button>
      </div>
    </header>

    <!-- Firefox Privacy Guide Overlay -->
    <div v-if="showFirefoxGuide"
      class="fixed inset-0 z-[100] bg-slate-950/90 backdrop-blur-xl flex flex-col items-center justify-center p-6 text-center">
      <div
        class="bg-slate-900 border border-slate-800 p-8 rounded-[3rem] max-w-md w-full shadow-2xl relative overflow-hidden">
        <!-- Glow effect -->
        <div class="absolute top-0 left-1/2 -translate-x-1/2 w-32 h-1 bg-amber-500 blur-sm"></div>

        <div class="w-20 h-20 bg-amber-500/10 rounded-full flex items-center justify-center mx-auto mb-6">
          <Shield class="w-10 h-10 text-amber-500" />
        </div>

        <h3 class="text-2xl font-black uppercase mb-4 text-white">{{ $t('firefox.title') }}</h3>

        <p class="text-slate-400 text-sm mb-6 leading-relaxed">
          {{ $t('firefox.desc') }}
        </p>

        <div class="bg-black/50 rounded-xl p-4 mb-8 border border-white/5 text-left text-xs text-slate-300 space-y-3">
          <div class="flex items-center gap-3">
            <div class="w-6 h-6 flex items-center justify-center bg-slate-800 rounded-full font-bold text-amber-500">1
            </div>
            <span>{{ $t('firefox.step1') }}</span>
          </div>
          <div class="flex items-center gap-3">
            <div class="w-6 h-6 flex items-center justify-center bg-slate-800 rounded-full font-bold text-amber-500">2
            </div>
            <span>{{ $t('firefox.step2') }}</span>
          </div>
        </div>

        <button @click="() => { showFirefoxGuide = false; window.location.reload(); }"
          class="w-full py-4 bg-amber-500 hover:bg-amber-400 text-slate-950 font-black rounded-xl uppercase tracking-widest transition-all active:scale-95">
          {{ $t('firefox.retry') }}
        </button>
      </div>
    </div>

    <main class="flex-1 flex flex-col relative overflow-hidden">
      <Transition name="fade" mode="out-in">
        <!-- Landing -->
        <div v-if="appState === STATES.LANDING"
          class="flex-1 flex flex-col items-center justify-center p-6 text-center">
          <div class="mb-4 px-4 py-1 bg-amber-500/10 border border-amber-500/20 rounded-full flex items-center gap-2">
            <Globe class="w-3 h-3 text-amber-500" />
            <span class="text-[10px] font-black uppercase text-amber-500 tracking-widest">{{ $t('landing.secure_protocol')
              }}</span>
          </div>
          <h1 class="text-6xl md:text-8xl font-black mb-6 tracking-tighter leading-none">
            {{ $t('landing.title_part1') }}<span class="text-amber-500">{{ $t('landing.title_part2') }}</span>
          </h1>
          <p class="text-slate-500 max-w-xs mb-10 text-sm font-medium italic">
            {{ $t('landing.subtitle') }}
          </p>

          <div class="flex flex-col gap-4 w-full max-w-xs">
            <button @click="appState = STATES.SOURCE_SELECT"
              class="group relative py-6 bg-amber-500 text-slate-950 rounded-3xl font-black text-xl uppercase shadow-xl shadow-amber-500/20 active:scale-95 transition-all overflow-hidden">
              <span class="relative z-10">{{ $t('landing.broadcast') }}</span>
              <div class="absolute inset-0 bg-white/20 translate-y-full group-hover:translate-y-0 transition-transform">
              </div>
            </button>
            <button @click="appState = STATES.RECEIVER_INPUT"
              class="py-6 bg-slate-900 border border-slate-800 rounded-3xl font-black text-xl uppercase active:scale-95 transition-all flex items-center justify-center gap-3 hover:border-slate-700">
              <Download class="w-6 h-6" />
              {{ $t('landing.receive') }}
            </button>
            <div class="flex flex-wrap gap-4 w-full max-w-sm mx-auto justify-center">
              <a href="/castnow.apk" download
                class="flex-1 min-w-[140px] h-11 bg-slate-900 border border-slate-800 rounded-xl hover:border-amber-500 transition-all flex items-center px-4 gap-3 group active:scale-95">
                <Smartphone class="w-6 h-6 text-amber-500 group-hover:scale-110 transition-transform" />
                <div class="flex flex-col items-start leading-none">
                  <span class="text-[8px] font-bold text-slate-500 uppercase tracking-tighter">Download for</span>
                  <span class="text-xs font-black text-slate-100 uppercase tracking-tight">Android APK</span>
                </div>
              </a>
              <a href="https://apps.apple.com/us/app/castnow-pro/id6761016081" target="_blank"
                class="flex-1 min-w-[140px] h-11 bg-black border border-slate-800 rounded-xl hover:border-amber-500 transition-all flex items-center px-4 gap-3 group active:scale-95">
                <Apple class="w-6 h-6 text-white group-hover:scale-110 transition-transform" />
                <div class="flex flex-col items-start leading-none">
                  <span class="text-[8px] font-bold text-slate-400 uppercase tracking-tighter">Download on the</span>
                  <span class="text-xs font-black text-white uppercase tracking-tight">App Store</span>
                </div>
              </a>
            </div>


          </div>


          <div class="mt-16 flex flex-col items-center gap-6">
            <div class="flex items-center justify-center flex-wrap gap-4 md:gap-8 text-slate-600 font-bold text-[10px] uppercase tracking-[0.2em]">
              <button @click="showInfo = 'privacy'" class="hover:text-amber-500 transition-colors">{{ $t('landing.privacy')
                }}</button>
              <button @click="showInfo = 'terms'" class="hover:text-amber-500 transition-colors">{{ $t('landing.terms')
                }}</button>
              <button @click="showInfo = 'support'" class="hover:text-amber-500 transition-colors">{{ $t('landing.email')
                }}</button>
              <a href="/blog/index.html" class="hover:text-amber-500 transition-colors">BLOG & GUIDES</a>
            </div>

            <div class="text-[9px] font-black text-slate-800 uppercase tracking-[0.2em] flex items-center gap-2">
              <span class="w-4 h-px bg-slate-800"></span>
              {{ $t('landing.made_by') }}
              <span class="w-4 h-px bg-slate-800"></span>
            </div>
          </div>
        </div>

        <!-- Source Selection -->
        <div v-else-if="appState === STATES.SOURCE_SELECT" class="flex-1 flex flex-col items-center justify-center p-6">
          <h2 class="text-2xl font-black uppercase mb-12 tracking-widest flex items-center gap-3">
            <span class="w-8 h-[2px] bg-amber-500"></span>
            {{ $t('source_select.title') }}
            <span class="w-8 h-[2px] bg-amber-500"></span>
          </h2>
          <div class="w-full max-w-2xl space-y-6">
            <div class="grid grid-cols-1 md:grid-cols-2 gap-6 w-full">
              <!-- Screen Share Card -->
              <button @click="toggleSource('screen')"
                class="flex flex-col items-center gap-6 p-10 bg-slate-900 border rounded-[2.5rem] transition-all group relative overflow-hidden"
                :class="selectedSources.includes('screen') ? 'border-amber-500 bg-amber-500/5 shadow-[0_0_40px_-10px_rgba(245,158,11,0.2)]' : 'border-slate-800 border-dashed hover:border-slate-600 hover:bg-slate-800/30'">
                <div
                  class="w-20 h-20 bg-slate-950 rounded-3xl flex items-center justify-center group-hover:scale-110 transition-transform shadow-xl">
                  <Monitor class="w-10 h-10" :class="selectedSources.includes('screen') ? 'text-amber-500' : 'text-slate-600'" />
                </div>
                <div class="text-center">
                  <span class="block font-black uppercase tracking-[0.2em] text-sm mb-1" :class="selectedSources.includes('screen') ? 'text-amber-500' : 'text-slate-600'">{{ $t('source_select.screen_share') }}</span>
                  <span class="block text-[9px] font-bold text-slate-500 uppercase tracking-widest opacity-60">High Quality Stream</span>
                </div>
                <div v-if="selectedSources.includes('screen')" class="absolute top-6 right-6 text-amber-500">
                  <CheckCircle2 class="w-6 h-6 fill-amber-500/10" />
                </div>
              </button>

              <!-- Camera Card -->
              <button @click="toggleSource('camera')"
                class="flex flex-col items-center gap-6 p-10 bg-slate-900 border rounded-[2.5rem] transition-all group relative overflow-hidden"
                :class="selectedSources.includes('camera') ? 'border-amber-500 bg-amber-500/5 shadow-[0_0_40px_-10px_rgba(245,158,11,0.2)]' : 'border-slate-800 border-dashed hover:border-slate-600 hover:bg-slate-800/30'">
                <div
                  class="w-20 h-20 bg-slate-950 rounded-3xl flex items-center justify-center group-hover:scale-110 transition-transform shadow-xl">
                  <Camera class="w-10 h-10" :class="selectedSources.includes('camera') ? 'text-amber-500' : 'text-slate-600'" />
                </div>
                <div class="text-center">
                  <span class="block font-black uppercase tracking-[0.2em] text-sm mb-1" :class="selectedSources.includes('camera') ? 'text-white' : 'text-slate-600'">{{ $t('source_select.camera') }}</span>
                  <span class="block text-[9px] font-bold text-slate-500 uppercase tracking-widest opacity-60">Live Video Feed</span>
                </div>
                <div v-if="selectedSources.includes('camera')" class="absolute top-6 right-6 text-amber-500">
                  <CheckCircle2 class="w-6 h-6 fill-amber-500/10" />
                </div>
              </button>
            </div>

            <!-- Microphone Selection Bar -->
            <button @click="toggleSource('mic')"
              class="w-full flex items-center justify-between px-8 py-5 bg-slate-900 border rounded-[1.5rem] transition-all group relative overflow-hidden"
              :class="selectedSources.includes('mic') ? 'border-amber-500 bg-amber-500/5' : 'border-slate-800 border-dashed hover:border-slate-600'">
              <div class="flex items-center gap-5">
                <div class="w-10 h-10 bg-slate-950 rounded-xl flex items-center justify-center group-hover:scale-110 transition-transform shadow-lg">
                  <Volume2 v-if="selectedSources.includes('mic')" class="w-5 h-5 text-amber-500" />
                  <VolumeX v-else class="w-5 h-5 text-slate-600" />
                </div>
                <div class="text-left">
                  <span class="block font-black uppercase tracking-widest text-xs" :class="selectedSources.includes('mic') ? 'text-white' : 'text-slate-500'">{{ $t('source_select.microphone') }}</span>
                  <span class="block text-[8px] font-bold text-slate-500 uppercase tracking-tighter opacity-50">Sync audio from your device</span>
                </div>
              </div>
              <div class="flex items-center gap-3">
                 <span class="text-[10px] font-black uppercase tracking-widest" :class="selectedSources.includes('mic') ? 'text-amber-500' : 'text-slate-600'">
                   {{ selectedSources.includes('mic') ? 'ON' : 'OFF' }}
                 </span>
                 <div class="w-10 h-5 bg-slate-950 rounded-full border border-slate-800 p-1 relative transition-colors"
                      :class="{ 'bg-amber-500/20 border-amber-500/50': selectedSources.includes('mic') }">
                   <div class="w-3 h-3 rounded-full bg-slate-700 transition-all duration-300 transform"
                        :class="selectedSources.includes('mic') ? 'translate-x-5 bg-amber-500 shadow-[0_0_10px_rgba(245,158,11,0.5)]' : 'translate-x-0'"></div>
                 </div>
              </div>
            </button>
          </div>

          <div class="mt-12 flex flex-col items-center gap-6">
            <button @click="handleStartCasting"
              class="px-12 py-4 bg-amber-500 text-slate-950 font-black rounded-2xl uppercase tracking-widest hover:scale-105 active:scale-95 transition-all shadow-xl shadow-amber-500/20">
              {{ $t('source_select.start_broadcast') }}
            </button>
            <button @click="appState = STATES.LANDING"
              class="text-slate-500 font-black uppercase tracking-widest text-[10px] hover:text-white transition-colors">
              {{ $t('source_select.cancel') }}
            </button>
          </div>
        </div>

        <!-- Sender View -->
        <div v-else-if="appState === STATES.SENDER" class="flex-1 flex flex-col items-center justify-center p-4">
          <div
            class="w-full max-w-xl bg-slate-900 border border-slate-800 rounded-[3rem] p-8 text-center relative overflow-hidden shadow-2xl">
            <div
              class="absolute top-0 left-0 w-full h-1 bg-gradient-to-r from-transparent via-amber-500 to-transparent animate-pulse">
            </div>

            <div class="flex items-center justify-between mb-8">
              <div class="flex items-center gap-2">
                <Activity class="w-4 h-4 text-amber-500" />
                <span class="text-[10px] font-black text-slate-500 uppercase tracking-widest">{{ $t('sender.active_tunnel')
                  }}</span>
              </div>
              <div class="flex items-center gap-2">
                <button @click="toggleMic"
                  class="flex items-center gap-2 px-3 py-1.5 bg-slate-800 rounded-full hover:bg-amber-500 hover:text-slate-950 transition-all"
                  :class="{ 'bg-red-500/20 text-red-500 hover:bg-red-500 hover:text-white': isMicMuted }">
                  <component :is="isMicMuted ? VolumeX : Volume2" class="w-3 h-3" />
                  <span class="text-[10px] font-black uppercase">{{ isMicMuted ? $t('sender.muted') : $t('sender.mic_on')
                    }}</span>
                </button>
                <button v-if="selectedSources.includes('camera') && hasMultipleCameras" @click="toggleCamera"
                  class="flex items-center gap-2 px-3 py-1.5 bg-slate-800 rounded-full hover:bg-amber-500 hover:text-slate-950 transition-all">
                  <Repeat class="w-3 h-3" />
                  <span class="text-[10px] font-black uppercase">{{
                    facingMode === "user" ? $t('sender.front') : $t('sender.back')
                    }}</span>
                </button>
              </div>
            </div>

            <div class="mb-10">
              <p class="text-[10px] font-black text-slate-500 uppercase tracking-[0.3em] mb-4">
                {{ $t('sender.sharing_key') }}
              </p>
              <div class="flex items-center justify-center gap-2">
                <template v-for="(char, i) in peerId.split('')" :key="i">
                  <span
                    class="text-4xl md:text-6xl font-black bg-slate-950 w-12 md:w-16 h-16 md:h-24 flex items-center justify-center rounded-2xl border border-slate-800 text-amber-500 shadow-inner">{{
                      char }}</span>
                  <span v-if="i === 2" class="text-slate-800 font-black text-2xl">-</span>
                </template>
                <div v-if="!peerId" class="flex gap-2">
                  <div v-for="n in 6" :key="n"
                    class="w-12 h-16 bg-slate-950 rounded-2xl border border-slate-800 animate-pulse"></div>
                </div>
              </div>
            </div>

            <div class="grid gap-4 mb-8" :class="localScreenStream && localCameraStream ? 'grid-cols-2' : 'grid-cols-1'">
              <!-- Screen Preview -->
              <div v-if="localScreenStream"
                class="aspect-video bg-black rounded-3xl border border-slate-800 overflow-hidden relative group shadow-inner">
                <video ref="localScreenVideo" autoplay muted playsinline class="w-full h-full object-cover" />
                <div class="absolute inset-0 bg-gradient-to-t from-black/60 to-transparent"></div>
                <div class="absolute bottom-4 left-6 flex items-center gap-3">
                  <div class="w-2 h-2 bg-red-500 rounded-full animate-ping"></div>
                  <span class="text-[8px] font-black uppercase tracking-widest">{{ $t('source_select.screen_share') }}</span>
                </div>
              </div>

              <!-- Camera Preview -->
              <div v-if="localCameraStream"
                class="aspect-video bg-black rounded-3xl border border-slate-800 overflow-hidden relative group shadow-inner">
                <video ref="localCameraVideo" autoplay muted playsinline class="w-full h-full object-cover" />
                <div class="absolute inset-0 bg-gradient-to-t from-black/60 to-transparent"></div>
                <div class="absolute bottom-4 left-6 flex items-center gap-3">
                  <div class="w-2 h-2 bg-red-500 rounded-full animate-ping"></div>
                  <span class="text-[8px] font-black uppercase tracking-widest">{{ $t('source_select.camera') }}</span>
                </div>
              </div>

              <!-- Fallback (if somehow streams not split) -->
              <div v-if="!localScreenStream && !localCameraStream"
                class="aspect-video bg-black rounded-3xl border border-slate-800 overflow-hidden relative group shadow-inner">
                <video ref="localVideo" autoplay muted playsinline class="w-full h-full object-cover" />
              </div>
            </div>

            <button @click="resetApp"
              class="w-full py-5 bg-red-500/10 hover:bg-red-500 text-red-500 hover:text-white font-black rounded-2xl transition-all border border-red-500/20 uppercase tracking-widest text-xs">
              {{ $t('sender.terminate') }}
            </button>
          </div>
        </div>

        <!-- Receiver Input -->
        <div v-else-if="appState === STATES.RECEIVER_INPUT"
          class="flex-1 flex flex-col items-center justify-center p-6">
          <h2 class="text-2xl font-black uppercase mb-10 tracking-widest flex items-center gap-3">
            <span class="w-8 h-[2px] bg-amber-500"></span>
            {{ $t('receiver.title') }}
            <span class="w-8 h-[2px] bg-amber-500"></span>
          </h2>

          <!-- Display -->
          <div class="mb-10 flex gap-2 h-20 md:h-24">
            <div v-for="i in 6" :key="i"
              class="w-12 md:w-16 bg-slate-900 border border-slate-800 rounded-2xl flex items-center justify-center text-3xl md:text-4xl font-black text-white shadow-inner transition-colors duration-200"
              :class="{
                'border-amber-500/50 text-amber-500': joinCode[i - 1],
                'animate-pulse bg-slate-800/50': joinCode.length === i - 1,
              }">
              {{ joinCode[i - 1] || "" }}
            </div>
          </div>

          <!-- Keypad - Only show on touch devices -->
          <div v-if="isTouchDevice" class="grid grid-cols-3 gap-4 w-full max-w-[280px] mb-8">
            <button v-for="n in 9" :key="n" @click="handleDigitInput(n.toString())"
              class="h-16 rounded-2xl bg-slate-900 border border-slate-800 hover:bg-slate-800 text-xl font-bold active:scale-95 transition-all">
              {{ n }}
            </button>
            <button @click="resetApp"
              class="h-16 rounded-2xl bg-slate-950 border border-slate-900 hover:bg-slate-900 text-slate-500 flex items-center justify-center active:scale-95 transition-all">
              <X class="w-6 h-6" />
            </button>
            <button @click="handleDigitInput('0')"
              class="h-16 rounded-2xl bg-slate-900 border border-slate-800 hover:bg-slate-800 text-xl font-bold active:scale-95 transition-all">
              0
            </button>
            <button @click="handleBackspace"
              class="h-16 rounded-2xl bg-slate-950 border border-slate-900 hover:bg-slate-900 text-slate-500 flex items-center justify-center active:scale-95 transition-all">
              <ArrowLeft class="w-6 h-6" />
            </button>
          </div>

          <div v-else class="mb-12 text-slate-500 text-xs font-bold uppercase tracking-widest animate-pulse">
            {{ $t('receiver.keyboard_hint') }}
          </div>

          <button @click="handleJoin" :disabled="joinCode.length !== 6 || isConnecting"
            class="w-full max-w-[280px] py-5 bg-amber-500 disabled:bg-slate-800 disabled:text-slate-600 text-slate-950 font-black rounded-2xl text-lg uppercase tracking-widest shadow-xl shadow-amber-500/20 active:scale-95 transition-all flex items-center justify-center gap-2">
            <Loader2 v-if="isConnecting" class="w-5 h-5 animate-spin" />
            <span v-else>{{ $t('receiver.connect_now') }}</span>
          </button>

          <!-- Cancel Button during connecting -->
          <button v-if="isConnecting" @click="resetApp"
            class="mt-4 text-slate-500 font-bold uppercase tracking-widest text-[10px] hover:text-white transition-colors flex items-center gap-2">
            <X class="w-3 h-3" /> {{ $t('receiver.stop_connecting') }}
          </button>

          <p v-if="error" class="mt-4 text-red-500 text-xs font-bold uppercase tracking-widest flex items-center gap-2">
            <AlertCircle class="w-4 h-4" /> {{ error }}
          </p>
        </div>

        <!-- Broadcast Ended Dialog as a full state for cleaner transition -->
        <div v-else-if="appState === STATES.BROADCAST_ENDED"
          class="flex-1 flex items-center justify-center p-6 bg-slate-950">
          <div class="w-full max-w-sm bg-slate-900 border border-slate-800 rounded-[3rem] p-10 text-center shadow-2xl">
            <div
              class="w-24 h-24 bg-amber-500/10 rounded-full flex items-center justify-center mx-auto mb-8 animate-bounce">
              <Info class="w-12 h-12 text-amber-500" />
            </div>
            <h3 class="text-3xl font-black uppercase mb-4 tracking-tight text-white">
              {{ $t('ended.title') }}
            </h3>
            <p class="text-slate-400 text-base mb-10 font-medium">
              {{ $t('ended.desc') }}
            </p>
            <button @click="resetApp(true)"
              class="w-full py-6 bg-amber-500 text-slate-950 font-black rounded-2xl uppercase tracking-widest text-sm active:scale-95 transition-all shadow-xl shadow-amber-500/20">
              {{ $t('ended.back_home') }}
            </button>
          </div>
        </div>

        <!-- Receiver Active -->
        <div v-else-if="appState === STATES.RECEIVER_ACTIVE" 
          ref="receiverRoot"
          class="fixed inset-0 bg-black flex items-center justify-center overflow-hidden" 
          @mousemove="handleDragMove"
          @mouseup="handleDragEnd"
          @touchstart="handleDragStart($event, 'move-pip')"
          @touchmove="handleDragMove"
          @touchend="handleDragEnd">
          
          <div :class="['relative w-full h-full flex ease-in-out', 
                        layoutMode === 'side-by-side' ? 'p-2 gap-0' : '',
                        isDragging ? 'no-transition' : 'transition-all duration-500']">
            
            <!-- Stream A (Primary) - Only show in dual-stream mode -->
            <div v-if="cameraStream && screenStream"
                 :class="['relative overflow-hidden bg-slate-900 flex items-center justify-center', 
                          layoutMode === 'pip' ? 'w-full h-full' : 'rounded-2xl',
                          isDragging ? 'no-transition' : 'transition-all duration-500']"
                 :style="layoutMode === 'side-by-side' ? { width: (splitRatio * 100) + '%' } : (layoutMode === 'pip' && isSwapped ? 'order: 2' : '')">
              <video :ref="isSwapped ? 'cameraVideo' : 'screenVideo'" 
                     autoplay playsinline 
                     :muted="isMuted"
                     class="max-w-full max-h-full object-contain" />
              <div v-if="layoutMode === 'side-by-side'" class="absolute bottom-4 left-4 bg-black/50 backdrop-blur-sm px-2 py-1 rounded-lg text-[10px] font-bold text-white uppercase tracking-widest">
                {{ isSwapped ? 'Camera' : 'Screen' }}
              </div>
            </div>

            <!-- Splitter Bar (Only in side-by-side) -->
            <div v-if="layoutMode === 'side-by-side' && cameraStream && screenStream"
                 @mousedown="handleDragStart($event, 'splitter')"
                 @touchstart.passive="handleDragStart($event, 'splitter')"
                 class="w-2 hover:w-4 -mx-1 hover:-mx-2 z-30 cursor-col-resize flex items-center justify-center transition-all group">
              <div class="h-12 w-1 bg-white/20 rounded-full group-hover:bg-amber-500 transition-colors"></div>
            </div>

            <div v-if="cameraStream && screenStream"
                 :class="['overflow-hidden shadow-2xl group flex items-center justify-center', 
                          isDragging ? 'no-transition' : 'transition-all duration-500',
                          layoutMode === 'pip' ? 'absolute rounded-xl border border-white/20 cursor-move z-20 hover:border-amber-500/50' : 'relative rounded-2xl bg-slate-900']"
                 :style="layoutMode === 'pip' ? { 
                    left: pipPosition.x + 'px', 
                    top: pipPosition.y + 'px',
                    width: pipWidth + 'px',
                    height: 'auto',
                    order: isSwapped ? 1 : 2,
                    transition: isDragging ? 'none' : 'all 0.5s ease-in-out'
                 } : { width: ((1 - splitRatio) * 100) + '%' }"
                 @mousedown="handleDragStart($event, 'move-pip')"
                 @touchstart="handleDragStart($event, 'move-pip')">
              <video :ref="isSwapped ? 'screenVideo' : 'cameraVideo'" 
                     autoplay playsinline 
                     :muted="isMuted"
                     class="max-w-full max-h-full object-contain pointer-events-none" />
              
              <div v-if="layoutMode === 'side-by-side'" class="absolute bottom-4 left-4 bg-black/50 backdrop-blur-sm px-2 py-1 rounded-lg text-[10px] font-bold text-white uppercase tracking-widest">
                {{ isSwapped ? 'Screen' : 'Camera' }}
              </div>

              <!-- Resize Handle (Only in PiP) -->
              <div v-if="layoutMode === 'pip'" 
                   @mousedown.stop="handleDragStart($event, 'resize-pip')"
                   class="absolute bottom-0 right-0 w-8 h-8 cursor-nwse-resize flex items-end justify-end p-1 group/resize">
                <div class="w-4 h-4 text-white/40 group-hover/resize:text-amber-500 transition-colors">
                  <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="3" stroke-linecap="round" stroke-linejoin="round"><path d="M15 19l4-4M10 19l9-9"/></svg>
                </div>
              </div>

               <!-- Drag hint -->
               <div v-if="layoutMode === 'pip'" class="absolute top-2 right-2 p-1 bg-black/40 rounded-full opacity-0 group-hover:opacity-100 transition-opacity">
                 <Maximize class="w-3 h-3 text-white" />
               </div>
            </div>

            <!-- Fallback single stream -->
            <video v-if="!cameraStream || !screenStream" ref="remoteVideo" autoplay playsinline :muted="isMuted" class="w-full h-full object-contain" />

          </div>


          <!-- Bottom Interactive Area (100% width) -->
          <div class="absolute bottom-0 left-0 w-full h-48 z-40 group/controls"
               @mouseenter="showControls = true"
               @mouseleave="showControls = false">
            
            <!-- Unified Bottom Control Bar -->
            <Transition name="fade">
              <div v-if="showControls"
                class="absolute bottom-10 left-1/2 -translate-x-1/2 flex items-center gap-6 z-50 p-3 bg-black/60 backdrop-blur-2xl rounded-[2.5rem] border border-white/10 shadow-2xl pointer-events-auto">
                
                <!-- Left: Leave Button -->
                <button @click="resetApp"
                  class="flex items-center gap-2 px-5 py-3 bg-red-500 text-white rounded-full hover:bg-red-600 transition-all font-black text-xs uppercase tracking-widest active:scale-95">
                  <LogOut class="w-4 h-4" /> {{ $t('active.leave') }}
                </button>

                <div class="w-px h-8 bg-white/10"></div>

                <!-- Center: Primary Controls -->
                <div class="flex items-center gap-2">
                  <template v-if="cameraStream && screenStream">
                    <button @click="toggleLayout" title="Toggle Layout"
                      class="p-4 bg-white/5 rounded-full text-white hover:bg-amber-500 hover:text-slate-950 transition-all active:scale-95 group">
                      <Monitor v-if="layoutMode === 'pip'" class="w-6 h-6" />
                      <div v-else class="flex gap-0.5">
                        <div class="w-2.5 h-4 bg-current rounded-sm"></div>
                        <div class="w-2.5 h-4 bg-current rounded-sm"></div>
                      </div>
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

                  <!-- Receiver Mic Toggle -->
                  <button @click="toggleReceiverMic"
                    class="p-4 rounded-full transition-all active:scale-95 flex items-center gap-2 group"
                    :class="isReceiverMicActive ? 'bg-amber-500 text-slate-950' : 'bg-white/5 text-white hover:bg-white/10'">
                    <Mic v-if="isReceiverMicActive" class="w-6 h-6" />
                    <MicOff v-else class="w-6 h-6 opacity-60" />
                    <span v-if="isReceiverMicActive" class="text-[10px] font-black uppercase pr-2">{{ $t('receiver.mic') }}</span>
                  </button>
                </div>
              </div>
            </Transition>
          </div>
        </div>
      </Transition>
      
      <!-- Hidden Audio for Intercom (Sender side hears Receiver) -->
    <audio ref="receiverAudioElement" autoplay playsinline webkit-playsinline class="opacity-0 pointer-events-none absolute h-0 w-0"></audio>
    </main>

    <!-- Info Modal -->
    <div v-if="showInfo"
      class="fixed inset-0 z-[100] flex items-center justify-center p-6 bg-slate-950/90 backdrop-blur-xl"
      @click.self="showInfo = null">
      <div class="w-full max-w-lg bg-slate-900 border border-slate-800 rounded-[2.5rem] p-10 shadow-2xl relative">
        <button @click="showInfo = null"
          class="absolute top-8 right-8 text-slate-500 hover:text-white transition-colors">
          <X class="w-6 h-6" />
        </button>

        <div v-if="showInfo === 'source'">
          <div class="w-16 h-16 bg-amber-500/10 rounded-2xl flex items-center justify-center mb-6">
            <Globe class="w-8 h-8 text-amber-500" />
          </div>
          <h3 class="text-2xl font-black uppercase mb-4 tracking-tight text-white">{{ $t('info.source_title') }}</h3>
          <p class="text-slate-400 text-sm leading-relaxed mb-8">
            {{ $t('info.source_desc') }}
          </p>
          <a href="https://github.com/MinghuaLiu1977/castnow" target="_blank"
            class="inline-flex items-center gap-2 px-6 py-3 bg-amber-500 text-slate-950 font-black rounded-xl uppercase tracking-widest text-[10px] hover:scale-105 transition-transform active:scale-95">
            {{ $t('info.view_github') }}
          </a>
        </div>

        <div v-else-if="showInfo === 'support'">
          <div class="w-16 h-16 bg-amber-500/10 rounded-2xl flex items-center justify-center mb-6">
            <Info class="w-8 h-8 text-amber-500" />
          </div>
          <h3 class="text-2xl font-black uppercase mb-4 tracking-tight text-white">{{ $t('info.support_title') }}</h3>
          <p class="text-slate-400 text-sm leading-relaxed mb-6">
            {{ $t('info.support_desc') }}
          </p>
          <div class="space-y-4 mb-8 text-sm text-slate-300">
            <div class="flex items-start gap-3">
              <div class="w-5 h-5 mt-0.5 flex items-center justify-center bg-slate-800 rounded-full font-bold text-amber-500 text-[10px]">1</div>
              <span>{{ $t('info.support_item1') }}</span>
            </div>
            <div class="flex items-start gap-3">
              <div class="w-5 h-5 mt-0.5 flex items-center justify-center bg-slate-800 rounded-full font-bold text-amber-500 text-[10px]">2</div>
              <span>{{ $t('info.support_item2') }}</span>
            </div>
          </div>
          <div class="flex flex-wrap gap-4">
            <a href="mailto:mingh.liu@gmail.com" 
              class="inline-flex items-center gap-2 px-6 py-3 bg-amber-500 text-slate-950 font-black rounded-xl uppercase tracking-widest text-[10px] hover:scale-105 transition-transform active:scale-95">
              Email Support
            </a>
            <a href="https://github.com/MinghuaLiu1977/castnow/issues" target="_blank"
              class="inline-flex items-center gap-2 px-6 py-3 bg-slate-800 text-white font-black rounded-xl uppercase tracking-widest text-[10px] border border-slate-700 hover:bg-slate-700 transition-all active:scale-95">
              Github Issues
            </a>
          </div>
        </div>

        <div v-else-if="showInfo === 'privacy'">
          <div class="w-16 h-16 bg-amber-500/10 rounded-2xl flex items-center justify-center mb-6">
            <Activity class="w-8 h-8 text-amber-500" />
          </div>
          <h3 class="text-2xl font-black uppercase mb-4 tracking-tight text-white">{{ $t('info.privacy_title') }}</h3>
          <p class="text-slate-400 text-sm leading-relaxed mb-4">
            {{ $t('info.privacy_intro') }}
          </p>
          <ul class="text-slate-500 text-[11px] space-y-2 mb-8">
            <li>• {{ $t('info.privacy_item1') }}</li>
            <li>• {{ $t('info.privacy_item2') }}</li>
            <li>• {{ $t('info.privacy_item3') }}</li>
          </ul>
          <button @click="showInfo = null"
            class="w-full py-4 bg-slate-800 text-white font-black rounded-xl uppercase tracking-widest text-[10px] active:scale-95 transition-all">{{
              $t('info.close') }}</button>
        </div>

        <div v-else-if="showInfo === 'terms'">
          <div class="w-16 h-16 bg-amber-500/10 rounded-2xl flex items-center justify-center mb-6">
            <Info class="w-8 h-8 text-amber-500" />
          </div>
          <h3 class="text-2xl font-black uppercase mb-4 tracking-tight text-white">{{ $t('info.terms_title') }}</h3>
          <p class="text-slate-400 text-sm leading-relaxed mb-6">
            {{ $t('info.terms_desc') }}
          </p>
          <p class="text-slate-500 text-[11px] italic mb-8 border-l-2 border-amber-500/20 pl-4">
            {{ $t('info.terms_note') }}
          </p>
          <button @click="showInfo = null"
            class="w-full py-4 bg-slate-800 text-white font-black rounded-xl uppercase tracking-widest text-[10px] active:scale-95 transition-all">{{
              $t('info.agree_close') }}</button>
        </div>
      </div>
    </div>

    <!-- Pro Activation Modal Removed -->

    <!-- Toast Notification -->
    <Transition name="fade">
      <div v-if="toast.show"
        class="fixed bottom-10 left-1/2 -translate-x-1/2 z-[200] px-6 py-3 rounded-2xl shadow-2xl backdrop-blur-md border animate-in slide-in-from-bottom-5 duration-300"
        :class="{
          'bg-amber-500/90 text-slate-950 border-amber-400': toast.type === 'success',
          'bg-red-500/90 text-white border-red-400': toast.type === 'error',
          'bg-slate-800/90 text-white border-slate-700': toast.type === 'info'
        }">
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
.fade-enter-active,
.fade-leave-active {
  transition: all 0.4s cubic-bezier(0.4, 0, 0.2, 1);
}

.fade-enter-from {
  opacity: 0;
  transform: translateY(10px);
}

.fade-leave-to {
  opacity: 0;
  transform: translateY(-10px);
}

/* New Layout Transitions */
.grid {
  transition: all 0.5s cubic-bezier(0.16, 1, 0.3, 1);
}

video {
  transition: opacity 0.5s;
}

.no-transition, .no-transition * {
  transition: none !important;
}

.grid {
  transition: filter 0.3s ease;
}

.cursor-move:active {
  cursor: grabbing;
}

/* Ensure smooth transition for all layout-related classes */
.transition-all {
  transition-property: all;
  transition-timing-function: cubic-bezier(0.4, 0, 0.2, 1);
  transition-duration: 500ms;
}
</style>
