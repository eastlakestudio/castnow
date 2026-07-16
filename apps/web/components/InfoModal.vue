<template>
  <div v-if="visible"
    class="fixed inset-0 z-[100] flex items-center justify-center p-6 bg-slate-950/90 backdrop-blur-xl"
    @click.self="$emit('close')">
    <div class="w-full max-w-lg backdrop-blur-xl bg-slate-900/80 border border-white/10 rounded-[2.5rem] p-10 shadow-2xl relative">
      <button @click="$emit('close')" class="absolute top-8 right-8 text-slate-500 hover:text-white transition-colors">
        <X class="w-6 h-6" />
      </button>

      <!-- Source Info -->
      <div v-if="visible === 'source'">
        <div class="w-16 h-16 bg-cyan-500/10 rounded-2xl flex items-center justify-center mb-6">
          <Globe class="w-8 h-8 text-cyan-400" />
        </div>
        <h3 class="text-2xl font-black uppercase mb-4 tracking-tight text-white">Source Code</h3>
        <p class="text-slate-400 text-sm leading-relaxed mb-8">CastNow is an open-source high-performance P2P engine. The source code is available on GitHub under the MIT license for community contributions and transparency.</p>
        <a href="https://github.com/MinghuaLiu1977/castnow" target="_blank"
          class="inline-flex items-center gap-2 px-6 py-3 bg-cyan-500 text-slate-950 font-black rounded-xl uppercase tracking-widest text-[10px] hover:scale-105 transition-transform active:scale-95">
          View on GitHub
        </a>
      </div>

      <!-- Support -->
      <div v-else-if="visible === 'support'">
        <div class="w-16 h-16 bg-cyan-500/10 rounded-2xl flex items-center justify-center mb-6">
          <Info class="w-8 h-8 text-cyan-400" />
        </div>
        <h3 class="text-2xl font-black uppercase mb-4 tracking-tight text-white">Support &amp; Contact</h3>
        <p class="text-slate-400 text-sm leading-relaxed mb-6">Having trouble or have questions? We're here to help. CastNow is a community-driven project dedicated to private P2P communication.</p>
        <div class="space-y-4 mb-8 text-sm text-slate-300">
          <div class="flex items-start gap-3">
            <div class="w-5 h-5 mt-0.5 flex items-center justify-center bg-slate-800 rounded-full font-bold text-cyan-400 text-[10px]">1</div>
            <span>Email us directly for technical support or feedback.</span>
          </div>
          <div class="flex items-start gap-3">
            <div class="w-5 h-5 mt-0.5 flex items-center justify-center bg-slate-800 rounded-full font-bold text-cyan-400 text-[10px]">2</div>
            <span>Report bugs or request features via our GitHub repository.</span>
          </div>
        </div>
        <div class="flex flex-wrap gap-4">
          <a href="mailto:mingh.liu@gmail.com" class="inline-flex items-center gap-2 px-6 py-3 bg-cyan-500 text-slate-950 font-black rounded-xl uppercase tracking-widest text-[10px] hover:scale-105 transition-transform active:scale-95">Email Support</a>
          <a href="https://github.com/MinghuaLiu1977/castnow/issues" target="_blank" class="inline-flex items-center gap-2 px-6 py-3 bg-slate-800 text-white font-black rounded-xl uppercase tracking-widest text-[10px] border border-slate-700 hover:bg-slate-700 transition-all active:scale-95">Github Issues</a>
        </div>
      </div>

      <!-- Privacy -->
      <div v-else-if="visible === 'privacy'">
        <div class="w-16 h-16 bg-cyan-500/10 rounded-2xl flex items-center justify-center mb-6">
          <Activity class="w-8 h-8 text-cyan-400" />
        </div>
        <h3 class="text-2xl font-black uppercase mb-4 tracking-tight text-white">Privacy Policy</h3>
        <p class="text-slate-400 text-sm leading-relaxed mb-4">We value your privacy. CastNow utilizes direct **End-to-End Peer-to-Peer** connections.</p>
        <ul class="text-slate-500 text-[11px] space-y-2 mb-8">
          <li>• Your stream data never touches our servers.</li>
          <li>• No recordings are stored or processed by us.</li>
          <li>• We do not collect or sell personal demographic data.</li>
        </ul>
        <button @click="$emit('close')" class="w-full py-4 bg-slate-800 text-white font-black rounded-xl uppercase tracking-widest text-[10px] active:scale-95 transition-all">Close</button>
      </div>

      <!-- Terms -->
      <div v-else-if="visible === 'terms'">
        <div class="w-16 h-16 bg-cyan-500/10 rounded-2xl flex items-center justify-center mb-6">
          <Info class="w-8 h-8 text-cyan-400" />
        </div>
        <h3 class="text-2xl font-black uppercase mb-4 tracking-tight text-white">Terms of Service</h3>
        <p class="text-slate-400 text-sm leading-relaxed mb-6">By using CastNow, you agree that you are solely responsible for the content you broadcast.</p>
        <p class="text-slate-500 text-[11px] italic mb-8 border-l-2 border-cyan-500/20 pl-4">The service is provided 'as is' without warranties of any kind. Misuse of the platform for illegal activities will result in termination of service availability.</p>
        <button @click="$emit('close')" class="w-full py-4 bg-slate-800 text-white font-black rounded-xl uppercase tracking-widest text-[10px] active:scale-95 transition-all">Agree &amp; Close</button>
      </div>
    </div>
  </div>
</template>

<script setup>
import { X, Globe, Info, Activity } from 'lucide-vue-next';

defineProps({
  visible: { type: String, default: null },
});

defineEmits(['close']);
</script>
