export const MAX_HABITAT_ANIMALS = 4;

export function residentSpriteSize(area,desiredSize,residentCount) {
  const count = Math.max(1,Math.min(MAX_HABITAT_ANIMALS,residentCount));
  // Each resident needs its 1.56× collision width plus room to wander.
  return Math.min(desiredSize,area.width / (count * 2.1),area.height / 2.8);
}

export function selectHabitatResidents(animals,{habitat,actionCount,litter,hiddenAnimals = [],ignoreRetreat = false}) {
  return animals.filter(a => a.habitat === habitat && actionCount >= a.required && !hiddenAnimals.includes(a.id) &&
    (litter < 5 || a.required === 0 || ignoreRetreat)).slice(0,MAX_HABITAT_ANIMALS);
}
