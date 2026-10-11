export const HABITATS = [
  { id: 'grove', name: 'Willow Grove', detail: 'A sunlit home for woodland friends.' },
  { id: 'ocean', name: 'Coral Cove', detail: 'A turquoise reef with a curious ocean crew.' },
  { id: 'snow', name: 'Snow Glade', detail: 'A snowy clearing for cozy little explorers.' },
];
export const ANIMALS = [
  ['pip','Pip',0,'grove','Your very first woodland friend.'],
  ['fern','Fern',1,'grove','A little frog who loves clean ponds.'],
  ['clover','Clover',3,'grove','Looking for a peaceful patch of grass.'],
  ['maple','Maple',6,'grove','A shy visitor who loves a healthy grove.'],
  ['bubbles','Bubbles',0,'ocean','A tiny clownfish with a big sense of adventure.'],
  ['shelly','Shelly',1,'ocean','A gentle sea turtle who loves a healthy reef.'],
  ['inky','Inky',3,'ocean','Eight arms, endless hugs.'],
  ['fin','Fin',6,'ocean','A playful dolphin who follows the bubbles.'],
  ['waddles','Waddles',0,'snow','Your cheerful guide to the snowy glade.'],
  ['flurry','Flurry',1,'snow','An arctic fox with warm little paws.'],
  ['pebble','Pebble',3,'snow','A round seal who loves a cozy snowbank.'],
  ['snowdrop','Snowdrop',6,'snow','A snow hare with springy feet.'],
].map(([id,name,required,habitat,detail]) => ({id,name,required,habitat,detail}));
export const DECORATIONS = [
  ['flowers','Wildflowers',40,'grove',.16,.73,.14],
  ['mushrooms','Mushroom nook',60,'grove',.86,.66,.13],
  ['house','Little hideaway',100,'grove',.21,.51,.20],
  ['bench','Woodland bench',50,'grove',.75,.71,.19],
  ['lantern','Firefly lantern',35,'grove',.82,.56,.14],
  ['fernPlant','Fern patch',25,'grove',.21,.63,.14],
  ['coral','Peach coral',40,'ocean',.18,.67,.18],
  ['pearl','Pearl hideaway',60,'ocean',.80,.71,.17],
  ['sandcastle','Sandcastle',90,'ocean',.28,.59,.21],
  ['igloo','Tiny igloo',90,'snow',.20,.58,.22],
  ['snowman','Snow buddy',40,'snow',.79,.66,.16],
  ['spruce','Frosted spruce',55,'snow',.17,.71,.18],
].map(([id,name,cost,habitat,x,y,scale]) => ({id,name,cost,habitat,x,y,scale}));
export const FOODS = [
  {id:'berries',name:'Berry basket',cost:5,habitats:['grove']},
  {id:'kelp',name:'Kelp bites',cost:5,habitats:['ocean']},
  {id:'crunch',name:'Star crunch',cost:8,habitats:['grove','ocean','snow']},
  {id:'apple',name:'Apple snack',cost:4,habitats:['grove','snow']},
];
