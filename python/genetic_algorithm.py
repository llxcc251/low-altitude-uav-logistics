# genetic_algorithm.py - 遗传算法（队列装箱版）

import random
import time
from eval_solution import eval_solution
from random_search import smart_random_assignment, build_sol


def calc_cost(assignment, data, cfg):
    cost, _, _, _ = eval_solution(assignment, data, cfg)
    return cost


def genetic_algorithm(data, cfg, time_budget=20):
    n_drones = cfg.n_drones
    m = data.n_orders

    pop_size = 100
    end_time = time.time() + time_budget
    gen = 0

    # 初始化：用随机搜索的解 + 随机填充
    from random_search import random_search
    init_sol = random_search(data, cfg, time_budget * 0.2)
    pop = []
    fitness = []

    if time.time() >= end_time:
        print(f'  GA init: timed out, returning random search result')
        return init_sol

    pop.append(sol_to_assignment(init_sol, n_drones, m))
    fitness.append(calc_cost(pop[0], data, cfg))

    for p in range(1, pop_size):
        if time.time() >= end_time:
            break
        pop.append(smart_random_assignment(n_drones, m, data, cfg))
        fitness.append(calc_cost(pop[p], data, cfg))

    if not pop:
        return init_sol

    best_cost = min(fitness)
    best = pop[fitness.index(best_cost)]
    print(f'  GA init: best_cost={best_cost:.1f} ({len(pop)} individuals)')

    while time.time() < end_time:
        gen += 1
        new_pop = []
        new_fit = []

        n_elite = max(1, int(pop_size * 0.05))
        sorted_idx = sorted(range(pop_size), key=lambda i: fitness[i])
        for e in range(n_elite):
            new_pop.append(pop[sorted_idx[e]][:])
            new_fit.append(fitness[sorted_idx[e]])

        for p in range(n_elite, pop_size):
            p1 = pop[tournament_select_idx(fitness, 5)]
            p2 = pop[tournament_select_idx(fitness, 5)]
            child = crossover_mutation(p1, p2, n_drones, m)
            cc = calc_cost(child, data, cfg)

            new_pop.append(child)
            new_fit.append(cc)

        # (u+lambda) 合并父代+子代，取前 pop_size
        combined_pop = pop + new_pop
        combined_fit = fitness + new_fit
        combined_idx = sorted(range(len(combined_pop)), key=lambda i: combined_fit[i])
        pop = [combined_pop[i] for i in combined_idx[:pop_size]]
        fitness = [combined_fit[i] for i in combined_idx[:pop_size]]

        gen_best = min(fitness)
        if gen_best < best_cost:
            best = pop[fitness.index(gen_best)][:]
            best_cost = gen_best

    print(f'  GA final: best_cost={best_cost:.1f} ({gen} gen)')
    return build_sol(best, data, cfg, n_drones)


def tournament_select_idx(fitness, k):
    candidates = random.sample(range(len(fitness)), k)
    return min(candidates, key=lambda i: fitness[i])


def crossover_mutation(p1, p2, n_drones, m):
    child = [0] * m
    for j in range(m):
        child[j] = p1[j] if random.random() < 0.5 else p2[j]
    if random.random() < 0.15:
        child[random.randint(0, m - 1)] = random.randint(1, n_drones)
    return child


def sol_to_assignment(sol, n_drones, m):
    assignment = [0] * m
    for route in sol.routes:
        for j in route['orders']:
            assignment[j - 1] = route['drone']
    return assignment
