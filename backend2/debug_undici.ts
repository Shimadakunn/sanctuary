import { Agent, Dispatcher } from 'undici';
console.log('Undici Agent:', Agent);
console.log('Undici Dispatcher:', Dispatcher);
const agent = new Agent();
console.log('Agent compose?', (agent as any).compose);
console.log('Dispatcher compose?', (Dispatcher as any).compose);
try {
    const { CookieAgent } = require('http-cookie-agent/dist/undici/cookie_agent');
    console.log('CookieAgent loaded');
} catch (e) {
    console.error('Error loading CookieAgent:', e);
}
