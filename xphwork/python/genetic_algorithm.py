# genetic_algorithm.py - 遗传算法

import random
from eval_solution import eval_solution
from random_search import random_search, build_sol

def genetic_algorithm(data, cfg):
    """
    遗传算法求解无人机配送路径优化
    种群并行搜索 + 交叉重组，比SA搜索范围更广
    """
    n_drones = cfg.n_drones
    m = data.n_orders

    # === GA 参数 ===
    pop_size = 100       # 种群大小
    n_gen = 500          # 迭代代数
    pc = 0.85            # 交叉概率
    pm = 0.15            # 变异概率
    elite_ratio = 0.05   # 精英比例
    tournament_k = 5     # 锦标赛选择大小

    # === 初始化种群 ===
    pop = []
    fitness = []

    # 第1个：随机搜索的最优解
    seed_sol = random_search(data, cfg, 200)
    pop.append(sol_to_assignment(seed_sol, n_drones, m))
    fitness.append(calc_fitness(pop[0], data, cfg))

    # 其余：随机生成可行解
    for p in range(1, pop_size):
        pop.append(random_assignment(n_drones, m))
        fitness.append(calc_fitness(pop[p], data, cfg))

    print(f"  GA: pop={pop_size}, gen={n_gen}")

    best_fitness = float('inf')
    best_ever = pop[0][:]

    # === 迭代 ===
    for gen in range(1, n_gen + 1):
        # 精英保留
        n_elite = max(1, int(pop_size * elite_ratio))
        sorted_idx = sorted(range(pop_size), key=lambda i: fitness[i])
        new_pop = []
        new_fit = []

        for e in range(n_elite):
            new_pop.append(pop[sorted_idx[e]][:])
            new_fit.append(fitness[sorted_idx[e]])

        # 生成剩余个体
        for p in range(n_elite, pop_size):
            # 锦标赛选择父代
            p1 = tournament_select(pop, fitness, tournament_k)
            p2 = tournament_select(pop, fitness, tournament_k)

            # 交叉
            if random.random() < pc:
                child = crossover(p1, p2, n_drones)
            else:
                child = p1[:]

            # 变异
            if random.random() < pm:
                child = mutate(child, n_drones, m)

            new_pop.append(child)
            new_fit.append(calc_fitness(child, data, cfg))

        pop = new_pop
        fitness = new_fit

        # 更新全局最优
        gen_best_idx = min(range(pop_size), key=lambda i: fitness[i])
        if fitness[gen_best_idx] < best_fitness:
            best_fitness = fitness[gen_best_idx]
            best_ever = pop[gen_best_idx][:]

        if gen % 50 == 0:
            print(f"  GA gen {gen}: best={best_fitness:.1f}")

    sol = build_sol(best_ever, data, cfg, n_drones)
    print(f"  GA 最终: 成本={sol.total_cost:.1f}, 启用={sol.n_enabled}架")
    return sol


def calc_fitness(assignment, data, cfg):
    """计算适应度（成本越低越好）"""
    cost, _, _, _ = eval_solution(assignment, data, cfg)
    return cost


def tournament_select(pop, fitness, k):
    """锦标赛选择：随机选k个，取最优"""
    pop_size = len(pop)
    idx = random.sample(range(pop_size), k)
    best_local = min(idx, key=lambda i: fitness[i])
    return pop[best_local][:]


def crossover(p1, p2, n_drones):
    """均匀交叉：每个订单随机选一个父代的分配"""
    m = len(p1)
    child = [0] * m
    for j in range(m):
        if random.random() < 0.5:
            child[j] = p1[j]
        else:
            child[j] = p2[j]
    # 确保至少有一架无人机被使用
    if all(d == 0 for d in child):
        child[random.randint(0, m - 1)] = random.randint(1, n_drones)
    return child


def mutate(assignment, n_drones, m):
    """变异：随机选一种操作"""
    r = random.random()
    if r < 0.4:
        # 单点变异
        j = random.randint(0, m - 1)
        assignment[j] = random.randint(1, n_drones)
    elif r < 0.7:
        # 双点交换
        j1 = random.randint(0, m - 1)
        j2 = random.randint(0, m - 1)
        if j1 != j2:
            assignment[j1], assignment[j2] = assignment[j2], assignment[j1]
    else:
        # 随机打乱一架无人机的所有订单分配
        d = random.randint(1, n_drones)
        for j in range(m):
            if assignment[j] == d:
                assignment[j] = random.randint(1, n_drones)
    return assignment


def random_assignment(n_drones, m):
    """生成随机分配"""
    n_active = random.randint(2, min(4, n_drones))
    active_drones = random.sample(range(1, n_drones + 1), n_active)
    return [random.choice(active_drones) for _ in range(m)]


def sol_to_assignment(sol, n_drones, m):
    """解向量转换"""
    assignment = [0] * m
    for route in sol.routes:
        for j in route.orders:
            assignment[j - 1] = route.drone
    return assignment
