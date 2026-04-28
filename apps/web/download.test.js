import { describe, it, expect } from 'vitest';
import fs from 'fs';
import path from 'path';

describe('Download Links in App.vue', () => {
  it('should NOT contain Android APK download link', () => {
    const appVuePath = path.resolve(__dirname, 'App.vue');
    const content = fs.readFileSync(appVuePath, 'utf-8');
    
    // 验证不包含 APK 链接
    expect(content).not.toContain('href="/castnow.apk"');
    expect(content).not.toContain('Android APK');
  });

  it('should contain App Store download link', () => {
    const appVuePath = path.resolve(__dirname, 'App.vue');
    const content = fs.readFileSync(appVuePath, 'utf-8');
    
    // 验证包含 App Store 链接
    expect(content).toContain('href="https://apps.apple.com/us/app/castnow-pro/id6761016081"');
  });
});
