// history.js — undo/redo, persistence, preview

import { canvas, syncBrush } from './canvas.js';
import { post } from './bridge.js';

let undoStack=[], redoStack=[], isRestoring=false;
const MAX_STACK=120, SAVE_MS=650;
let saveTimer=null;

const statusEl=document.getElementById('status');

function snapshot(){ return JSON.stringify(canvas.toJSON(['selectable','evented'])); }
function pushUndo(){
  if(isRestoring) return;
  const s=snapshot();
  if(undoStack.length&&undoStack[undoStack.length-1]===s) return;
  undoStack.push(s);
  if(undoStack.length>MAX_STACK) undoStack.shift();
  redoStack=[];
  updateUndoUI();
}
function restoreSnapshot(j){
  isRestoring=true;
  try{
    const o=JSON.parse(j);
    canvas.loadFromJSON(o,()=>{
      canvas.renderAll();
      canvas.calcOffset();
      requestAnimationFrame(()=>{ canvas.requestRenderAll(); isRestoring=false; });
    });
  }catch(e){ isRestoring=false; console.error(e); canvas.requestRenderAll(); }
}
export function undo(){
  if(undoStack.length<2) return;
  const cur=undoStack.pop(); redoStack.push(cur);
  const prev=undoStack[undoStack.length-1];
  if(prev){ restoreSnapshot(prev); }
  else { canvas.clear(); canvas.backgroundColor='#ffffff'; canvas.renderAll(); canvas.calcOffset(); requestAnimationFrame(()=>{ isRestoring=false; canvas.requestRenderAll(); }); }
  scheduleSave(true); updateUndoUI();
}
export function redo(){
  if(!redoStack.length) return;
  const s=redoStack.pop(); undoStack.push(s); restoreSnapshot(s); scheduleSave(true); updateUndoUI();
}
function updateUndoUI(){ /* no buttons now — keyboard only, but keep for future */ }

canvas.on('object:added',()=>{ if(!isRestoring){pushUndo(); scheduleSave();}});
canvas.on('object:removed',()=>{ if(!isRestoring){pushUndo(); scheduleSave();}});
canvas.on('object:modified',()=>{pushUndo(); scheduleSave();});
canvas.on('path:created',()=>{pushUndo(); scheduleSave();});
canvas.on('easel:text-created',()=>{pushUndo(); scheduleSave();});
canvas.on('easel:shape-created',()=>{pushUndo(); scheduleSave();});

document.addEventListener('keydown',e=>{
  const mod=e.metaKey||e.ctrlKey;
  if(mod&&e.key.toLowerCase()==='z'&&!e.shiftKey){e.preventDefault(); undo();}
  else if(mod&&(e.key.toLowerCase()==='y'||(e.key.toLowerCase()==='z'&&e.shiftKey))){e.preventDefault(); redo();}
  else if((e.key==='Delete'||e.key==='Backspace')&&!(e.target instanceof HTMLInputElement)&&!e.target.isContentEditable){
    const a=canvas.getActiveObjects(); if(a.length){e.preventDefault(); a.forEach(o=>canvas.remove(o)); canvas.discardActiveObject(); canvas.requestRenderAll();}
  }
  else if(mod&&e.key.toLowerCase()==='a'){e.preventDefault(); canvas.discardActiveObject(); const sel=new fabric.ActiveSelection(canvas.getObjects(),{canvas}); canvas.setActiveObject(sel); canvas.requestRenderAll();}
  else if(e.key==='v'&&!mod) { const cb=document.querySelector('[data-tool="select"]'); cb&&cb.click(); }
  else if(e.key==='p'&&!mod) { const cb=document.querySelector('[data-tool="pen"]'); cb&&cb.click(); }
  else if(e.key==='r'&&!mod) { const cb=document.querySelector('[data-tool="rect"]'); cb&&cb.click(); }
  else if(e.key==='t'&&!mod) { const cb=document.querySelector('[data-tool="text"]'); cb&&cb.click(); }
  else if(e.key==='a'&&!mod&&!e.metaKey) { const cb=document.querySelector('[data-tool="arrow"]'); cb&&cb.click(); }
});

function scheduleSave(f=false){ if(isRestoring) return; clearTimeout(scheduleSave._t); if(f) doSave(); else scheduleSave._t=setTimeout(doSave,SAVE_MS); }
function doSave(){
  try{
    const json=snapshot();
    post('easelChanged',{json});
    try{ const preview=canvas.toDataURL({format:'png', multiplier:0.18, quality:0.8}); post('easelPreviewChanged',{dataURL:preview}); }catch(e){}
  }catch(e){}
}
export function initHistory(){
  // initial push
  pushUndo();
}
export function loadEaselJson(j){
  if(!j){
    isRestoring=true;
    try{
      canvas.clear();
      canvas.backgroundColor='#ffffff';
      canvas.renderAll();
      canvas.calcOffset();
      undoStack=[snapshot()];
      redoStack=[];
    } finally { isRestoring=false; }
  } else {
    restoreSnapshot(j);
    // Make restored JSON the undo base after async load finishes
    setTimeout(()=>{ undoStack=[j]; redoStack=[]; }, 80);
  }
}
window.loadEasel = loadEaselJson;
window.easelSnapshot = snapshot;
window.easelUndo = undo;
window.easelRedo = redo;
window.pushUndo = pushUndo;
window.scheduleSave = scheduleSave;
