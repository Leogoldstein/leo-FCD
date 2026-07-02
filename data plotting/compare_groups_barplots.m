function figs = compare_groups_barplots(selected_groups, pooled_level, branch_name)

if nargin < 2
    pooled_level = [];
end

if nargin < 3 || isempty(branch_name)
    branch_name = 'gcamp_plane';
end

preferred_order = {'WT', 'SHAM', 'FCD'};
available = fieldnames(selected_groups);

animal_types = {};
for i = 1:numel(preferred_order)
    if ismember(preferred_order{i}, available)
        animal_types{end+1} = preferred_order{i}; %#ok<AGROW>
    end
end

remaining = setdiff(available, animal_types, 'stable');
animal_types = [animal_types; remaining(:)];

num_groups = numel(animal_types);
colors = lines(num_groups);

for g = 1:num_groups
    switch upper(animal_types{g})
        case 'WT'
            colors(g,:) = [0 0.60 0];
        case 'FCD'
            colors(g,:) = [0 0.45 0.74];
    end
end

measures = { ...
    'ActivityFreq', ...
    'SCEFrequency', ...
    'PairwiseCorr', ...
    'propSCEs'};

measure_titles = { ...
    'Activity Frequency (events/min)', ...
    'SCE Frequency (events/min)', ...
    'Mean Pairwise Correlation', ...
    'SCE Size (% Active Cells)'};

all_data = struct();
all_ages = [];

for g = 1:num_groups

    group_name = animal_types{g};
    animals = selected_groups.(group_name);

    for mi = 1:numel(measures)
        all_data.(group_name).(measures{mi}).values = {};
        all_data.(group_name).(measures{mi}).ages = [];
    end

    for k = 1:numel(animals)

        if ~isfield(animals(k), 'results_analysis') || isempty(animals(k).results_analysis)
            continue;
        end

        RA = animals(k).results_analysis;
        nRec = get_nrec_from_results_analysis(RA);

        for m = 1:nRec

            age_num = get_age_Frequency_from_animal(animals(k), m);

            if isnan(age_num)
                continue;
            end

            all_ages(end+1) = age_num; %#ok<AGROW>

            for mi = 1:numel(measures)

                measure_name = measures{mi};

                vals = extract_measure_values(RA, m, branch_name, measure_name);
                vals = flatten_numeric(vals);

                if isempty(vals)
                    continue;
                end

                if strcmp(measure_name, 'PairwiseCorr')
                    vals(abs(vals) > 1) = NaN;
                end

                vals = vals(isfinite(vals));

                if isempty(vals)
                    continue;
                end

                all_data.(group_name).(measure_name).values{end+1} = vals;
                all_data.(group_name).(measure_name).ages(end+1) = age_num;
            end
        end
    end
end

if isempty(all_ages)
    warning('No valid ages found in selected_groups.');
    figs = [];
    return;
end

base_ages = unique(all_ages);
base_ages = base_ages(:)';

if isempty(pooled_level)

    pooled_level = num2cell(base_ages);
    pooled_labels = arrayfun(@(x) sprintf('P%d', x), base_ages, ...
        'UniformOutput', false);

elseif isnumeric(pooled_level)

    pool_size = pooled_level;
    pooled_level = cell(1, ceil(numel(base_ages) / pool_size));

    for i = 1:numel(pooled_level)
        i1 = (i-1) * pool_size + 1;
        i2 = min(i * pool_size, numel(base_ages));
        pooled_level{i} = base_ages(i1:i2);
    end

    pooled_labels = cellfun(@(x) sprintf('P%d-P%d', min(x), max(x)), ...
        pooled_level, 'UniformOutput', false);

elseif iscell(pooled_level)

    pooled_labels = cellfun(@(x) sprintf('P%d-P%d', min(x), max(x)), ...
        pooled_level, 'UniformOutput', false);

else
    error('pooled_level must be empty, numeric, or cell array.');
end

num_pools = numel(pooled_level);

n_recordings_total = zeros(num_groups, 1);
n_animals_total = zeros(num_groups, 1);

for g = 1:num_groups

    group_name = animal_types{g};

    if ~isfield(selected_groups, group_name)
        continue;
    end

    animals = selected_groups.(group_name);
    valid_animal = false(numel(animals), 1);

    for k = 1:numel(animals)

        if isfield(animals(k), 'results_analysis') && ~isempty(animals(k).results_analysis)

            nRec_k = get_nrec_from_results_analysis(animals(k).results_analysis);

            if nRec_k > 0
                valid_animal(k) = true;
                n_recordings_total(g) = n_recordings_total(g) + nRec_k;
            end
        end
    end

    n_animals_total(g) = sum(valid_animal);
end

legend_labels = cell(num_groups, 1);

for g = 1:num_groups
    legend_labels{g} = sprintf('%s (n=%d animals, %d rec)', ...
        animal_types{g}, ...
        n_animals_total(g), ...
        n_recordings_total(g));
end

figs = figure('Name', 'Quantitative comparison of neuronal network activity', ...
              'Position', [50, 50, 1500, 900]);

t = tiledlayout(2, 2, ...
    'TileSpacing', 'compact', ...
    'Padding', 'compact');

num_measures = numel(measures);

for mi = 1:num_measures

    nexttile;
    hold on;

    measure_name = measures{mi};
    pooled_values_all = cell(num_groups, num_pools);
    n_recordings_pool = zeros(num_groups, num_pools);
    all_vals_measure = [];

    for g = 1:num_groups

        group_name = animal_types{g};

        ages_g = all_data.(group_name).(measure_name).ages;
        vals_g = all_data.(group_name).(measure_name).values;

        for p = 1:num_pools

            pooled_vals = [];

            idx = find(ismember(ages_g, pooled_level{p}));
            idx = idx(idx <= numel(vals_g));

            n_recordings_pool(g,p) = numel(idx);

            for ii = idx
                pooled_vals = [pooled_vals; vals_g{ii}(:)]; %#ok<AGROW>
            end

            pooled_vals = pooled_vals(isfinite(pooled_vals));
            pooled_values_all{g,p} = pooled_vals;
            all_vals_measure = [all_vals_measure; pooled_vals(:)]; %#ok<AGROW>
        end
    end

    if isempty(all_vals_measure)
        title([measure_titles{mi} ' (no data)'], ...
            'Interpreter', 'none', ...
            'FontSize', 18, ...
            'FontWeight', 'bold');
        axis off;
        continue;
    end

    ymin = min(all_vals_measure, [], 'omitnan');
    ymax = max(all_vals_measure, [], 'omitnan');

    if isempty(ymin) || isnan(ymin)
        ymin = 0;
    end

    if isempty(ymax) || isnan(ymax) || ymax <= ymin
        ymax = ymin + 1;
    end

    yrange = ymax - ymin;

    if strcmp(measure_name, 'SCEFrequency')

        means = nan(num_groups, num_pools);
        stds  = nan(num_groups, num_pools);

        for g = 1:num_groups
            for p = 1:num_pools

                vals = pooled_values_all{g,p};

                if isempty(vals)
                    continue;
                end

                means(g,p) = mean(vals, 'omitnan');
                stds(g,p)  = std(vals, 'omitnan');
            end
        end

        b = bar(means', 'grouped');

        for g = 1:num_groups
            b(g).FaceColor = colors(g,:);
            b(g).EdgeColor = 'none';
            b(g).FaceAlpha = 0.85;
        end

        for g = 1:num_groups
            x = b(g).XEndPoints;
            y = means(g,:);
            e = stds(g,:);

            errorbar(x, y, e, 'k.', 'LineWidth', 1.5);
        end

        ymax_bar = max(means(:) + stds(:), [], 'omitnan');

        if isempty(ymax_bar) || isnan(ymax_bar) || ymax_bar <= 0
            ymax_bar = ymax;
        end

        ylim([0, ymax_bar * 1.25]);

    else

        group_width = 0.55;
        violin_width = group_width / max(num_groups, 1);

        for p = 1:num_pools

            offsets = linspace(-group_width/2 + violin_width/2, ...
                                group_width/2 - violin_width/2, ...
                                num_groups);

            for g = 1:num_groups

                vals = pooled_values_all{g,p};

                if isempty(vals)
                    continue;
                end

                x_center = p + offsets(g);

                draw_single_violin(vals, x_center, violin_width * 0.65, colors(g,:));

                med_val = median(vals, 'omitnan');

                plot([x_center - violin_width*0.20, x_center + violin_width*0.20], ...
                     [med_val med_val], ...
                     'k-', 'LineWidth', 2);

                text(x_center, ...
                     max(vals) + 0.02*yrange, ...
                     sprintf('n=%d\nmed=%.2f', n_recordings_pool(g,p), med_val), ...
                     'HorizontalAlignment', 'center', ...
                     'VerticalAlignment', 'bottom', ...
                     'FontSize', 11, ...
                     'FontWeight', 'bold', ...
                     'Interpreter', 'none');
            end
        end

        ylim([min(0, ymin - 0.05*yrange), ymax + 0.20*yrange]);
    end

    xticks(1:num_pools);
    xticklabels(pooled_labels);

    title(measure_titles{mi}, ...
        'Interpreter', 'none', ...
        'FontSize', 22, ...
        'FontWeight', 'bold');

    ylabel(measure_titles{mi}, ...
        'Interpreter', 'none', ...
        'FontSize', 15);

    xlabel('Age group', ...
        'FontSize', 15);

    grid off;
    box off;
    xlim([0.5, num_pools + 0.5]);

    set(gca, ...
        'FontSize', 14, ...
        'LineWidth', 1.5, ...
        'TickDir', 'out');

    if mi == 2      % Frequency of SCEs panel

        legend_handles = gobjects(num_groups,1);
    
        for g = 1:num_groups
            legend_handles(g) = patch(NaN,NaN,colors(g,:), ...
                'FaceAlpha',0.85, ...
                'EdgeColor','none');
        end
    
        lgd = legend(legend_handles, legend_labels, ...
            'Location','northeast', ...
            'Interpreter','none', ...
            'FontSize',12, ...
            'Box','off');
    
    end
end

sgtitle(t, sprintf('Quantitative Analysis of Neuronal Network Activity Across Experimental Groups'), ...
    'Interpreter', 'none', ...
    'FontSize', 28, ...
    'FontWeight', 'bold');

end

function draw_single_violin(vals, x_center, max_width, color_val)

vals = vals(:);
vals = vals(isfinite(vals));

if isempty(vals)
    return;
end

if numel(vals) < 3
    plot(x_center, median(vals, 'omitnan'), 'o', ...
        'MarkerFaceColor', color_val, ...
        'MarkerEdgeColor', 'k', ...
        'MarkerSize', 7);
    return;
end

if numel(unique(vals)) == 1

    y = vals(1);

    plot([x_center - max_width/2, x_center + max_width/2], ...
         [y y], ...
         '-', ...
         'Color', color_val, ...
         'LineWidth', 3);
    return;
end

p1 = prctile(vals, 1);
p99 = prctile(vals, 99);

vals_density = vals(vals >= p1 & vals <= p99);

if numel(vals_density) < 3
    vals_density = vals;
end

try
    [density, y_grid] = ksdensity(vals_density);
catch
    [counts, edges] = histcounts(vals_density, 'Normalization', 'pdf');
    y_grid = edges(1:end-1) + diff(edges)/2;
    density = counts;
end

density = density(:);
y_grid = y_grid(:);

if isempty(density) || all(density == 0) || all(~isfinite(density))
    return;
end

density = density ./ max(density);
half_width = density .* max_width ./ 2;

x_left = x_center - half_width;
x_right = x_center + half_width;

patch([x_left; flipud(x_right)], ...
      [y_grid; flipud(y_grid)], ...
      color_val, ...
      'FaceAlpha', 0.45, ...
      'EdgeColor', color_val, ...
      'LineWidth', 1.3);

end

function nRec = get_nrec_from_results_analysis(results_analysis)

nRec = 0;

candidates = { ...
    {'general',     'DateName'}, ...
    {'gcamp_plane', 'FrequencyPerCell'}, ...
    {'gcamp_plane', 'ActiveCellsFrequency'}, ...
    {'gcamp_plane', 'BurstFraction'}, ...
    {'blue_plane',  'FrequencyPerCell'}, ...
    {'blue_plane',  'ActiveCellsFrequency'}, ...
    {'blue_plane',  'BurstFraction'}, ...
    {'SCEs',        'Frequency'}, ...
    {'SCEs',        'CellParticipation_percent'}};

for i = 1:numel(candidates)

    branch = candidates{i}{1};
    field  = candidates{i}{2};

    if isfield(results_analysis, branch) && ...
       isfield(results_analysis.(branch), field)

        C = results_analysis.(branch).(field);

        if iscell(C)
            nRec = max(nRec, numel(C));
        else
            nRec = max(nRec, numel(C));
        end
    end
end

end

function vals = extract_measure_values(results_analysis, m, branch_name, measure_name)

vals = [];

switch measure_name

    case 'ActivityFreq'
        vals = get_cell_field(results_analysis, branch_name, ...
            'FrequencyPerCell', m);

    case 'SCEFrequency'
        vals = get_cell_field(results_analysis, 'SCEs', ...
            'Frequency', m);

    case 'PairwiseCorr'
        if strcmp(branch_name, 'gcamp_plane')
            vals = get_cell_field(results_analysis, 'gcamp_plane', ...
                'max_corr_gcamp_gcamp_by_plane', m);
        elseif strcmp(branch_name, 'blue_plane')
            vals = get_cell_field(results_analysis, 'blue_plane', ...
                'max_corr_mtor_mtor_by_plane', m);
        else
            vals = [];
        end

    case 'propSCEs'
        vals = get_cell_field(results_analysis, 'SCEs', ...
            'CellParticipation_percent', m);
end

end

function vals = get_cell_field(S, branch_name, field_name, m)

vals = [];

if ~isfield(S, branch_name)
    return;
end

B = S.(branch_name);

if ~isfield(B, field_name)
    return;
end

C = B.(field_name);

if iscell(C)
    if numel(C) < m || isempty(C{m})
        return;
    end
    vals = C{m};
else
    vals = C;
end

end

function age_num = get_age_Frequency_from_animal(animal, m)

age_num = NaN;

if ~isfield(animal, 'ages') || isempty(animal.ages)
    return;
end

ages = animal.ages;

if iscell(ages)
    if numel(ages) < m || isempty(ages{m})
        return;
    end
    age_raw = ages{m};
else
    if numel(ages) < m
        return;
    end
    age_raw = ages(m);
end

age_num = parse_age(age_raw);

end

function age_num = parse_age(age_raw)

age_num = NaN;

if isempty(age_raw)
    return;
end

if isnumeric(age_raw)
    age_num = double(age_raw(1));
    return;
end

s = char(string(age_raw));
tok = regexp(s, 'P?(\d+)', 'tokens', 'once');

if ~isempty(tok)
    age_num = str2double(tok{1});
end

end

function x = flatten_numeric(x)

if isempty(x)
    x = [];
    return;
end

if iscell(x)
    tmp = [];

    for i = 1:numel(x)
        xi = flatten_numeric(x{i});
        tmp = [tmp; xi(:)]; %#ok<AGROW>
    end

    x = tmp;
    return;
end

if isstruct(x)
    x = [];
    return;
end

if isnumeric(x) || islogical(x)
    x = double(x(:));
else
    x = [];
end

end