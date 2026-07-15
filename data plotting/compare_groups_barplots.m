function [figs, stats_results, plot_table] = compare_groups_barplots( ...
    results_table, pooled_level, branch_name)
% COMPARE_GROUPS_BARPLOTS
% Compare les mesures quantitatives entre les types et les groupes d'âge
% avec un modèle linéaire mixte :
%
%   Value ~ Type * AgeGroup + (1|Animal)
%
% Les données sont d'abord moyennées au niveau Animal x AgeGroup afin que
% plusieurs plans ou plusieurs sessions d'un même animal ne soient pas
% considérés comme des répétitions biologiques indépendantes.
%
% SORTIES
%   figs          : handle de la figure
%   stats_results : structure contenant le modèle, l'ANOVA et les post-hoc
%   plot_table    : table agrégée réellement utilisée pour les figures/tests
%
% EXEMPLE
%   [figs, stats_results, plot_table] = ...
%       compare_groups_barplots(results_table, [], 'gcamp_plane');
%
%   Avec regroupement des âges deux par deux :
%   [figs, stats_results] = ...
%       compare_groups_barplots(results_table, 2, 'gcamp_plane');

    if nargin < 2
        pooled_level = [];
    end

    if nargin < 3 || isempty(branch_name)
        branch_name = 'gcamp_plane';
    end

    branch_name = string(branch_name);

    % ============================================================
    % Conditions minimales pour lancer la comparaison
    % ============================================================

    valid_age_mask = ...
        isfinite(results_table.AgeNumber) & ...
        results_table.AgeNumber >= 7 & ...
        results_table.AgeNumber <= 15;

    results_table = results_table(valid_age_mask, :);

    if isempty(results_table)
        figs = [];
        stats_results = struct();
        plot_table = table();

        fprintf( ...
            'compare_groups_barplots skipped: no data between P7 and P15.\n');
        return;
    end

    available_types = unique(string(results_table.Type));
    available_types = available_types(strlength(available_types) > 0);

    if numel(available_types) < 2
        figs = [];
        stats_results = struct();
        plot_table = table();

        fprintf([ ...
            'compare_groups_barplots skipped: ', ...
            'at least two animal types are required.\n']);
        return;
    end

    validate_results_table(results_table);
    
    % ============================================================
    % Couleurs
    % ============================================================
    colors = lines(num_groups);

    for g = 1:num_groups
        switch upper(animal_types(g))
            case "WT"
                colors(g,:) = [0 0.60 0];
            case "FCD"
                colors(g,:) = [0 0.45 0.74];
        end
    end

    % ============================================================
    % Mesures affichées
    % ============================================================
    measures = [ ...
        "ActivityFreq", ...
        "SCEFrequency", ...
        "PairwiseCorr", ...
        "propSCEs"];

    measure_titles = [ ...
        "Activity Frequency (events/min)", ...
        "SCE Frequency (events/min)", ...
        "Mean Pairwise Correlation", ...
        "SCE Size (% Active Cells)"];

    % ============================================================
    % Définition des groupes d'âge
    % ============================================================
    valid_age_rows = isfinite(results_table.AgeNumber);
    base_ages = unique(results_table.AgeNumber(valid_age_rows));
    base_ages = sort(base_ages(:)');

    if isempty(base_ages)
        error('No valid AgeNumber values were found in results_table.');
    end

    [age_pools, pooled_labels] = make_age_pools(base_ages, pooled_level);
    num_pools = numel(age_pools);

    % ============================================================
    % Construction d'une table standardisée pour les quatre mesures
    % ============================================================
    raw_plot_table = init_raw_plot_table();

    for mi = 1:numel(measures)

        measure_name = measures(mi);

        metric_rows = select_metric_rows( ...
            results_table, branch_name, measure_name);

        if isempty(metric_rows)
            warning('No data found for measure %s.', measure_name);
            continue;
        end

        metric_rows.Type = string(metric_rows.Type);
        metric_rows.Animal = string(metric_rows.Animal);

        for r = 1:height(metric_rows)

            age_number = metric_rows.AgeNumber(r);
            pool_index = find_age_pool(age_number, age_pools);

            if isempty(pool_index)
                continue;
            end

            value = metric_rows.Value(r);

            if ~isfinite(value)
                continue;
            end

            if measure_name == "PairwiseCorr" && abs(value) > 1
                continue;
            end

            new_row = table( ...
                string(metric_rows.Type(r)), ...
                string(metric_rows.Animal(r)), ...
                double(age_number), ...
                string(pooled_labels{pool_index}), ...
                double(pool_index), ...
                measure_name, ...
                double(value), ...
                'VariableNames', raw_plot_table.Properties.VariableNames);

            raw_plot_table = [raw_plot_table; new_row]; %#ok<AGROW>
        end
    end

    if isempty(raw_plot_table)
        error('No valid quantitative data were found.');
    end

    % ============================================================
    % Moyenne par Animal x Type x AgeGroup x Measure
    % ============================================================
    plot_table = groupsummary( ...
        raw_plot_table, ...
        {'Type','Animal','AgeGroup','AgeGroupIndex','Measure'}, ...
        'mean', ...
        'Value');

    plot_table.Properties.VariableNames{ ...
        strcmp(plot_table.Properties.VariableNames, 'mean_Value')} = 'Value';

    if ismember('GroupCount', plot_table.Properties.VariableNames)
        plot_table.Properties.VariableNames{ ...
            strcmp(plot_table.Properties.VariableNames, 'GroupCount')} = ...
            'NRowsAveraged';
    end

    % Catégories ordonnées
    plot_table.Type = categorical( ...
        string(plot_table.Type), ...
        cellstr(animal_types), ...
        'Ordinal', true);

    plot_table.AgeGroup = categorical( ...
        string(plot_table.AgeGroup), ...
        pooled_labels, ...
        'Ordinal', true);

    plot_table.Animal = categorical(plot_table.Animal);
    plot_table.Measure = categorical(plot_table.Measure);

    % ============================================================
    % Comptages pour la légende
    % ============================================================
    legend_labels = cell(num_groups,1);

    for g = 1:num_groups
        group_mask = string(plot_table.Type) == animal_types(g);
        n_animals = numel(unique(plot_table.Animal(group_mask)));

        source_mask = string(results_table.Type) == animal_types(g);
        n_sessions = numel(unique(string(results_table.SessionID(source_mask))));

        legend_labels{g} = sprintf( ...
            '%s (n=%d animals, %d sessions)', ...
            animal_types(g), n_animals, n_sessions);
    end

    % ============================================================
    % Figure
    % ============================================================
    figs = figure( ...
        'Name', 'Quantitative comparison of neuronal network activity', ...
        'Color', 'w', ...
        'Position', [50, 50, 1500, 900]);

    tiled = tiledlayout(figs, 2, 2, ...
        'TileSpacing', 'compact', ...
        'Padding', 'compact');

    stats_results = struct();

    % ============================================================
    % Boucle sur les mesures
    % ============================================================
    for mi = 1:numel(measures)

        ax = nexttile(tiled);
        hold(ax, 'on');

        measure_name = measures(mi);
        measure_title = measure_titles(mi);

        measure_table = plot_table( ...
            string(plot_table.Measure) == measure_name, :);

        if isempty(measure_table)
            title(ax, measure_title + " (no data)", ...
                'Interpreter', 'none', ...
                'FontSize', 18, ...
                'FontWeight', 'bold');
            axis(ax, 'off');
            continue;
        end

        % --------------------------------------------------------
        % Modèle mixte et post-hoc
        % --------------------------------------------------------
        try
            [lme, anova_table, comparisons] = ...
                run_mixed_model_with_posthoc( ...
                    measure_table, animal_types, pooled_labels);

            stats_results.(char(measure_name)).Model = lme;
            stats_results.(char(measure_name)).ANOVA = anova_table;
            stats_results.(char(measure_name)).Comparisons = comparisons;

        catch ME
            warning('Statistics failed for %s: %s', ...
                measure_name, ME.message);

            lme = [];
            anova_table = table();
            comparisons = table();

            stats_results.(char(measure_name)).Error = ME.message;
        end

        % --------------------------------------------------------
        % Tracé
        % --------------------------------------------------------
        [x_positions, plot_top] = plot_measure_panel( ...
            ax, measure_table, measure_name, ...
            animal_types, pooled_labels, colors);

        % --------------------------------------------------------
        % Significativité
        % --------------------------------------------------------
        if ~isempty(comparisons)
            add_significance_bars( ...
                ax, comparisons, x_positions, plot_top, ...
                animal_types, pooled_labels);
        end

        % --------------------------------------------------------
        % Résultats globaux du modèle
        % --------------------------------------------------------
        if ~isempty(anova_table)
            add_model_summary_text(ax, anova_table);
        end

        xticks(ax, 1:num_pools);
        xticklabels(ax, pooled_labels);

        title(ax, measure_title, ...
            'Interpreter', 'none', ...
            'FontSize', 22, ...
            'FontWeight', 'bold');

        ylabel(ax, measure_title, ...
            'Interpreter', 'none', ...
            'FontSize', 15);

        xlabel(ax, 'Age group', 'FontSize', 15);

        grid(ax, 'off');
        box(ax, 'off');
        xlim(ax, [0.5, num_pools + 0.5]);

        set(ax, ...
            'FontSize', 14, ...
            'LineWidth', 1.5, ...
            'TickDir', 'out');

        % Légende sur le panneau SCE Frequency
        if mi == 2
            legend_handles = gobjects(num_groups,1);

            for g = 1:num_groups
                legend_handles(g) = patch(ax, NaN, NaN, colors(g,:), ...
                    'FaceAlpha', 0.85, ...
                    'EdgeColor', 'none');
            end

            legend(ax, legend_handles, legend_labels, ...
                'Location', 'northeast', ...
                'Interpreter', 'none', ...
                'FontSize', 12, ...
                'Box', 'off');
        end
    end

    sgtitle(tiled, ...
        'Quantitative Analysis of Neuronal Network Activity Across Experimental Groups', ...
        'Interpreter', 'none', ...
        'FontSize', 28, ...
        'FontWeight', 'bold');
end


% ========================================================================
% VALIDATION
% ========================================================================
function validate_results_table(results_table)

    if ~istable(results_table)
        error('results_table must be a MATLAB table.');
    end

    required_variables = { ...
        'Type', ...
        'Animal', ...
        'AgeNumber', ...
        'SessionID', ...
        'Branch', ...
        'Metric', ...
        'Value'};

    missing = required_variables( ...
        ~ismember(required_variables, ...
        results_table.Properties.VariableNames));

    if ~isempty(missing)
        error('Missing variables in results_table: %s', ...
            strjoin(missing, ', '));
    end
end


% ========================================================================
% TABLE STANDARDISÉE
% ========================================================================
function T = init_raw_plot_table()

    T = table( ...
        string.empty(0,1), ... % Type
        string.empty(0,1), ... % Animal
        nan(0,1), ...          % OriginalAge
        string.empty(0,1), ... % AgeGroup
        nan(0,1), ...          % AgeGroupIndex
        string.empty(0,1), ... % Measure
        nan(0,1), ...          % Value
        'VariableNames', { ...
            'Type', ...
            'Animal', ...
            'OriginalAge', ...
            'AgeGroup', ...
            'AgeGroupIndex', ...
            'Measure', ...
            'Value'});
end


% ========================================================================
% SÉLECTION DES MÉTRIQUES DANS results_table
% ========================================================================
function T = select_metric_rows(results_table, branch_name, measure_name)

    branch = string(results_table.Branch);
    metric = string(results_table.Metric);

    switch measure_name

        case "ActivityFreq"
            mask = branch == branch_name & ...
                   metric == "FrequencyPerCell";

        case "SCEFrequency"
            mask = branch == "SCEs" & ...
                   metric == "Frequency";

        case "PairwiseCorr"
            if branch_name == "gcamp_plane"
                target_metric = "PairwiseCorrelation_GCaMP_GCaMP";
            elseif branch_name == "blue_plane"
                target_metric = "PairwiseCorrelation_mTOR_mTOR";
            else
                error('Unsupported branch_name for PairwiseCorr: %s', ...
                    branch_name);
            end

            mask = branch == branch_name & ...
                   metric == target_metric;

        case "propSCEs"
            mask = branch == "SCEs" & ...
                   metric == "CellParticipation";

        otherwise
            error('Unknown measure: %s', measure_name);
    end

    T = results_table(mask, :);
end


% ========================================================================
% GROUPES D'ÂGE
% ========================================================================
function [age_pools, pooled_labels] = make_age_pools(base_ages, pooled_level)

    if isempty(pooled_level)

        age_pools = num2cell(base_ages);
        pooled_labels = arrayfun( ...
            @(x) sprintf('P%d', x), ...
            base_ages, ...
            'UniformOutput', false);

    elseif isnumeric(pooled_level) && isscalar(pooled_level)

        pool_size = pooled_level;

        if pool_size < 1 || mod(pool_size,1) ~= 0
            error('Numeric pooled_level must be a positive integer.');
        end

        age_pools = cell(1, ceil(numel(base_ages) / pool_size));

        for i = 1:numel(age_pools)
            i1 = (i-1) * pool_size + 1;
            i2 = min(i * pool_size, numel(base_ages));
            age_pools{i} = base_ages(i1:i2);
        end

        pooled_labels = cellfun( ...
            @make_age_pool_label, ...
            age_pools, ...
            'UniformOutput', false);

    elseif iscell(pooled_level)

        age_pools = pooled_level;
        pooled_labels = cellfun( ...
            @make_age_pool_label, ...
            age_pools, ...
            'UniformOutput', false);

    else
        error('pooled_level must be empty, a positive integer, or a cell array.');
    end
end


function label = make_age_pool_label(age_values)

    age_values = age_values(:)';
    age_values = sort(age_values);

    if numel(age_values) == 1
        label = sprintf('P%d', age_values);
    else
        label = sprintf('P%d-P%d', min(age_values), max(age_values));
    end
end


function pool_index = find_age_pool(age_number, age_pools)

    pool_index = [];

    for p = 1:numel(age_pools)
        if ismember(age_number, age_pools{p})
            pool_index = p;
            return;
        end
    end
end


% ========================================================================
% MODÈLE MIXTE
% ========================================================================
function [lme, anova_table, comparisons] = ...
    run_mixed_model_with_posthoc(T, type_order, age_order)

    T = T(:, {'Animal','Type','AgeGroup','Value'});
    T = rmmissing(T);

    T.Type = removecats(T.Type);
    T.AgeGroup = removecats(T.AgeGroup);
    T.Animal = removecats(T.Animal);

    present_types = type_order( ...
        ismember(type_order, string(categories(T.Type))));

    present_ages = string(age_order( ...
        ismember(string(age_order), string(categories(T.AgeGroup)))));

    T.Type = categorical( ...
        string(T.Type), cellstr(present_types), 'Ordinal', true);

    T.AgeGroup = categorical( ...
        string(T.AgeGroup), cellstr(present_ages), 'Ordinal', true);

    T.Animal = categorical(T.Animal);

    if numel(categories(T.Type)) < 2
        error('At least two types are required for the mixed model.');
    end

    if numel(categories(T.AgeGroup)) < 2
        error('At least two age groups are required for the Type x Age model.');
    end

    lme = fitlme( ...
        T, ...
        'Value ~ Type*AgeGroup + (1|Animal)', ...
        'FitMethod', 'REML', ...
        'DummyVarCoding', 'reference');

    anova_table = anova( ...
        lme, ...
        'DFMethod', 'Satterthwaite');

    comparisons = pairwise_type_comparisons( ...
        lme, T, present_types, present_ages);
end


% ========================================================================
% POST-HOC : TYPES DANS CHAQUE GROUPE D'ÂGE
% ========================================================================
function comparisons = pairwise_type_comparisons( ...
    lme, T, type_order, age_order)

    coefficient_names = string(lme.CoefficientNames);
    beta = fixedEffects(lme);

    type_pairs = nchoosek(1:numel(type_order), 2);

    comparisons = init_comparisons_table();

    for age_idx = 1:numel(age_order)

        age_name = age_order(age_idx);

        age_rows = init_comparisons_table();

        for pair_idx = 1:size(type_pairs,1)

            type1 = type_order(type_pairs(pair_idx,1));
            type2 = type_order(type_pairs(pair_idx,2));

            type1_exists = any( ...
                string(T.Type) == type1 & ...
                string(T.AgeGroup) == age_name);

            type2_exists = any( ...
                string(T.Type) == type2 & ...
                string(T.AgeGroup) == age_name);

            if ~type1_exists || ~type2_exists
                continue;
            end

            x1 = fixed_effect_design_row( ...
                type1, age_name, coefficient_names, ...
                type_order(1), age_order(1));

            x2 = fixed_effect_design_row( ...
                type2, age_name, coefficient_names, ...
                type_order(1), age_order(1));

            contrast = x1 - x2;

            estimate = contrast * beta;

            [p_value, F_value, df_num, df_den] = coefTest( ...
                lme, contrast, 0, ...
                'DFMethod', 'Satterthwaite');

            if F_value >= 0
                t_value = sign(estimate) * sqrt(F_value);
            else
                t_value = NaN;
            end

            row = table( ...
                age_name, ...
                type1, ...
                type2, ...
                double(estimate), ...
                double(t_value), ...
                double(df_num), ...
                double(df_den), ...
                double(p_value), ...
                NaN, ...
                "", ...
                'VariableNames', ...
                age_rows.Properties.VariableNames);

            age_rows = [age_rows; row]; %#ok<AGROW>
        end

        if ~isempty(age_rows)
            age_rows.PAdjusted = holm_correction(age_rows.PValue);
            age_rows.Significance = arrayfun( ...
                @p_to_stars, ...
                age_rows.PAdjusted, ...
                'UniformOutput', false);
            age_rows.Significance = string(age_rows.Significance);

            comparisons = [comparisons; age_rows]; %#ok<AGROW>
        end
    end
end


function T = init_comparisons_table()

    T = table( ...
        string.empty(0,1), ...
        string.empty(0,1), ...
        string.empty(0,1), ...
        nan(0,1), ...
        nan(0,1), ...
        nan(0,1), ...
        nan(0,1), ...
        nan(0,1), ...
        nan(0,1), ...
        string.empty(0,1), ...
        'VariableNames', { ...
            'AgeGroup', ...
            'Type1', ...
            'Type2', ...
            'Estimate', ...
            'TValue', ...
            'DFNumerator', ...
            'DFDenominator', ...
            'PValue', ...
            'PAdjusted', ...
            'Significance'});
end


% ========================================================================
% LIGNE DE DESIGN POUR UNE COMBINAISON TYPE x AGE
% ========================================================================
function x = fixed_effect_design_row( ...
    type_name, age_name, coefficient_names, ...
    reference_type, reference_age)

    x = zeros(1, numel(coefficient_names));

    for c = 1:numel(coefficient_names)

        coefficient = coefficient_names(c);

        if coefficient == "(Intercept)"
            x(c) = 1;
            continue;
        end

        type_term = "Type_" + type_name;
        age_term = "AgeGroup_" + age_name;

        if coefficient == type_term
            x(c) = type_name ~= reference_type;

        elseif coefficient == age_term
            x(c) = age_name ~= reference_age;

        elseif contains(coefficient, ":")

            interaction1 = type_term + ":" + age_term;
            interaction2 = age_term + ":" + type_term;

            if coefficient == interaction1 || coefficient == interaction2
                x(c) = ...
                    type_name ~= reference_type && ...
                    age_name ~= reference_age;
            end
        end
    end
end


% ========================================================================
% CORRECTION DE HOLM
% ========================================================================
function adjusted_p = holm_correction(raw_p)

    raw_p = raw_p(:);
    adjusted_p = nan(size(raw_p));

    valid = isfinite(raw_p);
    p = raw_p(valid);

    if isempty(p)
        return;
    end

    [sorted_p, order] = sort(p);
    m = numel(sorted_p);

    sorted_adjusted = nan(m,1);

    for i = 1:m
        sorted_adjusted(i) = (m - i + 1) * sorted_p(i);
    end

    sorted_adjusted = cummax(sorted_adjusted);
    sorted_adjusted = min(sorted_adjusted, 1);

    unsorted_adjusted = nan(m,1);
    unsorted_adjusted(order) = sorted_adjusted;

    adjusted_p(valid) = unsorted_adjusted;
end


function stars = p_to_stars(p)

    if ~isfinite(p)
        stars = "n/a";
    elseif p < 0.0001
        stars = "****";
    elseif p < 0.001
        stars = "***";
    elseif p < 0.01
        stars = "**";
    elseif p < 0.05
        stars = "*";
    else
        stars = "ns";
    end
end


% ========================================================================
% TRACÉ D'UN PANNEAU
% ========================================================================
function [x_positions, plot_top] = plot_measure_panel( ...
    ax, T, measure_name, animal_types, age_labels, colors)

    num_groups = numel(animal_types);
    num_pools = numel(age_labels);

    means = nan(num_groups, num_pools);
    stds = nan(num_groups, num_pools);
    medians = nan(num_groups, num_pools);
    values_by_group = cell(num_groups, num_pools);

    for g = 1:num_groups
        for p = 1:num_pools

            mask = ...
                string(T.Type) == animal_types(g) & ...
                string(T.AgeGroup) == string(age_labels{p});

            values = T.Value(mask);
            values = values(isfinite(values));

            values_by_group{g,p} = values;

            if isempty(values)
                continue;
            end

            means(g,p) = mean(values, 'omitnan');
            stds(g,p) = std(values, 'omitnan');
            medians(g,p) = median(values, 'omitnan');
        end
    end

    all_values = T.Value(isfinite(T.Value));

    ymin = min(all_values);
    ymax = max(all_values);

    if ymax <= ymin
        ymax = ymin + 1;
    end

    yrange = ymax - ymin;

    group_width = 0.60;
    offsets = linspace( ...
        -group_width/2 + group_width/(2*num_groups), ...
         group_width/2 - group_width/(2*num_groups), ...
         num_groups);

    x_positions = nan(num_groups, num_pools);

    for g = 1:num_groups
        x_positions(g,:) = (1:num_pools) + offsets(g);
    end

    if measure_name == "SCEFrequency"

        b = bar(ax, means', 'grouped');

        for g = 1:num_groups
            b(g).FaceColor = colors(g,:);
            b(g).EdgeColor = 'none';
            b(g).FaceAlpha = 0.85;

            if isprop(b(g), 'XEndPoints')
                x_positions(g,:) = b(g).XEndPoints;
            end
        end

        for g = 1:num_groups
            errorbar(ax, ...
                x_positions(g,:), ...
                means(g,:), ...
                stds(g,:), ...
                'k.', ...
                'LineWidth', 1.5, ...
                'CapSize', 8);

            for p = 1:num_pools
                values = values_by_group{g,p};

                if isempty(values)
                    continue;
                end

                jitter = linspace(-0.025, 0.025, numel(values));

                scatter(ax, ...
                    x_positions(g,p) + jitter, ...
                    values, ...
                    28, ...
                    'k', ...
                    'filled', ...
                    'MarkerFaceAlpha', 0.65);
            end
        end

        plot_top = max(means(:) + stds(:), [], 'omitnan');

    else

        violin_width = group_width / max(num_groups,1) * 0.70;

        for p = 1:num_pools
            for g = 1:num_groups

                values = values_by_group{g,p};

                if isempty(values)
                    continue;
                end

                x_center = x_positions(g,p);

                draw_single_violin( ...
                    ax, values, x_center, violin_width, colors(g,:));

                plot(ax, ...
                    [x_center - violin_width*0.22, ...
                     x_center + violin_width*0.22], ...
                    [medians(g,p), medians(g,p)], ...
                    'k-', ...
                    'LineWidth', 2);

                jitter = linspace(-0.025, 0.025, numel(values));

                scatter(ax, ...
                    x_center + jitter, ...
                    values, ...
                    22, ...
                    'k', ...
                    'filled', ...
                    'MarkerFaceAlpha', 0.55);
            end
        end

        plot_top = ymax;
    end

    if ~isfinite(plot_top)
        plot_top = ymax;
    end

    lower_limit = min(0, ymin - 0.05*yrange);
    upper_limit = plot_top + 0.30*yrange;

    if measure_name == "PairwiseCorr"
        lower_limit = min(lower_limit, ymin - 0.05*yrange);
    end

    ylim(ax, [lower_limit, upper_limit]);
end


function draw_single_violin(ax, vals, x_center, max_width, color_val)

    vals = vals(:);
    vals = vals(isfinite(vals));

    if isempty(vals)
        return;
    end

    if numel(vals) < 3
        plot(ax, x_center, median(vals, 'omitnan'), 'o', ...
            'MarkerFaceColor', color_val, ...
            'MarkerEdgeColor', 'k', ...
            'MarkerSize', 7);
        return;
    end

    if numel(unique(vals)) == 1
        y = vals(1);

        plot(ax, ...
            [x_center - max_width/2, x_center + max_width/2], ...
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
        [counts, edges] = histcounts( ...
            vals_density, ...
            'Normalization', 'pdf');

        y_grid = edges(1:end-1) + diff(edges)/2;
        density = counts;
    end

    density = density(:);
    y_grid = y_grid(:);

    if isempty(density) || ...
            all(density == 0) || ...
            all(~isfinite(density))
        return;
    end

    density = density ./ max(density);
    half_width = density .* max_width ./ 2;

    x_left = x_center - half_width;
    x_right = x_center + half_width;

    patch(ax, ...
        [x_left; flipud(x_right)], ...
        [y_grid; flipud(y_grid)], ...
        color_val, ...
        'FaceAlpha', 0.45, ...
        'EdgeColor', color_val, ...
        'LineWidth', 1.3);
end


% ========================================================================
% BARRES DE SIGNIFICATIVITÉ
% ========================================================================
function add_significance_bars( ...
    ax, comparisons, x_positions, plot_top, animal_types, age_labels)

    significant = comparisons( ...
        isfinite(comparisons.PAdjusted) & ...
        comparisons.PAdjusted < 0.05, :);

    if isempty(significant)
        return;
    end

    y_limits = ylim(ax);
    y_range = y_limits(2) - y_limits(1);

    if y_range <= 0
        y_range = 1;
    end

    maximum_height = y_limits(2);

    for age_index = 1:numel(age_labels)

        age_name = string(age_labels{age_index});
        rows = significant(significant.AgeGroup == age_name, :);

        if isempty(rows)
            continue;
        end

        base_y = max(plot_top, y_limits(1)) + 0.05*y_range;

        for r = 1:height(rows)

            type1_index = find(animal_types == rows.Type1(r), 1);
            type2_index = find(animal_types == rows.Type2(r), 1);

            if isempty(type1_index) || isempty(type2_index)
                continue;
            end

            x1 = x_positions(type1_index, age_index);
            x2 = x_positions(type2_index, age_index);

            y = base_y + (r-1) * 0.08*y_range;
            tick_height = 0.015*y_range;

            plot(ax, ...
                [x1 x1 x2 x2], ...
                [y-tick_height y y y-tick_height], ...
                'k-', ...
                'LineWidth', 1.2);

            text(ax, ...
                mean([x1 x2]), ...
                y + 0.005*y_range, ...
                rows.Significance(r), ...
                'HorizontalAlignment', 'center', ...
                'VerticalAlignment', 'bottom', ...
                'FontSize', 13, ...
                'FontWeight', 'bold');

            maximum_height = max(maximum_height, y + 0.06*y_range);
        end
    end

    ylim(ax, [y_limits(1), maximum_height]);
end


% ========================================================================
% TEXTE DU MODÈLE GLOBAL
% ========================================================================
function add_model_summary_text(ax, anova_table)

    term_names = string(anova_table.Term);

    p_type = get_anova_pvalue(anova_table, term_names, "Type");
    p_age = get_anova_pvalue(anova_table, term_names, "AgeGroup");
    p_interaction = get_anova_pvalue( ...
        anova_table, term_names, "Type:AgeGroup");

    summary_text = sprintf( ...
        'LME: Type %s | Age %s | Type x Age %s', ...
        format_pvalue(p_type), ...
        format_pvalue(p_age), ...
        format_pvalue(p_interaction));

    text(ax, ...
        0.01, 0.99, ...
        summary_text, ...
        'Units', 'normalized', ...
        'HorizontalAlignment', 'left', ...
        'VerticalAlignment', 'top', ...
        'FontSize', 10, ...
        'Interpreter', 'none');
end


function p = get_anova_pvalue(anova_table, term_names, target_term)

    p = NaN;

    index = find(term_names == target_term, 1);

    if isempty(index) && target_term == "Type:AgeGroup"
        index = find(term_names == "AgeGroup:Type", 1);
    end

    if isempty(index)
        return;
    end

    % anova(lme) peut renvoyer une table ou un ancien objet dataset
    if istable(anova_table)

        variable_names = ...
            anova_table.Properties.VariableNames;

    elseif isa(anova_table, 'dataset')

        variable_names = ...
            get(anova_table, 'VarNames');

    else

        warning( ...
            'Unsupported ANOVA result type: %s', ...
            class(anova_table));

        return;
    end

    if ismember('pValue', variable_names)

        p_values = anova_table.pValue;
        p = double(p_values(index));

    elseif ismember('pValueDF2', variable_names)

        p_values = anova_table.pValueDF2;
        p = double(p_values(index));
    end
end


function text_value = format_pvalue(p)

    if ~isfinite(p)
        text_value = 'p=n/a';
    elseif p < 0.0001
        text_value = 'p<0.0001';
    else
        text_value = sprintf('p=%.4f', p);
    end
end
