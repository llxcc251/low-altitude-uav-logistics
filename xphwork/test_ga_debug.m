addpath(genpath('src'));
cfg = config();
data = load_data();
depot_idx = find(strcmp({data.nodes.type}, 'depot'));
dep = data.nodes(depot_idx);
n_drones = cfg.n_drones;
m = data.n_orders;

init_sol = random_search(data, cfg, 10);
current = zeros(1, m);
for r = 1:length(init_sol.routes)
    route = init_sol.routes{r};
    for jj = route.orders
        current(jj) = route.drone;
    end
end
fprintf('current: min=%d max=%d\n', min(current), max(current));

sol = build_sol_test(current, data, cfg, dep, n_drones);
fprintf('routes: %d, n_enabled: %d, cost: %.1f\n', length(sol.routes), sol.n_enabled, sol.total_cost);
