<template>
  <div class="node-explorer">
    <div class="node-tabs">
      <button
        v-for="tab in tabs"
        :key="tab.key"
        :class="{ active: current === tab.key }"
        @click="current = tab.key"
      >
        {{ tab.label }}
      </button>
    </div>
    <div class="node-body">
      <div class="node-list">
        <button
          v-for="node in filtered"
          :key="node.id"
          :class="{ active: selected.id === node.id }"
          @click="selected = node"
        >
          <b>{{ node.id }}</b>
          <span>{{ node.name }}</span>
        </button>
      </div>
      <div class="node-detail">
        <div class="node-pill">{{ selected.type }}</div>
        <h3>{{ selected.name }}</h3>
        <p>{{ selected.desc }}</p>
        <div class="node-meta">
          <span>x = {{ selected.x }} m</span>
          <span>y = {{ selected.y }} m</span>
        </div>
        <div class="node-note">{{ selected.note }}</div>
      </div>
    </div>
  </div>
</template>

<script setup>
import { computed, ref, watch } from 'vue'

const nodes = [
  { id: 'DEP_W', name: '西区无人机起降点', type: '起降点', group: 'depot', x: 260, y: 430, desc: '西区侧起降与换电能力节点。', note: '承担西区近距离订单与跨区订单的起飞/返回。' },
  { id: 'DEP_E', name: '东区无人机起降点', type: '起降点', group: 'depot', x: 1060, y: 880, desc: '东区侧起降与换电能力节点。', note: '与西区起降点共同降低空载绕飞。' },
  { id: 'CANTEEN_W', name: '西园食堂', type: '取货点', group: 'pickup', x: 525, y: 520, desc: '西区主要取货源。', note: '对西园宿舍、东园宿舍和图书馆均有订单流。' },
  { id: 'CANTEEN_E', name: '东园食堂', type: '取货点', group: 'pickup', x: 1125, y: 920, desc: '东区主要取货源。', note: '东区内部流量稳定，也存在东西区跨区配送。' },
  { id: 'RESTAURANT_X', name: '相山餐厅', type: '取货点', group: 'pickup', x: 720, y: 715, desc: '位于校园中部的取货点。', note: '在东西区与图书馆需求中起到连接作用。' },
  { id: 'GATE_S', name: '东南门服务点', type: '取货点', group: 'pickup', x: 800, y: 160, desc: '校门区域临时服务点。', note: '用于刻画校外/门岗类即时取货需求。' },
  { id: 'DORM_W', name: '西园宿舍区', type: '配送点', group: 'delivery', x: 267, y: 768, desc: '西区宿舍配送目的地。', note: '西区内部配送与东区跨区配送同时存在。' },
  { id: 'DORM_E', name: '东园宿舍区', type: '配送点', group: 'delivery', x: 1240, y: 1080, desc: '东区宿舍配送目的地。', note: '压力场景中跨区流量明显。' },
  { id: 'LIB', name: '图书馆学习区', type: '配送点', group: 'delivery', x: 640, y: 865, desc: '学习区配送目的地。', note: '与食堂、餐厅形成午晚高峰学习区需求。' },
]

const tabs = [
  { key: 'all', label: '全部 9 节点' },
  { key: 'depot', label: '起降点 2' },
  { key: 'pickup', label: '取货点 4' },
  { key: 'delivery', label: '配送点 3' },
]

const current = ref('all')
const selected = ref(nodes[0])
const filtered = computed(() => current.value === 'all' ? nodes : nodes.filter(n => n.group === current.value))

watch(current, () => {
  selected.value = filtered.value[0]
})
</script>
