<template>
  <div class="result-switcher">
    <div class="switch-row">
      <button :class="{ active: scene === 's120' }" @click="scene = 's120'">120 单主场景</button>
      <button :class="{ active: scene === 's300' }" @click="scene = 's300'">300 单压力场景</button>
    </div>
    <div class="result-grid">
      <div class="result-card baseline">
        <span>随机搜索</span>
        <b>{{ data.random.cost }}</b>
        <small>启用 {{ data.random.drones }} 架 · 能耗 {{ data.random.energy }} Wh · 超时 {{ data.random.late }} min</small>
        <div class="result-bar"><i :style="{ width: randomWidth }"></i></div>
      </div>
      <div class="result-card optimized">
        <span>遗传算法</span>
        <b>{{ data.ga.cost }}</b>
        <small>启用 {{ data.ga.drones }} 架 · 能耗 {{ data.ga.energy }} Wh · 超时 {{ data.ga.late }} min</small>
        <div class="result-bar"><i :style="{ width: gaWidth }"></i></div>
      </div>
    </div>
    <div class="insight">
      <strong>{{ data.headline }}</strong>
      <p>{{ data.note }}</p>
    </div>
  </div>
</template>

<script setup>
import { computed, ref } from 'vue'

const scene = ref('s120')
const results = {
  s120: {
    random: { cost: 65.1, drones: 14, energy: 34121, late: 15.6 },
    ga: { cost: 58.8, drones: 16, energy: 26819, late: 0.0 },
    headline: '成本降低 9.7%，并消除全部超时',
    note: 'GA 并非单纯减少机队规模，而是在启用数量、能耗和准时性之间取得更优综合权衡。',
  },
  s300: {
    random: { cost: 663.6, drones: 20, energy: 87605, late: 3206.7 },
    ga: { cost: 121.2, drones: 20, energy: 79913, late: 5.9 },
    headline: '成本降低 81.7%，超时压缩约 99.8%',
    note: '在压力场景中，两类算法均启用 20 架无人机，差异主要来自订单分配结构与任务链组织。',
  },
}

const data = computed(() => results[scene.value])
const maxCost = computed(() => Math.max(data.value.random.cost, data.value.ga.cost))
const randomWidth = computed(() => `${Math.max(8, data.value.random.cost / maxCost.value * 100)}%`)
const gaWidth = computed(() => `${Math.max(8, data.value.ga.cost / maxCost.value * 100)}%`)
</script>
