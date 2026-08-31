// canvas.js — Fabric setup, tools, shapes, pan/zoom, cursors

import { post } from './bridge.js';

export const wrap = document.getElementById('canvas-wrap');
export const canvas = new fabric.Canvas('c', { backgroundColor:'#ffffff', selection:true, preserveObjectStacking:true });

export function resizeCanvas(){
  const w=wrap.clientWidth, h=wrap.clientHeight;
  if(canvas.setDimensions) canvas.setDimensions({width:w,height:h});
  else { canvas.setWidth(w); canvas.setHeight(h); }
  canvas.requestRenderAll();
}
resizeCanvas();
window.addEventListener('resize', resizeCanvas);

export let currentTool='select';
let isPanning=false, lastPan={x:0,y:0};

const strokeEl=document.getElementById('strokeColor');
const widthEl=document.getElementById('strokeWidth');
const widthVal=document.getElementById('widthValue');

export function curStroke(){ return strokeEl?strokeEl.value:'#1a1a1a'; }
export function curWidth(){ return widthEl?parseInt(widthEl.value,10):3; }
export function getP(e){ if(canvas['getPointer']) return canvas['getPointer'](e); if(canvas['getScenePoint']) return canvas['getScenePoint'](e); return {x:e.clientX,y:e.clientY}; }

function makePencil(){
  const b=new fabric.PencilBrush(canvas);
  b.color=curStroke(); b.width=curWidth(); b.strokeLineCap='round'; b.strokeLineJoin='round';
  return b;
}
export function syncBrush(){
  const color=curStroke(), w=curWidth();
  if(canvas.freeDrawingBrush){ canvas.freeDrawingBrush.color=color; canvas.freeDrawingBrush.width=w; }
  const a=canvas.getActiveObject();
  if(a){
    if(a.type==='activeSelection'){ a.forEachObject(o=>{ if(o.stroke) o.set('stroke',color); if(o.strokeWidth!==undefined) o.set('strokeWidth',w); });}
    else { if(a.stroke!==undefined) a.set('stroke',color); if(a.strokeWidth!==undefined) a.set('strokeWidth',w); }
    canvas.requestRenderAll();
  }
}
if(widthEl && widthVal) widthEl.addEventListener('input', ()=>{ widthVal.textContent=widthEl.value; syncBrush(); });
if(strokeEl) strokeEl.addEventListener('change', syncBrush);

export function setTool(t){
  currentTool=t;
  document.querySelectorAll('.tool').forEach(el=>el.classList.toggle('active',el.dataset.tool===t));
  canvas.isDrawingMode=(t==='pen');
  if(t==='pen') canvas.freeDrawingBrush=makePencil();
  const cursors={select:'default', pen:'crosshair', rect:'crosshair', arrow:'crosshair', text:'text'};
  const def=cursors[t]||'default';
  canvas.defaultCursor=def;
  canvas.hoverCursor=(t==='select'?'move':def);
  canvas.moveCursor='move';
  canvas.requestRenderAll();
  return currentTool;
}
export function getTool(){ return currentTool; }
document.querySelectorAll('[data-tool]').forEach(b=>b.addEventListener('click',()=>setTool(b.dataset.tool)));

let shapeStart=null, activeShape=null;
export function isPanningActive(){ return isPanning; }

canvas.on('mouse:down', opt=>{
  const e=opt.e;
  if(e.button===2||e.which===3||e.altKey||e.button===1){ isPanning=true; lastPan={x:e.clientX,y:e.clientY}; canvas.defaultCursor='grabbing'; canvas.selection=false; if(e.button===2) e.preventDefault(); return; }
  if(currentTool==='select'||currentTool==='pen') return;
  if(currentTool==='text'){
    const p=getP(opt.e); const t=new fabric.Textbox('Text',{left:p.x,top:p.y,width:220,fontSize:18,fontFamily:'-apple-system',fill:curStroke(),editable:true});
    canvas.add(t); canvas.setActiveObject(t); canvas.requestRenderAll();
    // must be imported from history.js, but we emit event
    canvas.fire('easel:text-created');
    setTimeout(()=>{ t.enterEditing(); try{ t.selectAll(); if(t.hiddenTextarea) t.hiddenTextarea.select(); }catch(_){ try{ t.selectionStart=0; t.selectionEnd=t.text.length; t._updateTextarea(); }catch(_){} } },50);
    return;
  }
  const p=getP(opt.e); shapeStart=p;
  const common={left:p.x,top:p.y,stroke:curStroke(),strokeWidth:curWidth(),fill:null,selectable:false,evented:false};
  if(currentTool==='rect') activeShape=new fabric.Rect({...common,width:0,height:0,rx:6,ry:6});
  else if(currentTool==='arrow') activeShape=new fabric.Line([p.x,p.y,p.x,p.y],{stroke:curStroke(),strokeWidth:curWidth(),selectable:false,evented:false});
  if(activeShape) canvas.add(activeShape);
});
canvas.on('mouse:move', opt=>{
  if(isPanning){ const e=opt.e, vpt=canvas.viewportTransform; vpt[4]+=e.clientX-lastPan.x; vpt[5]+=e.clientY-lastPan.y; canvas.requestRenderAll(); lastPan={x:e.clientX,y:e.clientY}; return; }
  if(!shapeStart||!activeShape) return;
  const p=getP(opt.e), w=p.x-shapeStart.x, h=p.y-shapeStart.y;
  if(currentTool==='rect'){ activeShape.set({width:Math.abs(w),height:Math.abs(h),left:w<0?p.x:shapeStart.x,top:h<0?p.y:shapeStart.y});}
  else if(currentTool==='arrow'){ activeShape.set({x2:p.x,y2:p.y}); }
  canvas.requestRenderAll();
});
canvas.on('mouse:up', ()=>{
  if(isPanning){ isPanning=false; canvas.selection=(currentTool==='select'); const c={select:'default', pen:'crosshair', rect:'crosshair', arrow:'crosshair', text:'text'}; canvas.defaultCursor=c[currentTool]||'default'; return; }
  if(activeShape){
    activeShape.set({selectable:true,evented:true});
    if(currentTool==='arrow'&&activeShape.type==='line'){
      const x1=activeShape.x1,y1=activeShape.y1,x2=activeShape.x2,y2=activeShape.y2,ang=Math.atan2(y2-y1,x2-x1), hl=14,
        p1={x:x2-hl*Math.cos(ang-Math.PI/6),y:y2-hl*Math.sin(ang-Math.PI/6)},
        p2={x:x2-hl*Math.cos(ang+Math.PI/6),y:y2-hl*Math.sin(ang+Math.PI/6)},
        head=new fabric.Polygon([{x:x2,y:y2},p1,p2],{fill:curStroke(),stroke:curStroke(),strokeWidth:1,selectable:false});
      const g=new fabric.Group([activeShape,head],{selectable:true});
      canvas.remove(activeShape); canvas.add(g); canvas.setActiveObject(g);
    } else canvas.setActiveObject(activeShape);
    activeShape=null; shapeStart=null;
    canvas.fire('easel:shape-created');
  }
});
canvas.upperCanvasEl.addEventListener('contextmenu', e=>{ if(isPanning||e.button===2) e.preventDefault(); });

let spaceDown=false;
window.addEventListener('keydown',e=>{ if(e.code==='Space'&&!spaceDown){spaceDown=true; canvas.defaultCursor='grab';}});
window.addEventListener('keyup',e=>{ if(e.code==='Space'){spaceDown=false; const c={select:'default',pen:'crosshair',rect:'crosshair',arrow:'crosshair',text:'text'}; canvas.defaultCursor=c[currentTool]||'default';}});

wrap.addEventListener('wheel',e=>{
  if(e.ctrlKey||e.metaKey){ e.preventDefault(); const d=e.deltaY>0?0.92:1.08, p={x:e.offsetX,y:e.offsetY}, z=canvas.getZoom()*d; canvas.zoomToPoint(new fabric.Point(p.x,p.y), Math.min(4,Math.max(0.2,z))); }
  else if(spaceDown||e.altKey){ const vpt=canvas.viewportTransform; vpt[4]-=e.deltaX; vpt[5]-=e.deltaY; canvas.requestRenderAll(); }
},{passive:false});
wrap.addEventListener('gesturestart', e=>e.preventDefault());
wrap.addEventListener('gesturechange', e=>{
  e.preventDefault();
  const rect=wrap.getBoundingClientRect();
  const p={x:e.clientX-rect.left, y:e.clientY-rect.top};
  const z=canvas.getZoom()*e.scale;
  canvas.zoomToPoint(new fabric.Point(p.x,p.y), Math.min(4,Math.max(0.2,z)));
});
