import { ref, computed } from 'vue';

export function useLayout() {
  const layoutMode = ref('pip');
  const isSwapped = ref(false);
  const pipPosition = ref({ x: 20, y: 20 });
  const pipWidth = ref(320);
  const splitRatio = ref(0.5);
  const dragType = ref(null);
  const isDragging = ref(false);
  const dragOffset = ref({ x: 0, y: 0 });
  const isMuted = ref(false);

  let pendingDragUpdate = false;

  const isTouchDevice = computed(() => {
    if (typeof window === 'undefined') return false;
    return 'ontouchstart' in window || navigator.maxTouchPoints > 0;
  });

  const isMobile = computed(() => {
    if (typeof navigator === 'undefined') return false;
    return /Android|webOS|iPhone|iPad|iPod|BlackBerry|IEMobile|Opera Mini/i.test(navigator.userAgent);
  });

  const toggleLayout = () => {
    layoutMode.value = layoutMode.value === 'pip' ? 'side-by-side' : 'pip';
  };

  const swapStreams = () => {
    isSwapped.value = !isSwapped.value;
  };

  const handleDragStart = (e, type = 'move-pip') => {
    if (layoutMode.value === 'side-by-side' && type !== 'splitter') return;

    isDragging.value = true;
    dragType.value = type;

    const clientX = e.type.includes('touch') ? e.touches[0].clientX : e.clientX;
    const clientY = e.type.includes('touch') ? e.touches[0].clientY : e.clientY;

    if (type === 'move-pip') {
      dragOffset.value = {
        x: clientX - pipPosition.value.x,
        y: clientY - pipPosition.value.y,
      };
    } else if (type === 'resize-pip') {
      dragOffset.value = {
        x: clientX,
        width: pipWidth.value,
      };
    } else if (type === 'splitter') {
      dragOffset.value = { x: clientX };
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
          y: clientY - dragOffset.value.y,
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

  const toggleFullscreen = (receiverRoot) => {
    if (!document.fullscreenElement && receiverRoot) {
      receiverRoot.requestFullscreen().catch((err) => console.log(err));
    } else if (document.fullscreenElement) {
      document.exitFullscreen();
    }
  };

  return {
    layoutMode,
    isSwapped,
    pipPosition,
    pipWidth,
    splitRatio,
    dragType,
    isDragging,
    dragOffset,
    isMuted,
    isTouchDevice,
    isMobile,
    toggleLayout,
    swapStreams,
    handleDragStart,
    handleDragMove,
    handleDragEnd,
    toggleMute,
    toggleFullscreen,
  };
}
