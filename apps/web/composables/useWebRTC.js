import { ref, watch } from 'vue';

export function useWebRTC(getIceServers) {
  const peerId = ref('');
  const peerInstance = ref(null);
  const isConnecting = ref(false);
  const error = ref(null);
  const activeConnections = ref([]);
  const remoteDeviceInfo = ref('');
  const lastReceiverInfo = ref('');

  // Receiver state
  const joinCode = ref('');
  const remoteStream = ref(null);
  const screenStream = ref(null);
  const cameraStream = ref(null);
  const screenVideo = ref(null);
  const cameraVideo = ref(null);
  const remoteVideo = ref(null);
  const remoteRoot = ref(null);

  // Intercom state
  const isReceiverMicActive = ref(false);
  const receiverMicStream = ref(null);
  const receiverAudioStream = ref(null);
  const receiverAudioElement = ref(null);
  const activeReceiverCall = ref(null);
  const activeTalkbackCall = ref(null);

  // Free trial
  const freeTrialUsed = ref(false);
  const isPro = ref(true);

  let sessionInterval = null;

  // Watch intercom audio
  watch([receiverAudioElement, receiverAudioStream], ([el, stream]) => {
    if (el && stream) {
      el.srcObject = stream;
      el.muted = false;
      el.volume = 1.0;
      el.play().then(() => {
        console.log('🔊 [WEBRTC] Intercom audio playback started successfully');
      }).catch(e => {
        console.error('❌ [WEBRTC] Broadcaster audio playback failed (Auto-play policy?):', e);
      });
    }
  });

  const setupRemoteVideo = async (el, stream) => {
    if (!el || !stream) return;
    if (el.srcObject === stream) return;
    el.srcObject = stream;
    el.setAttribute('playsinline', 'true');
    el.setAttribute('webkit-playsinline', 'true');
    try {
      await el.play();
    } catch (err) {
      if (err.name !== 'AbortError') {
        console.warn('📥 Play failed:', err);
      }
    }
  };

  watch([screenVideo, screenStream], ([el, stream]) => setupRemoteVideo(el, stream));
  watch([cameraVideo, cameraStream], ([el, stream]) => setupRemoteVideo(el, stream));
  watch([remoteVideo, remoteStream], ([el, stream]) => {
    if (el && stream && (!screenStream.value || !cameraStream.value)) {
      setupRemoteVideo(el, stream);
    }
  });

  const getOS = () => {
    const ua = navigator.userAgent;
    if (/Windows/i.test(ua)) return 'Windows';
    if (/Mac/i.test(ua)) return 'macOS';
    if (/Linux/i.test(ua)) return 'Linux';
    if (/Android/i.test(ua)) return 'Android';
    if (/iPhone|iPad|iPod/i.test(ua)) return 'iOS';
    return 'System';
  };

  const getBrowser = () => {
    const ua = navigator.userAgent;
    if (/Chrome/i.test(ua)) return 'Chrome';
    if (/Safari/i.test(ua) && !/Chrome/i.test(ua)) return 'Safari';
    if (/Firefox/i.test(ua)) return 'Firefox';
    if (/Edg/i.test(ua)) return 'Edge';
    return 'Browser';
  };

  const handlePeerError = (err, showFirefoxGuideRef) => {
    console.error('PeerJS Error:', err);
    if (err.type === 'unavailable-id') {
      error.value = 'Code collision. Please try again.';
    } else if (err.type === 'network') {
      error.value = 'Network error. Check connection/firewall.';
    } else if (err.type === 'browser-incompatible' || (err.message && err.message.includes('not support WebRTC'))) {
      if (showFirefoxGuideRef) showFirefoxGuideRef.value = true;
      error.value = null;
      return;
    } else {
      error.value = `Connection failed. Check code.: ${err.message}`;
    }
    isConnecting.value = false;
  };

  const setupCallHandlers = (call) => {
    call.on('stream', (rs) => {
      if (rs.getAudioTracks().length > 0) {
        receiverAudioStream.value = rs;
      }
    });

    if (call.peerConnection) {
      call.peerConnection.ontrack = (event) => {
        if (event.track.kind === 'audio') {
          const stream = event.streams[0] || new MediaStream([event.track]);
          receiverAudioStream.value = stream;
        }
      };
    }

    call.on('error', (err) => {
      console.error('Call Error:', err);
    });

    call.on('close', () => {
      activeConnections.value = activeConnections.value.filter(c => c.peer !== call.peer);
    });
  };

  const startSenderPeer = (code, localStream, showFirefoxGuideRef, showToast, setAppState, STATES) => {
    const peer = new window.Peer(code, {
      debug: 1,
      config: {
        iceServers: getIceServers(),
        sdpSemantics: 'unified-plan',
      },
    });

    peerInstance.value = peer;
    peer.on('open', (id) => {
      peerId.value = id;
      isConnecting.value = false;
    });

    peer.on('call', (incomingCall) => {
      if (incomingCall.peer.startsWith('cnv_')) {
        const parts = incomingCall.peer.split('_');
        if (parts.length >= 3) {
          lastReceiverInfo.value = `${parts[1]} on ${parts[2]}`;
        }
      }

      if (incomingCall.metadata && !lastReceiverInfo.value) {
        const payload = incomingCall.metadata;
        if (payload && payload.type === 'dev') {
          lastReceiverInfo.value = `${payload.browser || 'Browser'} on ${payload.os}`;
        }
      }

      incomingCall.close();

      setTimeout(() => {
        if (!localStream.value) return;
        const forwardCall = peer.call(incomingCall.peer, localStream.value);
        setupCallHandlers(forwardCall);
      }, 1000);
    });

    peer.on('error', (err) => handlePeerError(err, showFirefoxGuideRef));
  };

  const startReceiverPeer = (code, setAppState, STATES, showToast) => {
    const browser = getBrowser().replace(/\s+/g, '');
    const os = getOS().replace(/\s+/g, '');
    const randomPart = Math.random().toString(36).substring(7);
    const richId = `cnv_${browser}_${os}_${randomPart}`;

    const peer = new window.Peer(richId, {
      config: {
        iceServers: getIceServers(),
        sdpSemantics: 'unified-plan',
      },
    });

    peerInstance.value = peer;

    peer.on('open', (id) => {
      const knockCall = peer.call(code, receiverMicStream.value || new MediaStream());

      const timeout = setTimeout(() => {
        if (setAppState.value !== STATES.RECEIVER_ACTIVE) {
          isConnecting.value = false;
          error.value = 'Connection failed. Check code.';
        }
      }, 10000);

      knockCall.on('error', (err) => {
        clearTimeout(timeout);
        error.value = 'Connection failed. Check code.';
        isConnecting.value = false;
      });
    });

    peer.on('call', (call) => {
      activeReceiverCall.value = call;
      setAppState(STATES.RECEIVER_ACTIVE);
      isConnecting.value = false;

      call.answer(receiverMicStream.value || undefined);

      call.on('close', () => {
        // Will be handled by resetApp callback
      });

      call.on('stream', (rs) => {
        if (call.peerConnection) {
          call.peerConnection.oniceconnectionstatechange = () => {
            const state = call.peerConnection.iceConnectionState;
            if (['disconnected', 'failed', 'closed'].includes(state)) {
              // Will be handled by resetApp callback
            }
          };

          call.peerConnection.ontrack = () => {
            updateSplitStreams(call);
          };
        }

        const checkAllTracksEnded = () => {
          if (!rs) return;
          const liveTracks = rs.getTracks().filter(t => t.readyState === 'live');
          if (liveTracks.length === 0) {
            // Will be handled by resetApp callback
          }
        };

        rs.getTracks().forEach(track => {
          track.onended = () => checkAllTracksEnded();
        });

        updateSplitStreams(call);
        setTimeout(() => updateSplitStreams(call), 1000);
        setTimeout(() => updateSplitStreams(call), 2500);

        rs.getTracks().forEach(t => { t.enabled = true; });
      });
    });

    peer.on('error', (err) => {
      handlePeerError(err, null);
      joinCode.value = '';
    });
  };

  const updateSplitStreams = (call) => {
    const currentStream = call.remoteStream;
    if (!currentStream) return;

    const videoTracks = currentStream.getVideoTracks();
    const audioTracks = currentStream.getAudioTracks();

    if (videoTracks.length > 0) {
      screenStream.value = new MediaStream([videoTracks[0], ...audioTracks]);
    }

    if (videoTracks.length > 1) {
      cameraStream.value = new MediaStream([videoTracks[1]]);
    } else {
      cameraStream.value = null;
      remoteStream.value = new MediaStream(currentStream.getTracks());
    }
  };

  const toggleReceiverMic = async (showToastFn) => {
    if (!receiverMicStream.value) {
      showToastFn('Microphone access denied', 'error');
      return;
    }
    isReceiverMicActive.value = !isReceiverMicActive.value;
    receiverMicStream.value.getAudioTracks().forEach(t => {
      t.enabled = isReceiverMicActive.value;
    });
    if (isReceiverMicActive.value) {
      showToastFn('Microphone ON', 'success');
    } else {
      showToastFn('Microphone OFF', 'info');
    }
  };

  const closeActiveCalls = () => {
    if (activeReceiverCall.value) {
      try {
        activeReceiverCall.value.close();
      } catch (e) {
        console.warn('Call close failed (likely already gone)', e);
      }
      activeReceiverCall.value = null;
    }
  };

  const destroyPeer = () => {
    if (peerInstance.value) {
      peerInstance.value.destroy();
      peerInstance.value = null;
    }
    if (sessionInterval) {
      clearInterval(sessionInterval);
      sessionInterval = null;
    }
  };

  const cleanUpStreams = () => {
    const streams = [
      remoteStream.value,
      screenStream.value,
      cameraStream.value,
      receiverMicStream.value,
      receiverAudioStream.value,
    ];
    streams.forEach(s => {
      if (s && s.getTracks) {
        s.getTracks().forEach(t => t.stop());
      }
    });
  };

  const resetState = () => {
    peerId.value = '';
    remoteStream.value = null;
    screenStream.value = null;
    cameraStream.value = null;
    activeReceiverCall.value = null;
    joinCode.value = '';
    isConnecting.value = false;
    error.value = null;
    lastReceiverInfo.value = '';
    remoteDeviceInfo.value = '';
    receiverAudioStream.value = null;
  };

  const persistTrial = () => {
    if (!isPro.value && !freeTrialUsed.value) {
      freeTrialUsed.value = true;
      localStorage.setItem('free_trial_used', 'true');
    }
  };

  return {
    peerId,
    peerInstance,
    isConnecting,
    error,
    activeConnections,
    remoteDeviceInfo,
    lastReceiverInfo,
    joinCode,
    remoteStream,
    screenStream,
    cameraStream,
    screenVideo,
    cameraVideo,
    remoteVideo,
    isReceiverMicActive,
    receiverMicStream,
    receiverAudioStream,
    receiverAudioElement,
    activeReceiverCall,
    activeTalkbackCall,
    freeTrialUsed,
    isPro,
    setupCallHandlers,
    startSenderPeer,
    startReceiverPeer,
    toggleReceiverMic,
    closeActiveCalls,
    destroyPeer,
    cleanUpStreams,
    resetState,
    persistTrial,
    getOS,
    getBrowser,
    handlePeerError,
  };
}
