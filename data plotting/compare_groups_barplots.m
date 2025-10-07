function [figs] = compare_groups_barplots(grouped_data_by_age, pooled_level)
    % Compare des groupes animaux par âge ou par groupes d’âges (pooled levels)
    % pooled_level = N  -> regroupe les âges par blocs de N (ex: 2 => P7-P8, P9-P10)
    % pooled_level = [] -> pas de pooling
    % pooled_level = cell array -> pooling personnalisé
    % Exclut Z < 50 µm et ajoute scatter points

    % --- Définir les groupes d’animaux ---
    animal_types = fieldnames(grouped_data_by_age);
    num_groups = numel(animal_types);
    colors = lines(num_groups);

    % --- Définir les mesures ---
    measures = {'NCells', 'Z_position', 'ActivityFreq', 'PairwiseCorr', ...
                'NumSCEs', 'SCE_Interv', 'SCEDuration', ...
                'propSCEs', 'Pburst', 'Stability'};

    measure_titles = {'NCells', ...
                      'Z Position (µm)', ...
                      'Activity Frequency (per minute)', ...
                      'Mean Pairwise Correlation (Fisher z normalized)', ...
                      'Number of SCEs', ...
                      'Inter-SCE Interval (s)', ...
                      'SCE Duration (ms)', ...
                      'Percentage of Active Cells in SCEs (averaged)', ...
                      'Fraction of events in bursts (P_burst)', ...
                      'Stability (mean successive Jaccard)'};

    % --- Âges disponibles ---
    base_ages = 7:15;
    age_labels = arrayfun(@(x) sprintf('P%d', x), base_ages, 'UniformOutput', false);

    % --- Gestion du pooling ---
    if nargin < 2 || isempty(pooled_level)
        pooled_level = num2cell(base_ages);
        pooled_labels = age_labels;

    elseif isnumeric(pooled_level)
        % Interprétation : "pooler chaque N âges consécutifs"
        pool_size = pooled_level;
        nAges = numel(base_ages);
        pooled_level = cell(1, ceil(nAges / pool_size));

        for i = 1:numel(pooled_level)
            start_idx = (i-1)*pool_size + 1;
            end_idx = min(i*pool_size, nAges);
            pooled_level{i} = base_ages(start_idx:end_idx);
        end

        pooled_labels = cellfun(@(x) sprintf('P%d–P%d', min(x), max(x)), pooled_level, 'UniformOutput', false);

    elseif iscell(pooled_level)
        % Si défini manuellement
        pooled_labels = cellfun(@(x) sprintf('P%d–P%d', min(x), max(x)), pooled_level, 'UniformOutput', false);
    else
        error('pooled_level must be numeric (e.g. 2, 3) or a cell array of age groups');
    end

    num_pools = numel(pooled_level);

    % --- Créer la figure principale ---
    figs = figure('Name', 'Comparing Animal Groups by Age / Pooled Levels', ...
                  'Position', [100, 100, 1400, 900]);

    num_measures = numel(measures);
    num_rows = ceil(num_measures / 2);
    num_columns = 2;

    % === Boucle sur chaque mesure ===
    for measureIdx = 1:num_measures
        subplot(num_rows, num_columns, measureIdx); hold on;
        measure_name = measures{measureIdx};

        means = nan(num_groups, num_pools);
        stds = nan(num_groups, num_pools);

        % --- Boucle sur les groupes d'animaux ---
        for groupIdx = 1:num_groups
            if ~isfield(grouped_data_by_age.(animal_types{groupIdx}), measure_name)
                warning('Measure "%s" not found for group "%s". Skipped.', ...
                        measure_name, animal_types{groupIdx});
                continue;
            end

            data_by_age = grouped_data_by_age.(animal_types{groupIdx}).(measure_name);

            % === Filtrage spécial pour la profondeur ===
            if strcmp(measure_name, 'Z_position')
                data_by_age(data_by_age < 50) = NaN; % exclure < 50 µm
            end

            % === Fisher-z pour corrélation ===
            if strcmp(measure_name, 'PairwiseCorr')
                data_by_age(abs(data_by_age) >= 1) = NaN;
                data_by_age = 0.5 * log((1 + data_by_age) ./ (1 - data_by_age));
            end

            % === Pooling ===
            for poolIdx = 1:num_pools
                current_pool = pooled_level{poolIdx};
                valid_rows = ismember(base_ages, current_pool);
                pooled_data = data_by_age(valid_rows, :);
                pooled_data = pooled_data(:);
                pooled_data = pooled_data(~isnan(pooled_data));

                if ~isempty(pooled_data)
                    means(groupIdx, poolIdx) = mean(pooled_data);
                    stds(groupIdx, poolIdx) = std(pooled_data);
                end
            end
        end

        % --- Barplot ---
        b = bar(means', 'grouped'); hold on;
        for g = 1:num_groups
            b(g).FaceColor = colors(g,:);
            b(g).EdgeColor = 'none';
            b(g).FaceAlpha = 0.8;
        end

        % --- Barres d'erreur ---
        for groupIdx = 1:num_groups
            if groupIdx <= numel(b)
                x = b(groupIdx).XEndPoints;
                y = means(groupIdx, :);
                err = stds(groupIdx, :);
                errorbar(x, y, err, 'k.', 'LineWidth', 1);
            end
        end

        % --- Scatters individuels ---
        offset = linspace(-0.15, 0.15, num_groups);
        for groupIdx = 1:num_groups
            data_by_age = grouped_data_by_age.(animal_types{groupIdx}).(measure_name);
            if strcmp(measure_name, 'Z_position')
                data_by_age(data_by_age < 50) = NaN;
            end
            for poolIdx = 1:num_pools
                current_pool = pooled_level{poolIdx};
                valid_rows = ismember(base_ages, current_pool);
                pooled_data = data_by_age(valid_rows, :);
                pooled_data = pooled_data(:);
                pooled_data = pooled_data(~isnan(pooled_data));
                scatter(ones(size(pooled_data))*(poolIdx + offset(groupIdx)), ...
                        pooled_data, 40, colors(groupIdx,:), ...
                        'filled', 'MarkerEdgeColor', 'k', 'MarkerFaceAlpha', 0.9);
            end
        end

        % --- Mise en forme ---
        xticks(1:num_pools);
        xticklabels(pooled_labels);
        title(measure_titles{measureIdx}, 'Interpreter', 'none');
        ylabel(measure_titles{measureIdx});
        xlabel('Age group');
        legend(animal_types, 'Location', 'bestoutside');
        grid on;

        ymax = max(means(:) + stds(:), [], 'omitnan');
        if isempty(ymax) || isnan(ymax) || ymax == 0
            ymax = 1;
        end
        ylim([0, ymax * 1.2]);
    end

    sgtitle('Comparison of Measures Between Animal Groups by Age / Pooled Levels');
    figs = gcf;
end
