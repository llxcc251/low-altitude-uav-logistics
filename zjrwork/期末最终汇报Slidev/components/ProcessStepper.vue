<template>
  <div class="process-stepper">
    <div class="process-rail">
      <button
        v-for="(step, idx) in steps"
        :key="step.title"
        :class="{ active: active === idx }"
        @click="active = idx"
      >
        <span>{{ idx + 1 }}</span>
        {{ step.title }}
      </button>
    </div>
    <div class="process-panel">
      <div class="process-tag">{{ current.tag }}</div>
      <h3>{{ current.title }}</h3>
      <p>{{ current.detail }}</p>
      <ul>
        <li v-for="item in current.points" :key="item">{{ item }}</li>
      </ul>
    </div>
  </div>
</template>

<script setup>
import { computed, ref } from 'vue'

const props = defineProps({
  mode: {
    type: String,
    default: 'algorithm',
  },
})

const bank = {
  algorithm: [
    { title: '加载数据', tag: '输入', detail: '读取校园节点、订单、距离矩阵和无人机参数。', points: ['节点集合 V = A ∪ P ∪ D', '订单集合 J 包含重量、就绪时间与服务时间窗'] },
    { title: '分配编码', tag: '搜索变量', detail: '用订单分配向量表示每个订单由哪架无人机执行。', points: ['染色体长度等于订单数', '随机搜索与 GA 使用一致解表达'] },
    { title: '队列装箱', tag: '解码', detail: '按就绪时间排序，在载重上限内形成多趟飞行。', points: ['单趟最多 3 单', '每趟检查 2.5 kg 载重约束'] },
    { title: '逐段仿真', tag: '评估', detail: '计算空载、载货、服务、等待、换电和超时。', points: ['统一评估口径', '输出成本、能耗、超时、启用数量'] },
    { title: '迭代更新', tag: '优化', detail: '遗传算法通过选择、交叉、变异重组订单分配片段。', points: ['种群 100、进化 500 代', '锦标赛选择、精英保留、0.15 变异'] },
  ],
  model: [
    { title: '飞行时间', tag: 't_uv', detail: '由飞行走廊距离和巡航速度计算段时间。', points: ['距离采用实际飞行走廊', '速度 v = 15 m/s'] },
    { title: '能耗计算', tag: 'e0/e1', detail: '基础能耗与载重附加能耗共同决定电量消耗。', points: ['e0 = 0.1 Wh/m', 'e1 = 0.01 Wh/(m·kg)'] },
    { title: '单趟可行', tag: 'route', detail: '每趟飞行必须同时满足载重、电池和时间窗。', points: ['Wmax = 2.5 kg', 'Emax = 1000 Wh'] },
    { title: '集合划分', tag: 'master', detail: '从候选方案集合中选择，使每个订单被恰好覆盖一次。', points: ['覆盖约束保证订单不拆分', '启用约束刻画固定成本'] },
  ],
}

const active = ref(0)
const steps = computed(() => bank[props.mode] || bank.algorithm)
const current = computed(() => steps.value[active.value])
</script>
