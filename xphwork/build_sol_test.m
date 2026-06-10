function sol = build_sol_test(assignment, data, cfg, dep, n_use)
    drone_orders = cell(n_use, 1);
    for j = 1:length(assignment)
        d = assignment(j);
        if d > 0 && d <= n_use
            drone_orders{d} = [drone_orders{d}, j];
        end
    end
    sol.routes = {}; sol.n_enabled = 0; sol.total_energy = 0; sol.total_late = 0; sol.total_swaps = 0;
    for i = 1:n_use
        if isempty(drone_orders{i}), continue; end
        sol.n_enabled = sol.n_enabled + 1;
        fprintf('  drone %d: %d orders\n', i, length(drone_orders{i}));
    end
    sol.total_energy = 0; sol.total_late = 0; sol.total_swaps = 0;
    sol.total_cost = sol.n_enabled * cfg.enable_cost;
end
