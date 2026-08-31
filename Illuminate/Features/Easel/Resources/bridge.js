const bridge = () => window.webkit?.messageHandlers?.easelBridge;
export function post(type, payload={}){ try{ bridge()?.postMessage({type, ...payload}); }catch(e){ console.warn('bridge post failed',e); } }
export function notifyReady(){ post('easelReady',{}); }

// hi
// im bored
// why is this so dificult
// JS sucks.
// WEB DEVELOPERS WHERE??