const groups = {grove:['pip','fern','clover','maple'],ocean:['bubbles','shelly','inky','fin'],snow:['waddles','flurry','pebble','snowdrop']};
// Source rectangles measured from the transparent sheets. Per-row bounds keep
// ears, tails and feet intact despite small differences in generated spacing.
const frames = {
  grove:[[70,270,244,[160.5,474.5,777.5,1085]],[359,276,269,[181,495.5,801.5,1107.5]],[634,297,227,[169,483,790,1099.5]],[933,279,291,[183,497.5,805.5,1110.5]]],
  ocean:[[70,216,277,[161,475,788,1101.5]],[362,221,301,[157,471,784,1097.5]],[640,264,289,[165,478.5,792.5,1105.5]],[953,248,292,[168.5,481,794.5,1108]]],
  snow:[[72,258,279,[163,473.5,782.5,1091.5]],[359,281,292,[155.5,466.5,776,1086.5]],[680,224,302,[158,469.5,775.5,1085]],[917,302,259,[151.5,464,775.5,1085.5]]],
};
export const EXPRESSIONS = ['Thriving','Littered','Tarnished','Polluted'];
export const MOODS = {Thriving:'happy',Littered:'concerned',Tarnished:'sad',Polluted:'distressed'};
export const DROP_SOUNDS = {pip:'Peep!',fern:'Ribbit!',clover:'Squeak!',maple:'Yip!',bubbles:'Blub!',shelly:'Hiss!',inky:'Bloop!',fin:'Click-click!',waddles:'Honk!',flurry:'Yip-yip!',pebble:'Arf!',snowdrop:'Squeak-squeak!'};
export function expressionCell(id,condition) {
  const column = EXPRESSIONS.indexOf(condition);
  if (column < 0) return null;
  for (const [habitat,animals] of Object.entries(groups)) {
    const row = animals.indexOf(id);
    if (row >= 0) { const [y,height,width,centres] = frames[habitat][row]; return {habitat,row,column,rect:{x:Math.max(0,Math.min(1254 - width,centres[column] - width / 2)),y,width,height}}; }
  }
  return null;
}
