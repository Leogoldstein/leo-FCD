function [grouped_data_by_age, fig] = plot_basic_metrics_boxplots_by_age( ...
    current_ages_group, results_analysis, save_folder, animal_name)

% =====================================================================
% INIT
% =====================================================================

    if nargin < 3 || isempty(save_folder)
        save_folder = pwd;
    end
    if nargin < 4
        animal_name = '';
    end

    if iscell(save_folder), save_folder = save_folder{1}; end
    if iscell(animal_name), animal_name = animal_name{1}; end

    if ~exist(save_folder, 'dir')
        mkdir(save_folder);
    end

    color_gcamp = [0.20 0.65 0.25];
    color_blue  = [0.10 0.35 0.90];
    color_gray  = [0.45 0.45 0.45];

    layer_defs = { ...
        'I',      0,   80; ...
        'II/III', 80,  300; ...
        'IV',     300, 450};

    metric_names = { ...
        'ZPosition_um', ...
        'FrequencyPerCell_gcamp', ...
        'FrequencyPerCell_blue', ...
        'InterEventIntervals_gcamp_ms', ...
        'InterEventIntervals_blue_ms', ...
        'SCEsNumber', ...
        'SCEsCellParticipation_percent', ...
        'SCEsduration_ms'};

% =====================================================================
% GROUP DATA BY AGE AND LAYER
% =====================================================================

    age_values = parse_age_values(current_ages_group);
    unique_ages = sort(unique(age_values(isfinite(age_values))));

    if isempty(unique_ages)
        error('Aucun âge valide trouvé.');
    end

    age_labels_base = arrayfun(@(x) sprintf('P%d', x), unique_ages, 'UniformOutput', false);

    [grouped_data_by_age, nLayers, layer_labels] = group_metrics_by_age_and_layer( ...
        results_analysis, age_values, unique_ages, metric_names, layer_defs);

% =====================================================================
% FIGURES
% =====================================================================

    fig = struct();

    fig.Frequency = make_frequency_figure( ...
        grouped_data_by_age, unique_ages, age_labels_base, nLayers, layer_labels, layer_defs, ...
        color_gcamp, color_blue, save_folder, animal_name);

    fig.Intervals = make_intervals_figure( ...
        grouped_data_by_age, unique_ages, age_labels_base, nLayers, layer_labels, layer_defs, ...
        color_gcamp, color_blue, save_folder, animal_name);

    fig.SCEs = make_sce_figure( ...
        grouped_data_by_age, unique_ages, age_labels_base, ...
        color_gray, save_folder, animal_name);
end

% =====================================================================
% GROUPING BY LAYER
% =====================================================================

function [grouped_data_by_age, nLayers, layer_labels] = group_metrics_by_age_and_layer( ...
    results_analysis, age_values, unique_ages, metric_names, layer_defs)

    nAges   = numel(unique_ages);
    nRec    = numel(results_analysis);
    nLayers = size(layer_defs, 1);

    layer_labels = layer_defs(:,1);

    grouped_data_by_age = struct();

    for k = 1:numel(metric_names)
        field = metric_names{k};

        if is_sce_metric(field)
            grouped_data_by_age.(field) = cell(nAges, 1);
        else
            grouped_data_by_age.(field) = cell(nAges, 1);
            for a = 1:nAges
                grouped_data_by_age.(field){a} = cell(nLayers, 1);
            end
        end
    end

    grouped_data_by_age.LayerPoints = cell(nAges, 1);

    for a = 1:nAges
        grouped_data_by_age.LayerPoints{a} = [];
    end

    for m = 1:nRec

        age_m = age_values(m);

        if ~isfinite(age_m)
            continue;
        end

        age_idx = find(unique_ages == age_m, 1);

        if isempty(age_idx)
            continue;
        end

        R = results_analysis(m);

        z_vals = get_field_or_empty(R, 'ZPosition_um');

        if isempty(z_vals)
            continue;
        end

        if ~iscell(z_vals)
            z_vals = {z_vals};
        end

        plane_to_layer = nan(numel(z_vals), 1);

        for p = 1:numel(z_vals)

            z = z_vals{p};

            if isempty(z) || ~isnumeric(z)
                continue;
            end

            z = z(1);

            if ~isfinite(z)
                continue;
            end

            layer_idx = find_layer_from_depth(z, layer_defs);

            if ~isnan(layer_idx)
                plane_to_layer(p) = layer_idx;

                grouped_data_by_age.ZPosition_um{age_idx}{layer_idx} = [ ...
                    grouped_data_by_age.ZPosition_um{age_idx}{layer_idx}; z];

                grouped_data_by_age.LayerPoints{age_idx} = [ ...
                    grouped_data_by_age.LayerPoints{age_idx}; ...
                    z, layer_idx, m, p];
            end
        end

        for k = 1:numel(metric_names)

            field = metric_names{k};

            if strcmp(field, 'ZPosition_um')
                continue;
            end

            vals = get_field_or_empty(R, field);

            if isempty(vals)
                continue;
            end

            if is_sce_metric(field)
                grouped_data_by_age.(field){age_idx} = ...
                    append_numeric_vector(grouped_data_by_age.(field){age_idx}, vals);
                continue;
            end

            if ~iscell(vals)
                vals = {vals};
            end

            for p = 1:numel(vals)

                if p > numel(plane_to_layer)
                    continue;
                end

                layer_idx = plane_to_layer(p);

                if isnan(layer_idx)
                    continue;
                end

                v = clean_numeric(vals{p});

                if isempty(v)
                    continue;
                end

                grouped_data_by_age.(field){age_idx}{layer_idx} = [ ...
                    grouped_data_by_age.(field){age_idx}{layer_idx}; v];
            end
        end
    end
end

function layer_idx = find_layer_from_depth(z, layer_defs)

    layer_idx = NaN;

    for i = 1:size(layer_defs, 1)

        z_min = layer_defs{i,2};
        z_max = layer_defs{i,3};

        if z >= z_min && z < z_max
            layer_idx = i;
            return;
        end
    end
end

% =====================================================================
% FIGURE MAKERS
% =====================================================================

function figHandle = make_frequency_figure(grouped, ages, age_labels, nLayers, layer_labels, layer_defs, color_gcamp, color_blue, save_folder, animal_name)

    metric_fields = {'FrequencyPerCell_gcamp', 'FrequencyPerCell_blue'};
    valid_layers = get_valid_layers_for_metrics(grouped, nLayers, metric_fields);
    layers_to_plot = find(valid_layers);

    if isempty(layers_to_plot)
        figHandle = [];
        return;
    end

    nRows = numel(layers_to_plot);

    figHandle = figure('Color','w', ...
        'Name', sprintf('%s_frequency_by_age_layer', animal_name), ...
        'Position', [50 50 2000 350 * nRows]);

    tl = tiledlayout(nRows, 4, 'TileSpacing','compact', 'Padding','compact');

    [ymin_g, ymax_g] = compute_global_ylim(grouped.FrequencyPerCell_gcamp, nLayers, false);
    [ymin_b, ymax_b] = compute_global_ylim(grouped.FrequencyPerCell_blue,  nLayers, false);

    ymin_freq = min([ymin_g ymin_b], [], 'omitnan');
    ymax_freq = max([ymax_g ymax_b], [], 'omitnan');

    for ii = 1:nRows

        l = layers_to_plot(ii);

        nexttile;
        plot_layer_points_one_layer(grouped, ages, age_labels, layer_defs, l, ...
            sprintf('Layer %s - depths', layer_labels{l}));

        nexttile;
        plot_box_one_layer(grouped.FrequencyPerCell_gcamp, ...
            ages, age_labels, l, color_gcamp, ...
            sprintf('Layer %s - GCaMP frequency', layer_labels{l}), ...
            'Events / min');
        apply_fixed_ylim(ymin_freq, ymax_freq);

        nexttile;
        plot_box_one_layer(grouped.FrequencyPerCell_blue, ...
            ages, age_labels, l, color_blue, ...
            sprintf('Layer %s - Blue frequency', layer_labels{l}), ...
            'Events / min');
        apply_fixed_ylim(ymin_freq, ymax_freq);

        nexttile;
        plot_gcamp_blue_one_layer( ...
            grouped.FrequencyPerCell_gcamp, ...
            grouped.FrequencyPerCell_blue, ...
            ages, age_labels, l, ...
            color_gcamp, color_blue, ...
            sprintf('Layer %s - GCaMP vs Blue frequency', layer_labels{l}), ...
            'Events / min');
        apply_fixed_ylim(ymin_freq, ymax_freq);
    end

    title(tl, sprintf('%s - Frequency by age and cortical layer', animal_name), ...
        'Interpreter','none', 'FontWeight','bold');

    saveas(figHandle, fullfile(save_folder, sprintf('%s_frequency_by_age_layer.png', animal_name)));
    close(figHandle);
end

function figHandle = make_intervals_figure(grouped, ages, age_labels, nLayers, layer_labels, layer_defs, color_gcamp, color_blue, save_folder, animal_name)

    metric_fields = {'InterEventIntervals_gcamp_ms', 'InterEventIntervals_blue_ms'};
    valid_layers = get_valid_layers_for_metrics(grouped, nLayers, metric_fields);
    layers_to_plot = find(valid_layers);

    if isempty(layers_to_plot)
        figHandle = [];
        return;
    end

    nRows = numel(layers_to_plot);

    figHandle = figure('Color','w', ...
        'Name', sprintf('%s_intervals_by_age_layer', animal_name), ...
        'Position', [50 50 2000 350 * nRows]);

    tl = tiledlayout(nRows, 4, 'TileSpacing','compact', 'Padding','compact');

    [ymin_g, ymax_g] = compute_global_ylim(grouped.InterEventIntervals_gcamp_ms, nLayers, true);
    [ymin_b, ymax_b] = compute_global_ylim(grouped.InterEventIntervals_blue_ms,  nLayers, true);

    ymin_iei = min([ymin_g ymin_b], [], 'omitnan');
    ymax_iei = max([ymax_g ymax_b], [], 'omitnan');

    for ii = 1:nRows

        l = layers_to_plot(ii);

        nexttile;
        plot_layer_points_one_layer(grouped, ages, age_labels, layer_defs, l, ...
            sprintf('Layer %s - depths', layer_labels{l}));

        nexttile;
        plot_box_one_layer(grouped.InterEventIntervals_gcamp_ms, ...
            ages, age_labels, l, color_gcamp, ...
            sprintf('Layer %s - GCaMP IEI', layer_labels{l}), ...
            'Interval (s)', true);
        apply_fixed_ylim(ymin_iei, ymax_iei);

        nexttile;
        plot_box_one_layer(grouped.InterEventIntervals_blue_ms, ...
            ages, age_labels, l, color_blue, ...
            sprintf('Layer %s - Blue IEI', layer_labels{l}), ...
            'Interval (s)', true);
        apply_fixed_ylim(ymin_iei, ymax_iei);

        nexttile;
        plot_gcamp_blue_one_layer( ...
            grouped.InterEventIntervals_gcamp_ms, ...
            grouped.InterEventIntervals_blue_ms, ...
            ages, age_labels, l, ...
            color_gcamp, color_blue, ...
            sprintf('Layer %s - GCaMP vs Blue IEI', layer_labels{l}), ...
            'Interval (s)', true);
        apply_fixed_ylim(ymin_iei, ymax_iei);
    end

    title(tl, sprintf('%s - Inter-event intervals by age and cortical layer', animal_name), ...
        'Interpreter','none', 'FontWeight','bold');

    saveas(figHandle, fullfile(save_folder, sprintf('%s_intervals_by_age_layer.png', animal_name)));
    close(figHandle);
end

function figHandle = make_sce_figure(grouped, ages, age_labels, color_gray, save_folder, animal_name)

    figHandle = figure('Color','w', ...
        'Name', sprintf('%s_SCEs_by_age', animal_name), ...
        'Position', [100 100 1400 450]);

    tl = tiledlayout(1,3, 'TileSpacing','compact', 'Padding','compact');

    nexttile;
    plot_bar_metric(grouped.SCEsNumber, ages, age_labels, color_gray, ...
        'Number of SCEs', 'SCE count');

    nexttile;
    plot_box_metric(grouped.SCEsCellParticipation_percent, ages, age_labels, color_gray, ...
        'SCE cell participation', 'Active cells (%)');

    nexttile;
    plot_box_metric(grouped.SCEsduration_ms, ages, age_labels, color_gray, ...
        'SCE duration', 'Duration (ms)');

    title(tl, sprintf('%s - SCE metrics by age', animal_name), ...
        'Interpreter','none', 'FontWeight','bold');

    saveas(figHandle, fullfile(save_folder, sprintf('%s_SCEs_by_age.png', animal_name)));
    close(figHandle);
end

% =====================================================================
% PLOTTERS
% =====================================================================

function plot_box_metric(vals_by_age, ages, age_labels, color_fixed, title_str, ylab, show_n)

    if nargin < 7
        show_n = true;
    end

    [y, g, positions, labels] = build_box_inputs(vals_by_age, ages, age_labels);

    if isempty(y)
        empty_axis(title_str, ylab);
        return;
    end

    dx = get_age_dx(ages);
    box_width = dx * 0.45;

    [ymin, ymax] = compute_std_ylim(y, 3);

    warning_state = warning('off', 'all');

    boxplot(y, g, ...
        'Positions', positions, ...
        'Widths', box_width, ...
        'Labels', repmat({''}, 1, numel(positions)), ...
        'Symbol', '', ...
        'Whisker', 1.5, ...
        'Colors', 'k');

    warning(warning_state);

    color_boxes(color_fixed);
    format_boxplot_lines();

    if show_n
        xticks(positions);
        xticklabels(labels);
    else
        xticks(positions);
        xticklabels(age_labels(ismember(ages, positions)));
    end

    xtickangle(35);

    apply_limits_and_style(positions, ages, dx, ymin, ymax, title_str, ylab);
end

function plot_box_one_layer(data_by_age, ages, age_labels, layer_idx, color_fixed, title_str, ylab, convert_ms_to_s, show_n)

    if nargin < 8
        convert_ms_to_s = false;
    end
    if nargin < 9
        show_n = true;
    end

    vals_by_age = extract_layer_values(data_by_age, layer_idx);

    if convert_ms_to_s
        vals_by_age = cellfun(@(x) x ./ 1000, vals_by_age, 'UniformOutput', false);
    end

    plot_box_metric(vals_by_age, ages, age_labels, color_fixed, title_str, ylab, show_n);
end

function plot_gcamp_blue_one_layer(data_gcamp_by_age, data_blue_by_age, ages, age_labels, layer_idx, color_gcamp, color_blue, title_str, ylab, convert_ms_to_s)

    if nargin < 10
        convert_ms_to_s = false;
    end

    gcamp_one_layer = extract_layer_values(data_gcamp_by_age, layer_idx);
    blue_one_layer  = extract_layer_values(data_blue_by_age, layer_idx);

    if convert_ms_to_s
        gcamp_one_layer = cellfun(@(x) x ./ 1000, gcamp_one_layer, 'UniformOutput', false);
        blue_one_layer  = cellfun(@(x) x ./ 1000, blue_one_layer,  'UniformOutput', false);
    end

    plot_gcamp_blue_side_by_side( ...
        gcamp_one_layer, blue_one_layer, ...
        ages, age_labels, ...
        color_gcamp, color_blue, ...
        title_str, ylab);
end

function plot_gcamp_blue_side_by_side(data_gcamp_by_age, data_blue_by_age, ages, age_labels, color_gcamp, color_blue, title_str, ylab)

    nAges = numel(ages);

    mean_g = nan(nAges,1);
    std_g  = nan(nAges,1);
    mean_b = nan(nAges,1);
    std_b  = nan(nAges,1);

    for a = 1:nAges
        vals_g = clean_numeric(data_gcamp_by_age{a});
        vals_b = clean_numeric(data_blue_by_age{a});

        if ~isempty(vals_g)
            mean_g(a) = mean(vals_g, 'omitnan');
            std_g(a)  = std(vals_g, 'omitnan');
        end

        if ~isempty(vals_b)
            mean_b(a) = mean(vals_b, 'omitnan');
            std_b(a)  = std(vals_b, 'omitnan');
        end
    end

    valid = ~(isnan(mean_g) & isnan(mean_b));

    if ~any(valid)
        empty_axis(title_str, ylab);
        return;
    end

    hold on;

    valid_g = isfinite(mean_g) & isfinite(std_g);
    valid_b = isfinite(mean_b) & isfinite(std_b);

    ages_g = ages(valid_g);
    mg = mean_g(valid_g);
    sg = std_g(valid_g);

    ages_b = ages(valid_b);
    mb = mean_b(valid_b);
    sb = std_b(valid_b);

    if ~isempty(mg)
        fill([ages_g; flipud(ages_g)], ...
             [mg - sg; flipud(mg + sg)], ...
             color_gcamp, ...
             'FaceAlpha', 0.20, ...
             'EdgeColor', 'none');

        plot(ages_g, mg, '-o', ...
            'Color', color_gcamp, ...
            'MarkerFaceColor', color_gcamp, ...
            'MarkerEdgeColor', 'k', ...
            'LineWidth', 2);
    end

    if ~isempty(mb)
        fill([ages_b; flipud(ages_b)], ...
             [mb - sb; flipud(mb + sb)], ...
             color_blue, ...
             'FaceAlpha', 0.20, ...
             'EdgeColor', 'none');

        plot(ages_b, mb, '-o', ...
            'Color', color_blue, ...
            'MarkerFaceColor', color_blue, ...
            'MarkerEdgeColor', 'k', ...
            'LineWidth', 2);
    end

    dx = get_age_dx(ages);

    xticks(ages(valid));
    xticklabels(age_labels(valid));
    xtickangle(35);
    xlim([min(ages)-dx, max(ages)+dx]);

    y_all = [mg - sg; mg + sg; mb - sb; mb + sb];
    y_all = y_all(isfinite(y_all));

    if ~isempty(y_all)
        [ymin, ymax] = compute_std_ylim(y_all, 3);
        if isfinite(ymin) && isfinite(ymax) && ymax > ymin
            ylim([ymin ymax]);
        end
    end

    format_yticks_integer();

    ylabel(ylab);
    title(title_str, 'Interpreter', 'none');
    grid on;
    box off;

    legend({'GCaMP ± std', 'GCaMP mean', 'Blue ± std', 'Blue mean'}, ...
        'Location','best', ...
        'Box','off');
end

function plot_bar_metric(vals_by_age, ages, age_labels, color_fixed, title_str, ylab)

    nAges = numel(vals_by_age);
    means = nan(nAges,1);
    sems  = nan(nAges,1);
    ns    = zeros(nAges,1);

    for a = 1:nAges
        vals = clean_numeric(vals_by_age{a});
        ns(a) = numel(vals);

        if ns(a) > 0
            means(a) = mean(vals, 'omitnan');

            if ns(a) > 1
                sems(a) = std(vals, 'omitnan') / sqrt(ns(a));
            else
                sems(a) = 0;
            end
        end
    end

    valid = ns > 0;

    if ~any(valid)
        empty_axis(title_str, ylab);
        return;
    end

    dx = get_age_dx(ages);

    age_x = ages(valid);
    labels = make_labels_with_n(age_labels(valid), ns(valid));

    bar(age_x, means(valid), dx * 0.45, ...
        'FaceColor', color_fixed, ...
        'EdgeColor', 'none');

    hold on;

    errorbar(age_x, means(valid), sems(valid), ...
        'k.', 'LineWidth', 1);

    xticks(age_x);
    xticklabels(labels);
    xtickangle(35);

    xlim([min(ages)-dx, max(ages)+dx]);

    format_yticks_integer();

    ylabel(ylab);
    title(title_str, 'Interpreter', 'none');
    grid on;
    box off;
end

% =====================================================================
% DATA HELPERS
% =====================================================================

function vals_by_age = extract_layer_values(data_by_age, layer_idx)

    vals_by_age = cell(numel(data_by_age), 1);

    for a = 1:numel(data_by_age)

        if isempty(data_by_age{a}) || ...
           numel(data_by_age{a}) < layer_idx || ...
           isempty(data_by_age{a}{layer_idx})

            vals_by_age{a} = [];
        else
            vals_by_age{a} = data_by_age{a}{layer_idx};
        end
    end
end

function [y, g, positions, labels] = build_box_inputs(vals_by_age, ages, age_labels)

    y = [];
    g = [];
    positions = [];
    labels = {};

    group_id = 0;

    for a = 1:numel(vals_by_age)

        vals = clean_numeric(vals_by_age{a});

        if isempty(vals)
            continue;
        end

        group_id = group_id + 1;

        y = [y; vals];
        g = [g; repmat(group_id, numel(vals), 1)];

        positions = [positions; ages(a)];
        labels{end+1} = sprintf('%s (n=%d)', age_labels{a}, numel(vals));
    end
end

function out = append_numeric_vector(out, x)

    if isempty(out)
        out = [];
    end

    if isempty(x)
        return;
    end

    if iscell(x)
        for i = 1:numel(x)
            out = append_numeric_vector(out, x{i});
        end
        return;
    end

    x = clean_numeric(x);

    if ~isempty(x)
        out = [out; x];
    end
end

function x = clean_numeric(x)

    if isempty(x) || ~isnumeric(x)
        x = [];
        return;
    end

    x = x(:);
    x = x(isfinite(x));
end

% =====================================================================
% FORMAT HELPERS
% =====================================================================

function color_boxes(color_fixed)

    h = findobj(gca, 'Tag', 'Box');
    h = flipud(h);

    for j = 1:numel(h)
        patch(get(h(j), 'XData'), get(h(j), 'YData'), color_fixed, ...
            'FaceAlpha', 0.45, ...
            'EdgeColor', color_fixed);
    end
end

function format_boxplot_lines()

    med = findobj(gca, 'Tag', 'Median');
    set(med, 'Color', 'k', 'LineWidth', 1.5);

    whisk = findobj(gca, 'Tag', 'Whisker');
    set(whisk, 'LineWidth', 1);
end

function apply_limits_and_style(~, all_ages, dx, ymin, ymax, title_str, ylab)

    if isempty(all_ages)
        return;
    end

    xlim([min(all_ages)-dx, max(all_ages)+dx]);

    if isfinite(ymin) && isfinite(ymax) && ymax > ymin
        ylim([ymin ymax]);
    end

    format_yticks_integer();

    ylabel(ylab);
    title(title_str, 'Interpreter', 'none');
    grid on;
    box off;
end

function empty_axis(title_str, ylab)

    title([title_str ' (no data)'], 'Interpreter', 'none');
    ylabel(ylab);

    xticks([]);
    yticks([]);

    box off;
end

function dx = get_age_dx(ages)

    dx = min(diff(unique(ages)));

    if isempty(dx) || ~isfinite(dx) || dx <= 0
        dx = 1;
    end
end

function [ymin, ymax] = compute_std_ylim(y, k_std)

    if nargin < 2
        k_std = 3;
    end

    y = clean_numeric(y);

    if isempty(y)
        ymin = NaN;
        ymax = NaN;
        return;
    end

    mu = mean(y, 'omitnan');
    sigma = std(y, 'omitnan');

    if isnan(mu) || isnan(sigma)
        ymin = NaN;
        ymax = NaN;

    elseif sigma == 0
        ymin = max(0, mu * 0.9);
        ymax = mu * 1.1 + eps;

    else
        ymin = mu - k_std * sigma;
        ymax = mu + k_std * sigma;

        if min(y) >= 0
            ymin = max(0, ymin);
        end
    end
end

function [ymin_global, ymax_global] = compute_global_ylim(data_by_age, nLayers, convert_ms_to_s)

    if nargin < 3
        convert_ms_to_s = false;
    end

    all_values = [];

    for a = 1:numel(data_by_age)

        if isempty(data_by_age{a})
            continue;
        end

        for l = 1:nLayers

            if numel(data_by_age{a}) < l || isempty(data_by_age{a}{l})
                continue;
            end

            vals = clean_numeric(data_by_age{a}{l});

            if isempty(vals)
                continue;
            end

            if convert_ms_to_s
                vals = vals ./ 1000;
            end

            all_values = [all_values; vals];
        end
    end

    if isempty(all_values)
        ymin_global = NaN;
        ymax_global = NaN;
        return;
    end

    [ymin_global, ymax_global] = compute_std_ylim(all_values, 3);
end

function apply_fixed_ylim(ymin, ymax)

    if isfinite(ymin) && isfinite(ymax) && ymax > ymin
        ylim([ymin ymax]);
        format_yticks_integer();
    end
end

function format_yticks_integer()

    yl = ylim;

    if ~all(isfinite(yl)) || diff(yl) <= 0
        return;
    end

    range = diff(yl);
    step = max(1, round(range / 6));

    ystart = ceil(yl(1) / step) * step;
    yend   = floor(yl(2) / step) * step;

    if ystart <= yend
        yticks(ystart:step:yend);
    end

    ytickformat('%.0f');
end

function colors = distinguishable_age_colors(n)

    if n <= 0
        colors = [];
        return;
    end

    hue = linspace(0, 1, n + 1);
    hue(end) = [];

    saturation = 0.70 * ones(n,1);
    value      = 0.85 * ones(n,1);

    colors = hsv2rgb([hue(:), saturation, value]);
end

% =====================================================================
% BASIC HELPERS
% =====================================================================

function age_values = parse_age_values(current_ages_group)

    n = numel(current_ages_group);
    age_values = nan(n,1);

    for i = 1:n

        a = current_ages_group{i};

        if isnumeric(a) && isscalar(a)
            age_values(i) = a;

        elseif isstring(a) || ischar(a)
            tok = regexp(char(a), '\d+', 'match', 'once');

            if ~isempty(tok)
                age_values(i) = str2double(tok);
            end
        end
    end
end

function out = get_field_or_empty(S, field_name)

    if isstruct(S) && isfield(S, field_name)
        out = S.(field_name);
    else
        out = [];
    end
end

function tf = is_sce_metric(field_name)

    sce_fields = { ...
        'SCEsNumber', ...
        'SCEsCellParticipation_percent', ...
        'SCEsduration_ms', ...
        'SCEsThreshold'};

    tf = any(strcmp(field_name, sce_fields));
end

function labels = make_labels_with_n(age_labels, ns)

    labels = cell(size(age_labels));

    for i = 1:numel(age_labels)
        labels{i} = sprintf('%s (n=%d)', age_labels{i}, ns(i));
    end
end

function valid_layers = get_valid_layers_for_metrics(grouped, nLayers, metric_fields)

    valid_layers = false(nLayers, 1);

    for l = 1:nLayers
        for f = 1:numel(metric_fields)

            data_by_age = grouped.(metric_fields{f});

            for a = 1:numel(data_by_age)

                if isempty(data_by_age{a}) || ...
                   numel(data_by_age{a}) < l || ...
                   isempty(data_by_age{a}{l})
                    continue;
                end

                vals = clean_numeric(data_by_age{a}{l});

                if ~isempty(vals)
                    valid_layers(l) = true;
                    break;
                end
            end

            if valid_layers(l)
                break;
            end
        end
    end
end


function plot_layer_points_one_layer(grouped, ages, age_labels, layer_defs, layer_idx, title_str)

    hold on;

    age_colors = distinguishable_age_colors(numel(ages));

    dx = get_age_dx(ages);

    z_global_min = layer_defs{1, 2};
    z_global_max = layer_defs{end, 3};

    xlim([min(ages)-dx, max(ages)+dx]);
    ylim([z_global_min z_global_max]);
    set(gca, 'YDir', 'reverse');

    % Points de profondeur appartenant à la layer courante
    for a = 1:numel(ages)

        V = grouped.LayerPoints{a};

        if isempty(V)
            continue;
        end

        keep = V(:,2) == layer_idx;

        if ~any(keep)
            continue;
        end

        z_vals = V(keep, 1);
        x_jitter = (rand(size(z_vals)) - 0.5) * 0.18;

        scatter(ages(a) + x_jitter, z_vals, 65, ...
            'filled', ...
            'MarkerFaceColor', age_colors(a,:), ...
            'MarkerEdgeColor', 'k', ...
            'DisplayName', age_labels{a});
    end

    % Afficher toutes les limites de layers, même sans données
    for i = 1:size(layer_defs, 1)

        z_min = layer_defs{i,2};
        z_max = layer_defs{i,3};
        z_mid = (z_min + z_max) / 2;

        yline(z_min, '--k', 'HandleVisibility','off');
        yline(z_max, '--k', 'HandleVisibility','off');

        xl = xlim;
    
        text(xl(1), z_mid, layer_defs{i,1}, ...
            'HorizontalAlignment', 'left', ...
            'VerticalAlignment', 'middle', ...
            'FontWeight', 'bold', ...
            'BackgroundColor', 'w', ...
            'Margin', 2, ...
            'Interpreter','none');
    end

    xticks(ages);
    xticklabels(age_labels);
    xtickangle(35);

    xlabel('Age');
    ylabel('Depth (\mum)');
    title(title_str, 'Interpreter','none');

    grid on;
    box off;
end