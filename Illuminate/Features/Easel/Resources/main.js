import { post } from './bridge.js';
import { setTool } from './canvas.js';
import { initHistory } from './history.js';

// Init after modules load — ensures window.loadEasel is defined before Swift posts easelReady
setTool('select');
initHistory();
console.log('[Easel] main.js (thin) loaded — requesting easel');
post('easelReady', {});
