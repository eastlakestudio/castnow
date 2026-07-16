
import { createApp } from 'vue';
import App from './App.vue';
import './style.css';

const app = createApp(App);
app.mount('#root');

// PWA Service Worker Registration
if ('serviceWorker' in navigator) {
  window.addEventListener('load', () => {
    // Register from root /sw.js which Vite serves from public/sw.js
    navigator.serviceWorker.register('/sw.js')
      .then(reg => console.log('Service Worker registered', reg))
      .catch(err => console.error('Service Worker registration failed', err));
  });
}
