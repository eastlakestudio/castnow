<template>
  <div class="flex-1 flex flex-col items-center justify-center p-6">
    <h2 class="text-2xl font-black uppercase mb-12 tracking-widest flex items-center gap-3">
      <span class="w-8 h-[2px] bg-cyan-500"></span>Choose Source<span class="w-8 h-[2px] bg-cyan-500"></span>
    </h2>
    <div class="w-full max-w-2xl space-y-6">
      <div class="grid grid-cols-1 md:grid-cols-2 gap-6 w-full">
        <button @click="$emit('toggleSource', 'screen')"
          class="flex flex-col items-center gap-6 p-10 bg-slate-900 border rounded-[2.5rem] transition-all group relative overflow-hidden backdrop-blur-sm"
          :class="selectedSources.includes('screen') ? 'border-cyan-500 bg-cyan-500/5 shadow-[0_0_40px_-10px_rgba(6,182,212,0.2)]' : 'border-slate-800 border-dashed hover:border-slate-600 hover:bg-slate-800/30'">
          <div class="w-20 h-20 bg-slate-950 rounded-3xl flex items-center justify-center group-hover:scale-110 transition-transform shadow-xl">
            <Monitor class="w-10 h-10" :class="selectedSources.includes('screen') ? 'text-cyan-400' : 'text-slate-600'" />
          </div>
          <div class="text-center">
            <span class="block font-black uppercase tracking-[0.2em] text-sm mb-1" :class="selectedSources.includes('screen') ? 'text-cyan-400' : 'text-slate-600'">Screen Share</span>
            <span class="block text-[9px] font-bold text-slate-500 uppercase tracking-widest opacity-60">High Quality Stream</span>
          </div>
          <div v-if="selectedSources.includes('screen')" class="absolute top-6 right-6 text-cyan-400"><CheckCircle2 class="w-6 h-6 fill-cyan-400/10" /></div>
        </button>
        <button @click="$emit('toggleSource', 'camera')"
          class="flex flex-col items-center gap-6 p-10 bg-slate-900 border rounded-[2.5rem] transition-all group relative overflow-hidden backdrop-blur-sm"
          :class="selectedSources.includes('camera') ? 'border-cyan-500 bg-cyan-500/5 shadow-[0_0_40px_-10px_rgba(6,182,212,0.2)]' : 'border-slate-800 border-dashed hover:border-slate-600 hover:bg-slate-800/30'">
          <div class="w-20 h-20 bg-slate-950 rounded-3xl flex items-center justify-center group-hover:scale-110 transition-transform shadow-xl">
            <Camera class="w-10 h-10" :class="selectedSources.includes('camera') ? 'text-cyan-400' : 'text-slate-600'" />
          </div>
          <div class="text-center">
            <span class="block font-black uppercase tracking-[0.2em] text-sm mb-1" :class="selectedSources.includes('camera') ? 'text-white' : 'text-slate-600'">Camera</span>
            <span class="block text-[9px] font-bold text-slate-500 uppercase tracking-widest opacity-60">Live Video Feed</span>
          </div>
          <div v-if="selectedSources.includes('camera')" class="absolute top-6 right-6 text-cyan-400"><CheckCircle2 class="w-6 h-6 fill-cyan-400/10" /></div>
        </button>
      </div>

      <button @click="$emit('toggleSource', 'mic')"
        class="w-full flex items-center justify-between px-8 py-5 bg-slate-900 border rounded-[1.5rem] transition-all group relative overflow-hidden backdrop-blur-sm"
        :class="selectedSources.includes('mic') ? 'border-cyan-500 bg-cyan-500/5' : 'border-slate-800 border-dashed hover:border-slate-600'">
        <div class="flex items-center gap-5">
          <div class="w-10 h-10 bg-slate-950 rounded-xl flex items-center justify-center group-hover:scale-110 transition-transform shadow-lg">
            <Volume2 v-if="selectedSources.includes('mic')" class="w-5 h-5 text-cyan-400" />
            <VolumeX v-else class="w-5 h-5 text-slate-600" />
          </div>
          <div class="text-left">
            <span class="block font-black uppercase tracking-widest text-xs" :class="selectedSources.includes('mic') ? 'text-white' : 'text-slate-500'">Microphone</span>
            <span class="block text-[8px] font-bold text-slate-500 uppercase tracking-tighter opacity-50">Sync audio from your device</span>
          </div>
        </div>
        <div class="flex items-center gap-3">
          <span class="text-[10px] font-black uppercase tracking-widest" :class="selectedSources.includes('mic') ? 'text-cyan-400' : 'text-slate-600'">{{ selectedSources.includes('mic') ? 'ON' : 'OFF' }}</span>
          <div class="w-10 h-5 bg-slate-950 rounded-full border border-slate-800 p-1 relative transition-colors" :class="{ 'bg-cyan-500/20 border-cyan-500/50': selectedSources.includes('mic') }">
            <div class="w-3 h-3 rounded-full bg-slate-700 transition-all duration-300 transform" :class="selectedSources.includes('mic') ? 'translate-x-5 bg-cyan-500 shadow-[0_0_10px_rgba(6,182,212,0.5)]' : 'translate-x-0'"></div>
          </div>
        </div>
      </button>
    </div>

    <div class="mt-12 flex flex-col items-center gap-6">
      <button @click="$emit('startBroadcast')"
        class="px-12 py-4 bg-cyan-500 text-slate-950 font-black rounded-2xl uppercase tracking-widest hover:scale-105 active:scale-95 transition-all shadow-xl shadow-cyan-500/20">
        Start Broadcasting
      </button>
      <button @click="$emit('navigate', 'LANDING')"
        class="text-slate-500 font-black uppercase tracking-widest text-[10px] hover:text-white transition-colors">
        ← Cancel Operation
      </button>
    </div>
  </div>
</template>

<script setup>
import { Monitor, Camera, CheckCircle2, Volume2, VolumeX } from 'lucide-vue-next';

defineProps({
  selectedSources: { type: Array, required: true },
});

defineEmits(['toggleSource', 'startBroadcast', 'navigate']);
</script>
