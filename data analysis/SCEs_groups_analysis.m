function SCEs_groups_analysis(selected_groups, current_group_paths, all_DF_groups, all_Race_groups, all_TRace_groups, sampling_rate, all_Raster_groups, all_sces_distances_groups)

    num_animals = length(selected_groups);
    animal_group = cell(num_animals, 1);
    colors = lines(num_animals); % Generate distinct colors

    % Initialize the figure
    figure('Position', [100, 100, 1200, 800]);
    age_labels = {'P7', 'P8', 'P9', 'P10', 'P11', 'P12', 'P13', 'P14', 'P15'};
    age_values = 7:15;
    legend_entries = cell(num_animals, 1);

    % Iterate over each unique animal-group combination
    for groupIdx = 1:num_animals
        current_animal_group = selected_groups(groupIdx).animal_group;
        animal_group{groupIdx} = current_animal_group;
        current_dates_group = selected_groups(groupIdx).dates;
        current_folders_group = selected_groups(groupIdx).folders;
        current_ani_path_group = selected_groups(groupIdx).path;
        current_ages_group = selected_groups(groupIdx).ages;
        
        % Check the type of current_ages_group
        current_ages = cellfun(@(x) str2double(x(2:end)), current_ages_group); % Remove 'P' and convert to number

        all_DF = all_DF_groups{groupIdx};
        all_TRace = all_TRace_groups{groupIdx};
        all_Race = all_Race_groups{groupIdx};
        all_Raster = all_Raster_groups{groupIdx};
        all_sces_distances = all_sces_distances_groups{groupIdx};
        current_paths = current_group_paths{groupIdx};

        % Reset lists for each animal to prevent overlap
        animal_ncell_list = [];
        animal_num_sces_list = [];
        animal_sce_frequencies = [];
        animal_ratio_list = [];
        animal_sce_duration_list = [];
        
        % Iterate over directories for the current animal
        for pathIdx = 1:length(current_dates_group)
            try
                % Check if current indices are within valid bounds
                if pathIdx <= numel(all_DF)
                    DF = all_DF{pathIdx}; % Ensure DF is numeric
                else
                    error('Index exceeds the number of DF elements.');
                end
                
                [NCell, Nz] = size(DF);
                animal_ncell_list = [animal_ncell_list; NCell];
                
                % Number of SCEs
                if pathIdx <= numel(all_TRace)
                    TRace = all_TRace{pathIdx}; % Ensure TRace is numeric
                else
                    error('Index exceeds the number of TRace elements.');
                end
                TRace = TRace(:);  % Flatten the trace
                num_sces = numel(TRace);
                animal_num_sces_list = [animal_num_sces_list; num_sces];

                % SCE frequency
                nb_seconds = Nz / sampling_rate;
                sce_frequency_seconds = num_sces / nb_seconds;
                sce_frequency_minutes = sce_frequency_seconds * 60;
                animal_sce_frequencies = [animal_sce_frequencies; sce_frequency_minutes];

                % Proportion of active cells in SCEs

                % Average number of active cells in SCEs
                if pathIdx <= numel(all_Race)
                    Race = all_Race{pathIdx}; % Ensure Race is numeric
                else
                    error('Index exceeds the number of Race elements.');
                end
                if ~isempty(Race) && size(Race, 2) >= num_sces
                    avg_active_cell_SCEs = mean(sum(Race, 1)); % Average across SCEs
                end
  
                if pathIdx <= numel(all_Raster)
                    Raster = all_Raster{pathIdx}; % Ensure Raster is numeric
                else
                    error('Index exceeds the number of Raster elements.');
                end
                if isempty(Raster), error('Raster data is empty.'); end
                num_columns = size(Raster, 2);
                inds = 1:num_columns;
                indices_not_SCEs = setdiff(inds, TRace);

                if ~isempty(indices_not_SCEs)
                    avg_active_cells_not_in_SCEs = mean(sum(Raster(:, indices_not_SCEs), 1));
                    ratio = avg_active_cell_SCEs / avg_active_cells_not_in_SCEs;
                else
                    ratio = NaN;
                end
                percentage_ratio = ratio * 100;
                animal_ratio_list = [animal_ratio_list; percentage_ratio];
                
                %SCEs duration
                if pathIdx <= numel(all_sces_distances)
                    sces_distances = all_sces_distances{pathIdx}; % Ensure Raster is numeric
                else
                    sces_distances = NaN;
                end
                distances = sces_distances(:, 2);
                if ~isempty(distances)
                    % Convertir les distances (en frames) en durées (en ms)
                    frame_duration_ms = 1000 / sampling_rate; % Durée d'une frame en ms
                    durations_ms = distances * frame_duration_ms; % Conversion
                else
                    durations_ms = NaN; % Si distances est vide, renvoyer NaN
                end

                avg_duration_ms = mean(durations_ms, 'omitnan'); % Moyenne en ignorant les NaN
                animal_sce_duration_list = [animal_sce_duration_list; avg_duration_ms];


            catch ME
                fprintf('Error in directory %s: %s\n', current_paths{pathIdx}, ME.message);
                % Append NaN for each list if an error occurs
                animal_ncell_list = [animal_ncell_list; NaN];
                animal_num_sces_list = [animal_num_sces_list; NaN];
                animal_sce_frequencies = [animal_sce_frequencies; NaN];
                animal_ratio_list = [animal_ratio_list; NaN];
                animal_sce_duration_list = [animal_sce_duration_list; NaN];
            end
        end

        % Map the current ages to x positions
        [~, x_indices] = ismember(current_ages, age_values);

        % Plot the data for the current animal
        subplot(4, 2, 1); hold on;
        plot_segments(x_indices, animal_ncell_list, colors(groupIdx, :));
        legend_entries{groupIdx} = current_animal_group;

        subplot(4, 2, 2); hold on;
        plot_segments(x_indices, animal_num_sces_list, colors(groupIdx, :));

        subplot(4, 2, 3); hold on;
        plot_segments(x_indices, animal_sce_frequencies, colors(groupIdx, :));

        subplot(4, 2, 4); hold on;
        plot_segments(x_indices, animal_ratio_list, colors(groupIdx, :));

        subplot(4, 2, 5); hold on;
        plot_segments(x_indices, animal_sce_duration_list, colors(groupIdx, :));
        
    end

    % Adjust the x-axis limits and ticks for all subplots
    for i = 1:5
        subplot(4, 2, i);
        
        % Set x-axis limits and ticks
        xlim([1, numel(age_labels)]);
        xticks(1:numel(age_labels));
        xticklabels(age_labels);
        xlabel('Age');
    
        % Get current data for y-axis adjustment
        data = get(gca, 'Children');
        yData = arrayfun(@(h) get(h, 'YData'), data, 'UniformOutput', false);
        yData = cell2mat(yData');
        
        % Calculate min and max with a margin
        if ~isempty(yData)
            yMin = min(yData);
            yMax = max(yData);
            yRange = yMax - yMin;
            yMargin = yRange * 0.1;  % 10% margin
    
            % Adjust the y-axis limits
            ylim([yMin - yMargin, yMax + yMargin]);
        end
    end

    % Add legends and titles
    subplot(4, 2, 1); legend(legend_entries); title('NCells by age');
    subplot(4, 2, 2); legend(legend_entries); title('Number of SCEs by age');
    subplot(4, 2, 3); legend(legend_entries); title('SCE frequencies by age');
    subplot(4, 2, 4); legend(legend_entries); title('Proportion of active cell by age (%)');
    subplot(4, 2, 5); legend(legend_entries); title('Mean SCEs duration by age (ms)');

    % Set the overall figure title
    first_animal_group = animal_group{1};
    last_animal_group = animal_group{end};
    fig_name = sprintf('SCEs measures by age from %s to %s', first_animal_group, last_animal_group);
    sgtitle(fig_name); % Set the title of the figure

    % Save the figure
    PathSave = fullfile('D:', 'after_processing', 'Global SCEs analysis');
    save_path = fullfile(PathSave, [fig_name, '.png']);
    saveas(gcf, save_path);
    close(gcf);
end

function plot_segments(x, y, color)
    % Helper function to plot data with gaps for missing values
    % Check where there are gaps in the data
    gaps = find(diff(x) > 1); 
    segment_starts = [1; gaps + 1];
    segment_ends = [gaps; length(x)];
    
    % Plot each continuous segment separately
    for i = 1:length(segment_starts)
        range = segment_starts(i):segment_ends(i);
        plot(x(range), y(range), 'o-', 'Color', color);
    end
    
    % Set x-axis limits with a margin
    x_min = min(x);
    x_max = max(x);
    margin = 0.5; % Adjust this value to change the margin size
    xlim([x_min - margin, x_max + margin]);
end
