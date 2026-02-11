// @vitest-environment jsdom
import { describe, it, expect, vi, beforeEach } from 'vitest';
import { getInitialLocale, setLocale } from './i18n.js';

// Mock browser globals
const localStorageMock = {
    getItem: vi.fn(),
    setItem: vi.fn(),
    removeItem: vi.fn(),
};

vi.stubGlobal('localStorage', localStorageMock);
vi.stubGlobal('navigator', { language: 'en-US' });
vi.stubGlobal('document', {
    documentElement: {
        lang: '',
    },
});

describe('i18n logic', () => {
    beforeEach(() => {
        vi.clearAllMocks();
        vi.stubGlobal('navigator', { language: 'en-US' });
    });

    it('should detect system language as Chinese', () => {
        vi.stubGlobal('navigator', { language: 'zh-CN' });
        localStorageMock.getItem.mockReturnValue(null);

        expect(getInitialLocale()).toBe('zh');
    });

    it('should detect system language as English', () => {
        vi.stubGlobal('navigator', { language: 'en-GB' });
        localStorageMock.getItem.mockReturnValue(null);

        expect(getInitialLocale()).toBe('en');
    });

    it('should use stored language preference', () => {
        localStorageMock.getItem.mockReturnValue('zh');

        expect(getInitialLocale()).toBe('zh');
    });

    it('should update storage and document lang on setLocale', () => {
        setLocale('zh');

        expect(localStorageMock.setItem).toHaveBeenCalledWith('locale', 'zh');
        expect(document.documentElement.lang).toBe('zh');
    });
});
