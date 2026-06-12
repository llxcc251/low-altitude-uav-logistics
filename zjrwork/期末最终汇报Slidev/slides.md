---
theme: default
title: 低空物流服务优化：期末最终汇报
info: |
  严格依据 论文模板/SYSU.palte.tex 重写的 Slidev 汇报版
class: text-left
transition: fade
mdc: true
canvasWidth: 1500
aspectRatio: 16/9
---

<CityDroneBackground />

<div class="w-8/12 pt-14 pl-4">
  <div class="brand-row">
    <img class="brand-mark" src="./public/assets/SYSU_emblem.png">
    <div>
      <div class="kicker">Operations Research Final Presentation</div>
      <div class="text-sm text-cyan-100/65 mt-1">严格依据 SYSU.palte.tex · 低空物流多无人机调度</div>
    </div>
  </div>
  <h1 class="mt-5">低空物流服务优化</h1>
  <h2 class="mt-3 !text-3xl !font-700">基于中山大学深圳校区的多无人机协同调度</h2>
  <p class="mt-7 text-xl w-10/12">
    研究多起降点、多取货点、多配送点、载重约束、电池约束和服务时间窗约束下的多无人机协同调度问题。
  </p>
  <div class="page-fill w-11/12">
    <div class="mini-card"><b>对象</b><span>9 个校园低空物流节点</span></div>
    <div class="mini-card"><b>数据</b><span>120 单主场景 + 300 单压力场景</span></div>
    <div class="mini-card"><b>方法</b><span>随机搜索基线 + 遗传算法优化</span></div>
  </div>
</div>

---

<CityDroneBackground />

<div class="glass-strong p-9 fit-panel fit-outline">
  <h2 class="mt-2">汇报目录</h2>
  <div class="grid grid-cols-3 gap-4 mt-8">
    <div class="metric"><span>01</span><b>引言</b><small>背景、问题、贡献、反馈改进</small></div>
    <div class="metric"><span>02</span><b>数据与场景构建</b><small>9 节点、订单、参数</small></div>
    <div class="metric"><span>03</span><b>问题描述与符号定义</b><small>I、J、V、R_i 与路线层级</small></div>
    <div class="metric"><span>04</span><b>数学模型</b><small>飞行时间、能耗、可行性、集合划分</small></div>
    <div class="metric"><span>05</span><b>算法设计与实现</b><small>编码、解码、随机搜索、GA</small></div>
    <div class="metric"><span>06</span><b>实验设计与结果分析</b><small>120 单、300 单、优化分解</small></div>
    <div class="metric"><span>07</span><b>模型选择与淘汰</b><small>保留随机搜索与遗传算法</small></div>
    <div class="metric"><span>08</span><b>前端可视化与系统实现</b><small>看板、地图、甘特图、解释面板</small></div>
    <div class="metric"><span>09</span><b>结论与展望</b><small>项目闭环与后续方向</small></div>
  </div>
  <p class="mt-7 text-lg">根据汇报大论文编排的此次汇报PPT</p>
</div>

---

<CityDroneBackground />

<div class="two-col fit-two">
  <div class="glass-strong p-8">
    <div class="kicker">01 引言</div>
    <h2 class="mt-2">研究背景、问题与贡献</h2>
    <p class="mt-5 text-lg">
      校园即时配送具有短距离、高频次、强时效、空间集中特征。项目核心不是“画出一条航线”，而是在多订单、多约束、多无人机协同条件下给出可执行、可解释、可复现的整体调度方案。
    </p>
    <div class="page-fill !grid-cols-2">
      <div class="mini-card"><b>研究问题</b><span>给定校园网络、机队参数和时间窗订单，决定启用无人机、订单分配、批次合并与多趟飞行。</span></div>
      <div class="mini-card"><b>反馈改进</b><span>补充集合规模、任务层级和“不拆单，只做订单合并/批次装载/多趟调度”的边界。</span></div>
      <div class="mini-card"><b>模型贡献</b><span>候选方案集合划分，表达覆盖、启用、载重、电量、时间窗和换电约束。</span></div>
      <div class="mini-card"><b>工程贡献</b><span>随机搜索与遗传算法求解器，前端展示低空走廊、路线和调度解释。</span></div>
    </div>
  </div>
  <img class="screenshot" src="./public/assets/color_check_0046.png">
</div>

---

<CityDroneBackground />

<div class="two-col fit-two fit-data">
  <div class="glass-strong p-8">
    <div class="kicker">02 数据与场景构建</div>
    <h2 class="mt-2">校园低空物流网络：9 个节点</h2>
    <p class="mt-5 text-lg">
      校园网络抽象为 2 个起降点、4 个取货点、3 个配送点；距离矩阵采用实际飞行走廊距离，而非单纯欧氏距离。
    </p>
    <NodeExplorer />
  </div>
  <div>
    <div class="grid grid-cols-2 gap-4">
      <img class="screenshot" src="./public/assets/SYSU_Shenzhen_model_real_map_check.png">
      <img class="screenshot" src="./public/assets/SYSU_Shenzhen_model_network_map_check.png">
    </div>
    <div class="page-fill">
      <div class="mini-card"><b>120 单</b><span>重量 0.30-1.49 kg，平均时间窗 19.4 min</span></div>
      <div class="mini-card"><b>300 单</b><span>重量 0.27-1.41 kg，平均时间窗 20.5 min</span></div>
      <div class="mini-card"><b>主要 OD</b><span>西园/东园食堂与东西宿舍、图书馆之间的高频流量</span></div>
    </div>
  </div>
</div>

---

<CityDroneBackground />

<div class="glass-strong p-9 fit-panel fit-symbols">
  <div class="kicker">03 问题描述与符号定义</div>
  <h2 class="mt-2">订单、趟次、调度方案的层级关系</h2>
  <div class="flow mt-7">
    <div>订单 j<br><small>p_j, q_j, w_j, S_j, [a_j,b_j]</small></div>
    <div>单趟路线<br><small>a → p → q → ... → a</small></div>
    <div>候选方案 R_i<br><small>同一无人机连续多趟</small></div>
    <div>集合划分<br><small>每个订单恰好覆盖一次</small></div>
  </div>
  <SymbolLatexPanel />
  <div class="constraint-strip">
    <div><b>不可拆单</b><span>单个订单不拆给多架无人机</span></div>
    <div><b>可合单</b><span>同一趟可合并若干订单</span></div>
    <div><b>可多趟</b><span>同一无人机可连续执行多趟</span></div>
  </div>
</div>

---

<CityDroneBackground />

<div class="two-col fit-two fit-model">
  <div class="glass-strong p-8">
    <div class="kicker">04 数学模型</div>
    <h2 class="mt-2">飞行时间、能耗、单趟可行性与集合划分</h2>
    <ProcessStepper mode="model" />
  </div>
  <div class="glass p-8">
    <h3 class="!text-2xl">目标函数口径</h3>
    <p class="mt-4">综合成本由四部分组成，所有算法通过统一评估器计算。</p>
    <div class="page-fill !grid-cols-2">
      <div class="mini-card"><b>启用成本</b><span>F = 2.0，由 0.5 起按 0.1 步长试调，综合启用规模、能耗与准时性后确定。</span></div>
      <div class="mini-card"><b>能耗成本</b><span>α = 0.001，将 Wh 折算到目标函数成本。</span></div>
      <div class="mini-card"><b>超时惩罚</b><span>γ = 10.0，对晚于时间窗的订单计罚。</span></div>
      <div class="mini-card"><b>换电惩罚</b><span>ρ = 0.1，并考虑 5 min 换电时间。</span></div>
    </div>
    <div class="insight mt-5"><strong>建模边界</strong><p>模型不把问题简化为最短路，而是把订单覆盖、起降点选择、批次装载、能耗、电量和时间窗统一评价。</p></div>
  </div>
</div>

---

<CityDroneBackground />

<div class="two-col fit-two fit-algorithm">
  <div class="glass-strong p-8">
    <div class="kicker">05 算法设计与实现</div>
    <h2 class="mt-2">分配染色体 → 队列装箱 → 严格仿真评估</h2>
    <ProcessStepper mode="algorithm" />
  </div>
  <div class="glass p-8">
    <h3 class="!text-2xl">最终保留两类算法</h3>
    <div class="page-fill !grid-cols-1">
      <div class="mini-card"><b>随机搜索基线</b><span>按重量排序的智能随机分配，对 1-20 架启用规模分别尝试 500 次，保留当前最低成本方案。</span></div>
      <div class="mini-card"><b>遗传算法主方法</b><span>种群 100、进化 500 代、锦标赛选择、均匀交叉、精英保留、0.15 概率变异。</span></div>
      <div class="mini-card"><b>统一评估器</b><span>所有候选解都被解码成具体批次、趟次和路线段，再计算成本、能耗、超时和启用数量。</span></div>
    </div>
  </div>
</div>

---

<CityDroneBackground />

<div class="glass-strong p-9 fit-panel fit-results">
  <div class="kicker">06 实验设计与结果分析</div>
  <h2 class="mt-2">点击切换 120 单与 300 单实验结果</h2>
  <ResultSwitcher />
  <div class="page-fill mt-6">
    <div class="mini-card"><b>实验设置</b><span>固定随机种子 2026，使结果差异主要来自搜索策略本身。</span></div>
    <div class="mini-card"><b>120 单解释</b><span>GA 启用 16 架而非 14 架，但减少 7302 Wh 并实现零超时。</span></div>
    <div class="mini-card"><b>300 单解释</b><span>两类算法均启用 20 架，GA 通过分配重组大幅压缩严重时间窗违约。</span></div>
  </div>
</div>

---

<CityDroneBackground />

<div class="glass-strong p-9 fit-panel fit-selection">
  <div class="kicker">07 模型选择与淘汰</div>
  <h2 class="mt-2">为什么最终只保留随机搜索与遗传算法</h2>
  <div class="grid grid-cols-5 gap-3 mt-7">
    <div class="mini-card"><b>MILP</b><span>理论清晰，但订单规模扩大后求解负担明显。</span></div>
    <div class="mini-card"><b>Clarke-Wright</b><span>局部距离改进明显，但对时间窗、电量、绕行不稳定。</span></div>
    <div class="mini-card"><b>最近邻</b><span>容易局部最优，把后续订单推入不合适时序。</span></div>
    <div class="mini-card"><b>单任务分配</b><span>无法体现批次合并和多趟复用，订单规模大时成本高。</span></div>
    <div class="mini-card"><b>固定批次</b><span>过早固定组合后，难以重新组织空间邻近、时间窗相容订单。</span></div>
  </div>
  <div class="flow mt-8">
    <div>小规模可接受</div>
    <div>120/300 单稳定</div>
    <div>统一评估器可解释</div>
    <div>最终保留：随机搜索 + GA</div>
  </div>
  <div class="insight mt-8"><strong>论文原文结论</strong><p>其他备选模型弃用的主要原因是早期效果不好：要么成本较高，要么超时较多，要么放大到主数据集后不够稳定。</p></div>
</div>

---

<CityDroneBackground />

<div class="frontend-slide fit-frontend">
  <img class="screenshot frontend-shot" src="./public/assets/frontend_live_screenshot.png">
  <div class="glass-strong frontend-card">
    <div class="kicker">08 前端可视化与系统实现</div>
    <h2 class="mt-2">模型输入、算法求解、结果解释在同一看板闭环</h2>
    <p class="mt-5">
      前端采用单页 HTML 看板，从 data 目录读取节点、订单、无人机参数、敏感性分析结果和算法输出。
    </p>
    <div class="page-fill !grid-cols-2">
      <div class="mini-card"><b>空间路径地图</b><span>展示起降点、取货点、配送点、载货段和空载段。</span></div>
      <div class="mini-card"><b>时间线甘特图</b><span>展示每架无人机多趟任务占用与完成时间。</span></div>
      <div class="mini-card"><b>算法对比</b><span>展示随机搜索与遗传算法的成本对照。</span></div>
      <div class="mini-card"><b>调度解释</b><span>每架无人机覆盖订单、累计重量和预计完成时间。</span></div>
    </div>
    <a class="link-button mt-5" href="https://banyanz.github.io/slidev/zjrwork/frontend/%E5%AE%9E%E9%AA%8C%E6%95%B0%E6%8D%AE%E9%9D%A2%E6%9D%BF.html" target="_blank">打开前端看板</a>
  </div>
</div>

---

<CityDroneBackground />

<div class="glass-strong p-9 fit-panel fit-conclusion">
  <div class="kicker">09 结论与展望</div>
  <h2 class="mt-2">从数据建模、数学规划、启发式求解到前端展示的闭环</h2>
  <div class="page-fill mt-7">
    <div class="mini-card"><b>结论 1</b><span>校园配送被抽象为带时间窗、载重和能耗约束的多无人机车辆路径问题。</span></div>
    <div class="mini-card"><b>结论 2</b><span>遗传算法在 120 单场景实现零超时并降低能耗，在 300 单压力场景显著降低成本和违约时间。</span></div>
    <div class="mini-card"><b>结论 3</b><span>前端可视化把模型结果从黑箱数字转为可被讨论的路线方案。</span></div>
  </div>
  <div class="grid grid-cols-4 gap-4 mt-8">
    <div class="metric"><span>展望 1</span><b>滚动优化</b><small>将全天订单切分连续时间片，实现实时派单。</small></div>
    <div class="metric"><span>展望 2</span><b>局部精修</b><small>加入 2-opt、跨无人机交换或大邻域搜索。</small></div>
    <div class="metric"><span>展望 3</span><b>空域模型</b><small>纳入高度、建筑障碍、起降坪容量和天气扰动。</small></div>
    <div class="metric"><span>展望 4</span><b>真实校准</b><small>接入真实订单和飞行日志，校准能耗与服务时间。</small></div>
  </div>
  <p class="mt-7 text-lg">一句话概括：项目将校园低空物流从“航线展示”推进到“可计算、可比较、可解释的调度方案”。</p>
</div>

---

<CityDroneBackground />

<div class="glass-strong p-9 fit-panel fit-team">
  <div class="kicker">小组任务分工</div>
  <h2 class="mt-2">论文原文分工口径</h2>
  <div class="grid grid-cols-2 gap-5 mt-8 text-lg">
    <div class="mini-card"><b>谢沛桦</b><span>数据建模、问题抽象、数学规划模型构建、遗传算法/随机搜索算法设计、飞行走廊初步设计。</span></div>
    <div class="mini-card"><b>朱家良</b><span>中深地图数据收集与处理，建立地图数据结构，配合完成飞行走廊最终设计。</span></div>
    <div class="mini-card"><b>王志轩</b><span>无人机参数收集、数学建模参数设计与优化，并参与算法设计和结果分析。</span></div>
    <div class="mini-card"><b>黄宇鑫</b><span>前端可视化系统设计与实现，包括地图展示、甘特图和交互控制台。</span></div>
    <div class="mini-card col-span-2"><b>张家榕</b><span>实验设计、结果分析和论文撰写，对中深地图进行数据收集与可视化设计，搭建 Blender 模型并优化前端网页。</span></div>
  </div>
</div>

---

<CityDroneBackground />

<div class="thanks-page">
  <div>
    <div class="rainbow-thanks">谢谢倾听</div>
    <div class="thanks-sub">低空物流服务优化 · 中山大学深圳校区多无人机协同调度</div>
  </div>
</div>
