<template>
  <div class="symbol-latex-panel" :class="`symbol-mode-${active.key}`">
    <div class="symbol-nav">
      <button
        v-for="section in sections"
        :key="section.key"
        :class="{ active: current === section.key }"
        @click="current = section.key"
      >
        {{ section.label }}
      </button>
    </div>

    <div class="symbol-main">
      <div class="formula-board">
        <div class="formula-title">{{ active.title }}</div>
        <div class="formula-render notranslate" translate="no" v-html="render(active.formula)" />
        <p>{{ active.note }}</p>
      </div>

      <div class="symbol-grid">
        <div v-for="item in active.items" :key="item.math" class="symbol-item">
          <span class="symbol-math notranslate" translate="no" v-html="renderInline(item.math)" />
          <small>{{ item.text }}</small>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup>
import { computed, ref } from 'vue'
import katex from 'katex'
import 'katex/dist/katex.min.css'

const current = ref('sets')

const sections = [
  {
    key: 'sets',
    label: '集合',
    title: '集合与节点结构',
    formula: String.raw`I=\{1,\ldots,n\},\quad J=\{1,\ldots,m\},\quad V=A\cup P\cup D`,
    note: '把校园低空物流拆成无人机集合、订单集合和由起降点、取货点、配送点构成的节点集合。',
    items: [
      { math: String.raw`I`, text: '候选无人机集合，实验候选规模为 20 架' },
      { math: String.raw`J`, text: '订单集合，主场景 120 单，压力场景 300 单' },
      { math: String.raw`A,\ P,\ D`, text: '起降点、取货点、配送点集合' },
      { math: String.raw`R_i`, text: '无人机 i 的候选完整调度方案集合' },
    ],
  },
  {
    key: 'orders',
    label: '订单',
    title: '订单参数',
    formula: String.raw`j\in J:\quad (p_j,q_j,w_j,S_j,[a_j,b_j])`,
    note: '一个订单对应一次从取货点到配送点的配送需求；订单不可拆分，但可以在同一趟中与其他订单合并。',
    items: [
      { math: String.raw`p_j`, text: '订单 j 的取货节点' },
      { math: String.raw`q_j`, text: '订单 j 的配送节点' },
      { math: String.raw`w_j`, text: '订单 j 的重量' },
      { math: String.raw`S_j`, text: '订单 j 的可装载就绪时间' },
      { math: String.raw`[a_j,b_j]`, text: '订单 j 的服务时间窗' },
      { math: String.raw`L_j`, text: '订单晚到时产生的超时量' },
    ],
  },
  {
    key: 'params',
    label: '参数',
    title: '无人机与成本参数',
    formula: String.raw`W_i,\ E_i,\ v_i,\ F_i,\ \alpha,\ \gamma,\ \rho`,
    note: '这些参数进入统一评估器，用于同时评价载重、电量、飞行时间、启用成本和服务违约。',
    items: [
      { math: String.raw`W_i`, text: '无人机 i 的载重上限，实验中最大载重 2.5 kg' },
      { math: String.raw`E_i`, text: '无人机 i 的电池容量约束' },
      { math: String.raw`v_i`, text: '无人机 i 的巡航速度' },
      { math: String.raw`F_i`, text: '启用无人机 i 的固定成本' },
      { math: String.raw`\alpha`, text: '能耗成本权重，实验取 0.001' },
      { math: String.raw`\gamma,\ \rho`, text: '超时惩罚与换电惩罚系数' },
    ],
  },
  {
    key: 'vars',
    label: '变量',
    title: '覆盖矩阵与决策变量',
    formula: String.raw`A_{jr}\in\{0,1\},\quad x_i\in\{0,1\},\quad y_{ir}\in\{0,1\}`,
    note: '候选方案是否覆盖订单先被预计算；优化阶段只选择是否启用无人机，以及每架无人机采用哪个完整方案。',
    items: [
      { math: String.raw`A_{jr}`, text: '方案 r 是否覆盖订单 j' },
      { math: String.raw`x_i`, text: '无人机 i 是否启用' },
      { math: String.raw`y_{ir}`, text: '无人机 i 是否选择候选方案 r' },
      { math: String.raw`C_{ir}`, text: '方案 r 的综合运行成本' },
    ],
  },
  {
    key: 'model',
    label: '模型',
    title: '集合划分主模型',
    formula: String.raw`\begin{aligned}
\min\quad Z
&= \sum_{u\in\mathcal{I}}\sum_{r\in R_u} C_{ur}y_{ur}
  + \sum_{u\in\mathcal{I}} F_u x_u\\
\mathrm{s.t.}\quad
\sum_{u\in\mathcal{I}}\sum_{r\in R_u} A_{jr}y_{ur}
&= 1,\quad \forall j\in\mathcal{J}\\
\sum_{r\in R_u} y_{ur}
&\le x_u,\quad \forall u\in\mathcal{I}\\
x_u,\ y_{ur}
&\in \{0,1\},\quad \forall u\in\mathcal{I},\ r\in R_u
\end{aligned}`,
    note: 'PPT 中用 u 表示无人机索引，避免 i 与集合 I 在投影时混淆；含义仍对应论文中的无人机 i。',
    items: [
      { math: String.raw`C_{ur}`, text: '方案成本由能耗、超时、换电等组成' },
      { math: String.raw`A_{jr}y_{ur}`, text: '每个订单恰好被覆盖一次' },
      { math: String.raw`y_{ur}\le x_u`, text: '每架无人机最多选择一个完整方案' },
      { math: String.raw`x_u,y_{ur}\in\{0,1\}`, text: '启用和方案选择均为二元决策' },
    ],
  },
]

const active = computed(() => sections.find(section => section.key === current.value) || sections[0])

function render(source, displayMode = true) {
  return katex.renderToString(source, {
    displayMode,
    throwOnError: false,
    strict: false,
  })
}

function renderInline(source) {
  return render(source, false)
}

</script>
