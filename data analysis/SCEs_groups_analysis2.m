function SCEs_groups_analysis2(selected_groups, all_DF_groups, all_Race_groups, all_TRace_groups, all_sampling_rate_groups, all_Raster_groups, all_sces_distances_groups)

    num_animals = length(selected_groups);
    animal_group = cell(num_animals, 1);
    colors = lines(num_animals); % Generate distinct colors

    % Data containers for aggregation
    age_labels = {'P7', 'P8', 'P9', 'P10', 'P11', 'P12', 'P13', 'P14', 'P15'};
    age_values = 7:15;  % Numeric age representation

    % Data structure to store aggregated measures
    data_by_age = struct('NCells', nan(numel(age_labels), num_animals), ...
                         'NumSCEs', nan(numel(age_labels), num_animals), ...
                         'SCEFreq', nan(numel(age_labels), num_animals), ...
                         'AvgActiveSCE', nan(numel(age_labels), num_animals), ...
                         'SCEDuration', nan(numel(age_labels), num_animals), ...
                         'propSCEs', nan(numel(age_labels), num_animals));
    
    % Iterate over each unique animal-group combination
    for groupIdx = 1:num_animals
        current_animal_group = selected_groups(groupIdx).animal_group;
        animal_group{groupIdx} = current_animal_group;
        current_dates_group = selected_groups(groupIdx).dates;
        current_ages_group = selected_groups(groupIdx).ages;
        
        % Extract ages and map them to age indices
        current_ages = cellfun(@(x) str2double(x(2:end)), current_ages_group); % Remove 'P' and convert to number
        [~, x_indices] = ismember(current_ages, age_values);

        all_DF = all_DF_groups{groupIdx};
        all_TRace = all_TRace_groups{groupIdx};
        all_Race = all_Race_groups{groupIdx};
        all_Raster = all_Raster_groups{groupIdx};
        all_sces_distances = all_sces_distances_groups{groupIdx};
        all_sampling_rate = all_sampling_rate_groups{groupIdx};

        % Iterate over directories for the current animal
        for pathIdx = 1:length(current_dates_group)
            try
                if pathIdx <= numel(all_DF)
                    DF = all_DF{pathIdx};
                    [NCell, Nz] = size(DF);
                else
                    error('Index exceeds the number of DF elements.');
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

                if pathIdx <= numel(all_Raster)
                    Raster = all_Raster{pathIdx};
                    num_columns = size(Raster, 2);
                    inds = 1:num_columns;
                    indices_not_SCEs = setdiff(inds, TRace);
                    avg_active_cells_not_in_SCEs = mean(sum(Raster(:, indices_not_SCEs), 1));
                    prop_active_cell_SCEs = avg_active_cell_SCEs / (avg_active_cell_SCEs + avg_active_cells_not_in_SCEs) *100;
                end

                if pathIdx <= numel(all_sces_distances)
                    sces_distances = all_sces_distances{pathIdx};
                    distances = sces_distances(:, 2);
                    frame_duration_ms = 1000 / sampling_rate;
                    durations_ms = distances * frame_duration_ms;
                    avg_duration_ms = mean(durations_ms, 'omitnan');
                end

                % Aggregate data
                data_by_age.NCells(x_indices(pathIdx), groupIdx) = NCell;
                data_by_age.NumSCEs(x_indices(pathIdx), groupIdx) = num_sces;
                data_by_age.SCEFreq(x_indices(pathIdx), groupIdx) = sce_frequency_minutes;
                data_by_age.AvgActiveSCE(x_indices(pathIdx), groupIdx) = avg_active_cell_SCEs;
                data_by_age.SCEDuration(x_indices(pathIdx), groupIdx) = avg_duration_ms;
                data_by_age.propSCEs(x_indices(pathIdx), groupIdx) = prop_active_cell_SCEs;

            catch ME
                fprintf('Error in group %s, path %d: %s\n', current_animal_group, pathIdx, ME.message);
            end
        end
    end

    % Create a single barplot for each measure with individual points and error bars
    measures = {'NCells', 'NumSCEs', 'SCEFreq', 'AvgActiveSCE', 'SCEDuration', 'propSCEs'};
    measure_titles = {'NCells', 'Number of SCEs', 'SCE Frequency', 'Avg Active Cells in SCEs', ...
                      'SCE Duration (ms)', 'Percentage of Active Cells in SCEs'};
    num_measures = numel(measures);

    figure('Position', [100, 100, 1200, 800]);

    legend_handles = gobjects(num_animals, 1); % Placeholder for legend handles

    for measureIdx = 1:num_measures
        subplot(3, 2, measureIdx); hold on;

        measure_name = measures{measureIdx};
        data = data_by_age.(measure_name);
        
        % Ensure no mismatch between ages and data
        valid_indices = ~all(isnan(data), 2); % Keep ages with valid data
        x_valid = find(valid_indices);
        data_valid = data(valid_indices, :);

        means = nanmean(data_valid, 2);  % Mean across groups
        stds = nanstd(data_valid, [], 2); % Standard deviation across groups

        % Plot bars with error bars
        b = bar(x_valid, means);
        errorbar(x_valid, means, stds, 'k.', 'LineWidth', 1);

        % Plot individual data points
        for animalIdx = 1:num_animals
            y = data_valid(:, animalIdx);
            scatter(x_valid, y, 50, colors(animalIdx, :), 'filled', 'MarkerEdgeColor', 'k');

            % Store handle for legend (one per animal)
            if measureIdx == 1
                legend_handles(animalIdx) = scatter(nan, nan, 50, colors(animalIdx, :), 'filled', 'MarkerEdgeColor', 'k');
            end
        end

        % Customize subplot
        title(measure_titles{measureIdx});
        xticks(1:numel(age_labels));
        xticklabels(age_labels);
        xlabel('Age');
        ylabel(measure_titles{measureIdx});
        ylim([0, max(means + stds, [], 'omitnan') * 1.2]);
    end

    % Add a legend for the animal groups using scatter points
    legend(legend_handles, animal_group, 'Location', 'bestoutside');

    % Set the overall figure title and save
    sgtitle('SCEs Measures by Age with Individual Data Points');
    save_path = fullfile('D:', 'after_processing', 'Global SCEs analysis', 'SCEs_measures_with_individual_points.png');
    saveas(gcf, save_path);
    close(gcf);
end