/** @type {import('tailwindcss').Config} */
export default {
  content: [
    "./index.html",
    "./App.vue",
    "./main.js",
    "./components/**/*.vue",
    "./composables/**/*.js"
  ],
  theme: {
    extend: {
      fontFamily: {
        sans: ['Inter', 'sans-serif'],
      },
    },
  },
  plugins: [],
}