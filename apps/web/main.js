
import { createApp } from 'vue';
import App from './App.vue';
import i18n from './i18n';
import './style.css'; // Ensure CSS is imported for Vite to process

const app = createApp(App);
app.use(i18n);
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
