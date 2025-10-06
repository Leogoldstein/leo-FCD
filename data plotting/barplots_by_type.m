function [grouped_data_by_age, figs] = barplots_by_type(selected_groups)

    animal_types = {'jm', 'FCD', 'WT'};
    num_types = numel(animal_types);

    grouped_data_by_age = struct(); 
    figs = struct();

    % Grouper les selected_groups par type d'animal
    for typeIdx = 1:num_types
        current_type = animal_types{typeIdx};
        type_groups_idx = find(arrayfun(@(x) strcmp(x.animal_type, current_type), selected_groups));

        if isempty(type_groups_idx)
            continue;
        end

        groups_subset = selected_groups(type_groups_idx);
        num_groups = length(groups_subset);
        animal_group = cell(num_groups, 1);
        colors = lines(num_groups);

        % Définition des âges
        age_labels = {'P7', 'P8', 'P9', 'P10', 'P11', 'P12', 'P13', 'P14', 'P15'};
        age_values = 7:15;

        % === Conteneur des données ===
        data_by_age = struct('NCells', nan(numel(age_labels), num_groups), ...
                             'ActivityFreq', nan(numel(age_labels), num_groups), ...
                             'PairwiseCorr', nan(numel(age_labels), num_groups), ...
                             'NumSCEs', nan(numel(age_labels), num_groups), ...
                             'SCE_Interv', nan(numel(age_labels), num_groups), ...
                             'SCEDuration', nan(numel(age_labels), num_groups), ...
                             'propSCEs', nan(numel(age_labels), num_groups), ...
                             'Pburst', nan(numel(age_labels), num_groups));

        % === Parcours des groupes d'animaux ===
        for groupIdx = 1:num_groups
            current_animal_group = groups_subset(groupIdx).animal_group;
            animal_group{groupIdx} = current_animal_group;
            current_dates_group = groups_subset(groupIdx).dates;
            current_ages_group = groups_subset(groupIdx).ages;
            data = groups_subset(groupIdx).data;

            current_ages = cellfun(@(x) str2double(x(2:end)), current_ages_group);
            [~, x_indices] = ismember(current_ages, age_values);

            for pathIdx = 1:length(current_dates_group)
                try
                    DF             = data.DF_gcamp{pathIdx};
                    Acttmp2        = data.Acttmp2_gcamp{pathIdx};
                    Raster         = data.Raster_gcamp{pathIdx};
                    TRace          = data.TRace_gcamp{pathIdx};
                    RasterRace     = data.RasterRace_gcamp{pathIdx};
                    sces_distances = data.sces_distances_gcamp{pathIdx};
                    sampling_rate  = data.sampling_rate{pathIdx};
                    all_max_corr_gcamp_gcamp = data.max_corr_gcamp_gcamp{pathIdx};
                    
                    % Vérifier cohérence DF / Raster
                    if size(DF, 1) ~= size(Raster, 1)
                        warning('Mismatch in number of neurons between DF and Raster for group %d.', groupIdx);
                        min_cells = min(size(DF, 1), size(Raster, 1));
                        DF = DF(1:min_cells, :);
                        Raster = Raster(1:min_cells, :);
                    end
                    if size(DF, 2) ~= size(Raster, 2)
                        warning('Mismatch in number of frames between DF and Raster for group %d.', groupIdx);
                        min_frames = min(size(DF, 2), size(Raster, 2));
                        DF = DF(:, 1:min_frames);
                        Raster = Raster(:, 1:min_frames);
                    end

                    % === Mesures ===
                    [NCell, Nz] = size(Raster);

                    % Fréquence d'activité (événements/minute)
                    frequency = zeros(1, NCell);
                    for i = 1:NCell
                        frequency(i) = numel(Acttmp2{i}) / Nz * sampling_rate * 60;
                    end
                    activity_frequency_minutes = mean(frequency, 'omitnan');

                    % Corrélation pairwise (Fisher z)
                    if ~isempty(all_max_corr_gcamp_gcamp) && isnumeric(all_max_corr_gcamp_gcamp)
                        r = all_max_corr_gcamp_gcamp(:);
                        r = r(~isnan(r) & abs(r) < 1);
                        if ~isempty(r)
                            z = 0.5 * log((1 + r) ./ (1 - r));
                            mean_z = mean(z, 'omitnan');
                            mean_pairwise_corr = (exp(2*mean_z) - 1) / (exp(2*mean_z) + 1);
                        else
                            mean_pairwise_corr = NaN;
                        end
                    else
                        mean_pairwise_corr = NaN;
                    end

                    % Nombre de SCEs
                    num_sces = numel(TRace);

                    % === Intervalle inter-SCE (sec) ===
                    if num_sces > 1
                        SCE_intervals = diff(TRace) / sampling_rate; % en secondes
                        mean_SCE_interv = mean(SCE_intervals, 'omitnan');
                    else
                        mean_SCE_interv = NaN;
                    end

                    % Proportion de cellules actives par SCE
                    pourcentageActif = zeros(length(TRace), 1);
                    for i = 1:length(TRace)
                        nbActives = sum(RasterRace(:, TRace(i)) == 1);
                        pourcentageActif(i) = 100 * nbActives / NCell;
                    end
                    prop_active_cell_SCEs = mean(pourcentageActif);

                    % Durée moyenne des SCEs
                    distances = sces_distances(:, 2);
                    frame_duration_ms = 1000 / sampling_rate;
                    durations_ms = distances * frame_duration_ms;
                    avg_duration_ms = mean(durations_ms, 'omitnan');

                    % Fraction d’événements en bursts (P_burst)
                    pop_counts = sum(Raster,1);
                    smoothSigma = 3; 
                    win = ceil(6*smoothSigma);
                    g = exp(-((-win:win).^2)/(2*smoothSigma^2));
                    g = g/sum(g);
                    smooth_pop = conv(pop_counts,g,'same');
                    zThresh = 3;
                    thr = mean(smooth_pop) + zThresh*std(smooth_pop);
                    inBurstFrames = smooth_pop > thr;
                    totalEvents = sum(Raster(:));
                    eventsInBursts = sum(Raster(:,inBurstFrames),'all');
                    if totalEvents>0
                        P_burst = eventsInBursts/totalEvents;
                    else
                        P_burst = NaN;
                    end

                    % === Stockage ===
                    data_by_age.NCells(x_indices(pathIdx), groupIdx)       = NCell;
                    data_by_age.ActivityFreq(x_indices(pathIdx), groupIdx) = activity_frequency_minutes;
                    data_by_age.PairwiseCorr(x_indices(pathIdx), groupIdx) = mean_pairwise_corr;
                    data_by_age.NumSCEs(x_indices(pathIdx), groupIdx)      = num_sces;
                    data_by_age.SCE_Interv(x_indices(pathIdx), groupIdx)   = mean_SCE_interv;
                    data_by_age.SCEDuration(x_indices(pathIdx), groupIdx)  = avg_duration_ms;
                    data_by_age.propSCEs(x_indices(pathIdx), groupIdx)     = prop_active_cell_SCEs;
                    data_by_age.Pburst(x_indices(pathIdx), groupIdx)       = P_burst;

                catch ME
                    fprintf('Error in group %s, path %d: %s\n', current_animal_group, pathIdx, ME.message);
                end
            end
        end

        % === Plotting ===
        measures = {'NCells', 'ActivityFreq', 'PairwiseCorr', ...
                    'NumSCEs', 'SCE_Interv', 'SCEDuration', 'propSCEs', 'Pburst'};
        measure_titles = {'NCells', 'Activity Frequency (per minute)', ...
                          'Mean Pairwise Correlation (Fisher z normalized)', ...
                          'Number of SCEs', 'Inter-SCE Interval (s)', ...
                          'SCE Duration (ms)', ...
                          'Percentage of Active Cells in SCEs (averaged)', ...
                          'Fraction of events in bursts (P_burst)'};
        
        num_measures = numel(measures);
        num_rows = ceil(num_measures / 2);
        num_columns = 2;
        
        figure('Name', sprintf('Animal Type: %s', current_type), ...
               'Position', [100, 100, 1200, 800]);
        legend_handles = gobjects(num_groups, 1);
        
        for measureIdx = 1:num_measures
            subplot(num_rows, num_columns, measureIdx); hold on;
            measure_name = measures{measureIdx};
            data = data_by_age.(measure_name);
            valid_indices = ~all(isnan(data), 2);
            x_valid = find(valid_indices);
            data_valid = data(valid_indices, :);

            means = nanmean(data_valid, 2);
            stds = nanstd(data_valid, [], 2);

            b = bar(x_valid, means);
            errorbar(x_valid, means, stds, 'k.', 'LineWidth', 1);

            for animalIdx = 1:num_groups
                y = data_valid(:, animalIdx);
                scatter(x_valid, y, 50, colors(animalIdx, :), 'filled', 'MarkerEdgeColor', 'k');

                if measureIdx == 1
                    legend_handles(animalIdx) = scatter(nan, nan, 50, colors(animalIdx, :), 'filled', 'MarkerEdgeColor', 'k');
                end
            end

            title(measure_titles{measureIdx});
            xticks(1:numel(age_labels));
            xticklabels(age_labels);
            xlabel('Age');
            ylabel(measure_titles{measureIdx});

            ymax = max(means + stds, [], 'omitnan');
            if isempty(ymax) || isnan(ymax) || ymax == 0
                ymax = 1;
            end
            ylim([0, ymax * 1.2]);
        end

        legend(legend_handles, animal_group, 'Location', 'bestoutside');
        
        figs.(current_type) = gcf;
        grouped_data_by_age.(current_type) = data_by_age;
    end
end
