export const clamp = (n,min,max) => Math.max(min,Math.min(max,n));
export function boundsFor(area,size,ground = area.y + area.height) {
  const mx = Math.min(size * .65,area.width / 2), my = Math.min(size * .65,area.height / 2);
  return {left:area.x + mx,right:area.x + area.width - mx,top:area.y + my,bottom:clamp(ground,area.y + my,area.y + area.height - my)};
}
export const bounded = (p,b) => ({x:clamp(p.x,b.left,b.right),y:clamp(p.y,b.top,b.bottom)});
export const settle = (p,b) => ({...bounded(p,b),y:b.bottom,vx:0,vy:0,grounded:true});
export const drop = (p,v,b) => ({...bounded(p,b),vx:clamp(v.x,-320,320),vy:clamp(v.y,-420,420),grounded:false});
export function stepBody(body,seconds,b,gravity = 1450) {
  if (body.grounded || !Number.isFinite(seconds) || seconds <= 0) return body;
  let n = {...body}, left = Math.min(seconds,.1);
  while (left > 0 && !n.grounded) {
    const dt = Math.min(left,1 / 120); left -= dt;
    n.vy += gravity * dt; n.vx *= Math.exp(-1.4 * dt);
    n.x += n.vx * dt; n.y += n.vy * dt;
    if (n.x < b.left || n.x > b.right) { n.x = clamp(n.x,b.left,b.right); n.vx *= -.3; }
    if (n.y < b.top) { n.y = b.top; n.vy = Math.max(0,n.vy); }
    if (n.y >= b.bottom) {
      n.y = b.bottom;
      if (n.vy > 100) { n.vy *= -.24; n.vx *= .55; } else n = settle(n,b);
    }
  }
  return n;
}
export function walk(body,target,speed,seconds,b) {
  if (!body.grounded || !Number.isFinite(seconds) || seconds <= 0 || !Number.isFinite(target)) return body;
  return settle({...body,x:body.x + clamp(clamp(target,b.left,b.right) - body.x,-speed * Math.min(seconds,.1),speed * Math.min(seconds,.1))},b);
}
