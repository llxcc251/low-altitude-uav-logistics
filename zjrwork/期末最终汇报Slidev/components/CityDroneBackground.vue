<template>
  <div class="city-bg" aria-hidden="true">
    <div class="sky-grid"></div>
    <div class="moon"></div>
    <div class="flight-lane lane-a"></div>
    <div class="flight-lane lane-b"></div>
    <div class="flight-lane lane-c"></div>

    <div class="building-layer rear">
      <span v-for="b in rearBuildings" :key="`r-${b.left}`" class="building" :style="buildingStyle(b)">
        <i v-for="n in b.windows" :key="n"></i>
      </span>
    </div>
    <div class="building-layer front">
      <span v-for="b in frontBuildings" :key="`f-${b.left}`" class="building" :style="buildingStyle(b)">
        <i v-for="n in b.windows" :key="n"></i>
      </span>
    </div>

    <div class="drone drone-one">
      <span class="beam"></span>
      <span class="body"></span>
      <span class="arm left"></span>
      <span class="arm right"></span>
      <span class="rotor left"></span>
      <span class="rotor right"></span>
    </div>
    <div class="drone drone-two small">
      <span class="beam"></span>
      <span class="body"></span>
      <span class="arm left"></span>
      <span class="arm right"></span>
      <span class="rotor left"></span>
      <span class="rotor right"></span>
    </div>
    <div class="drone drone-three tiny">
      <span class="beam"></span>
      <span class="body"></span>
      <span class="arm left"></span>
      <span class="arm right"></span>
      <span class="rotor left"></span>
      <span class="rotor right"></span>
    </div>
  </div>
</template>

<script setup>
const rearBuildings = [
  { left: 2, width: 8, height: 34, delay: 0, windows: 14 },
  { left: 13, width: 6, height: 42, delay: 2, windows: 16 },
  { left: 23, width: 9, height: 31, delay: 4, windows: 12 },
  { left: 37, width: 7, height: 45, delay: 1, windows: 18 },
  { left: 51, width: 10, height: 36, delay: 3, windows: 14 },
  { left: 67, width: 7, height: 48, delay: 5, windows: 18 },
  { left: 80, width: 9, height: 39, delay: 2, windows: 15 },
  { left: 92, width: 6, height: 44, delay: 4, windows: 17 },
]

const frontBuildings = [
  { left: -1, width: 9, height: 25, delay: 1, windows: 10 },
  { left: 9, width: 10, height: 29, delay: 4, windows: 12 },
  { left: 21, width: 7, height: 22, delay: 0, windows: 9 },
  { left: 30, width: 11, height: 32, delay: 2, windows: 14 },
  { left: 45, width: 8, height: 26, delay: 3, windows: 10 },
  { left: 56, width: 12, height: 35, delay: 1, windows: 15 },
  { left: 71, width: 8, height: 24, delay: 5, windows: 10 },
  { left: 82, width: 11, height: 31, delay: 2, windows: 13 },
  { left: 94, width: 8, height: 27, delay: 4, windows: 10 },
]

function buildingStyle(b) {
  return {
    left: `${b.left}%`,
    width: `${b.width}%`,
    height: `${b.height}%`,
    '--delay': `${b.delay}s`,
  }
}
</script>

