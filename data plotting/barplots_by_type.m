function [grouped_data_by_age, figs] = barplots_by_type(selected_groups)

    animal_types = {'jm', 'FCD', 'CTRL'};
    num_types = numel(animal_types);

    grouped_data_by_age = struct(); 
    figs = struct();  % Structure pour stocker les figures par type d'animal

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

        % Data containers for aggregation
        age_labels = {'P7', 'P8', 'P9', 'P10', 'P11', 'P12', 'P13', 'P14', 'P15'};
        age_values = 7:15;

        data_by_age = struct('NCells', nan(numel(age_labels), num_groups), ...
                             'NumSCEs', nan(numel(age_labels), num_groups), ...
                             'SCEFreq', nan(numel(age_labels), num_groups), ...
                             'AvgActiveSCE', nan(numel(age_labels), num_groups), ...
                             'SCEDuration', nan(numel(age_labels), num_groups), ...
                             'propSCEs', nan(numel(age_labels), num_groups), ...
                             'ActivityFreq', nan(numel(age_labels), num_groups));  % Ajout de ActivityFreq

        for groupIdx = 1:num_groups
            current_animal_group = groups_subset(groupIdx).animal_group;
            animal_group{groupIdx} = current_animal_group;
            current_dates_group = groups_subset(groupIdx).dates;
            current_ages_group = groups_subset(groupIdx).ages;

            current_ages = cellfun(@(x) str2double(x(2:end)), current_ages_group);
            [~, x_indices] = ismember(current_ages, age_values);

            all_DF = groups_subset(groupIdx).gcamp_data.DF;
            all_TRace = groups_subset(groupIdx).gcamp_data.TRace;
            all_Race = groups_subset(groupIdx).gcamp_data.Race;
            all_Raster = groups_subset(groupIdx).gcamp_data.Raster;
            all_RasterRace = groups_subset(groupIdx).gcamp_data.RasterRace;
            all_sces_distances = groups_subset(groupIdx).gcamp_data.sces_distances;
            all_sampling_rate = groups_subset(groupIdx).gcamp_data.sampling_rate;

            for pathIdx = 1:length(current_dates_group)
                try
                    if pathIdx <= numel(all_DF)
                        DF = all_DF{pathIdx};
                    else
                        error('Index exceeds the number of DF elements.');
                    end
                    
                    if pathIdx <= numel(all_sampling_rate)
                        sampling_rate = all_sampling_rate{pathIdx};
                    end

                    if pathIdx <= numel(all_Raster)
                        Raster = all_Raster{pathIdx};
                         
                        % Vérifier que DF et Raster ont le même nombre de neurones et ajuster si nécessaire
                        if size(DF, 1) ~= size(Raster, 1)
                            warning('Mismatch in the number of neurons between DF and Raster for group %d. Adjusting to the smallest size.', groupIdx);
                            min_cells = min(size(DF, 1), size(Raster, 1));
                            DF = DF(1:min_cells, :);
                            Raster = Raster(1:min_cells, :);
                        end

                        % Vérifier que DF et Raster ont le même nombre de frames et ajuster si nécessaire
                        if size(DF, 2) ~= size(Raster, 2)
                            warning('Mismatch in the number of frames between DF and Raster for group %d. Adjusting to the smallest size.', groupIdx);
                            min_frames = min(size(DF, 2), size(Raster, 2));
                            DF = DF(:, 1:min_frames);
                            Raster = Raster(:, 1:min_frames);
                        end
                        
                        % Fréquence d'activité par minute pour chaque neurone
                        [NCell, Nz] = size(Raster);
                        mean_activity = mean(Raster, 1);  % Moyenne de l'activité sur tous les neurones pour chaque frame
                        activity_frequency_minutes = mean(mean_activity) * sampling_rate * 60;  % Fréquence en activité par minute
                    else
                        error('Index exceeds the number of Raster elements.');
                    end

                    if pathIdx <= numel(all_TRace)
                        TRace = all_TRace{pathIdx};
                        num_sces = numel(TRace);
                    else
                        error('Index exceeds the number of TRace elements.');
                    end

                    if pathIdx <= numel(all_sampling_rate)
                        sampling_rate = all_sampling_rate{pathIdx};
                        nb_seconds = Nz / sampling_rate;
                        sce_frequency_seconds = num_sces / nb_seconds;
                        sce_frequency_minutes = sce_frequency_seconds * 60;
                    end

                    if pathIdx <= numel(all_Race)
                        Race = all_Race{pathIdx};
                        avg_active_cell_SCEs = mean(sum(Race, 1));
                    end

                    if pathIdx <= numel(all_RasterRace)
                        RasterRace = all_RasterRace{pathIdx};
                        NCell = size(RasterRace, 1);
                        
                        % Initialisation d’un vecteur pour stocker les pourcentages par SCE
                        pourcentageActif = zeros(length(TRace), 1);
                        
                        for i = 1:length(TRace)
                            % Nombre de cellules actives à l’instant TRace(i)
                            nbActives = sum(RasterRace(:, TRace(i)) == 1);
                            
                            % Pourcentage de cellules actives
                            pourcentageActif(i) = 100 * nbActives / NCell;
                        end

                        prop_active_cell_SCEs = mean(pourcentageActif);
                    end

                    if pathIdx <= numel(all_sces_distances)
                        sces_distances = all_sces_distances{pathIdx};
                        distances = sces_distances(:, 2);
                        frame_duration_ms = 1000 / sampling_rate;
                        durations_ms = distances * frame_duration_ms;
                        avg_duration_ms = mean(durations_ms, 'omitnan');
                    end

                    data_by_age.NCells(x_indices(pathIdx), groupIdx) = NCell;
                    data_by_age.NumSCEs(x_indices(pathIdx), groupIdx) = num_sces;
                    data_by_age.SCEFreq(x_indices(pathIdx), groupIdx) = sce_frequency_minutes;
                    data_by_age.AvgActiveSCE(x_indices(pathIdx), groupIdx) = avg_active_cell_SCEs;
                    data_by_age.SCEDuration(x_indices(pathIdx), groupIdx) = avg_duration_ms;
                    data_by_age.propSCEs(x_indices(pathIdx), groupIdx) = prop_active_cell_SCEs;
                    data_by_age.ActivityFreq(x_indices(pathIdx), groupIdx) = activity_frequency_minutes;  % Ajout de la fréquence d'activité

                catch ME
                    fprintf('Error in group %s, path %d: %s\n', current_animal_group, pathIdx, ME.message);
                end
            end
        end

        % Plotting
        measures = {'NCells', 'ActivityFreq', 'NumSCEs', 'SCEFreq', 'AvgActiveSCE', 'SCEDuration', 'propSCEs'};
        measure_titles = {'NCells', 'Activity Frequency (per minute)', 'Number of SCEs', 'SCE Frequency', ...
                          'Number of Active Cells in SCEs (averaged)', 'SCE Duration (ms)', 'Percentage of Active Cells in SCEs (averaged)'};
        
        num_measures = numel(measures);
        num_rows = ceil(num_measures / 2);  % Utilise autant de lignes que nécessaire
        num_columns = 2;  % Utilise 2 colonnes (vous pouvez ajuster cela également)
        
        % Créez les sous-graphes avec la taille de grille ajustée
        figure('Name', sprintf('Animal Type: %s', current_type), 'Position', [100, 100, 1200, 800]);
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
            ylim([0, max(means + stds, [], 'omitnan') * 1.2]);
        end

        legend(legend_handles, animal_group, 'Location', 'bestoutside');
        
        % Enregistrer la figure pour ce type d'animal
        figs.(current_type) = gcf;  % Stocke la figure sous le type d'animal
        %close(gcf)

        grouped_data_by_age.(current_type) = data_by_age;

    end
end
