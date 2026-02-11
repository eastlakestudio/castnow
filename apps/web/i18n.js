import { createI18n } from 'vue-i18n';
import en from './locales/en.json';
import zh from './locales/zh.json';

const messages = {
    en,
    zh,
};

// Get initial locale from localStorage or system language
export const getInitialLocale = () => {
    const savedLocale = localStorage.getItem('locale');
    if (savedLocale) return savedLocale;

    const systemLocale = navigator.language || 'en';
    return systemLocale.toLowerCase().includes('zh') ? 'zh' : 'en';
};

const initialLocale = getInitialLocale();
document.documentElement.lang = initialLocale;

const i18n = createI18n({
    legacy: false, // Use Composition API
    locale: initialLocale,
    fallbackLocale: 'en',
    messages,
});

export default i18n;

export const setLocale = (locale) => {
    i18n.global.locale.value = locale;
    localStorage.setItem('locale', locale);
    document.documentElement.lang = locale;
};
