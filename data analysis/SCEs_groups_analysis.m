function SCEs_groups_analysis(selected_groups, all_DF_groups, all_Race_groups, all_TRace_groups, all_sampling_rate_groups, all_Raster_groups)
    % Initialize lists to store results
    animal_ncell_list = [];
    animal_num_sces_list = [];
    animal_sce_frequencies = [];
    avg_active_cell_list = [];
    ratio_list = [];
    
    num_animals = length(selected_groups);
    animal_group = cell(num_animals,1);
    colors = lines(num_animals); % Generate distinct colors

    % Initialize the figure
    figure('Position', [100, 100, 1200, 800]);
    age_labels = {'P7', 'P8', 'P9', 'P10', 'P11', 'P12', 'P13', 'P14', 'P15'};
    age_values = 7:15;
    legend_entries = cell(num_animals, 1);

    % Iterate over each unique animal-group combination
    for groupIdx = 1:length(selected_groups)
        current_animal_group = selected_groups(groupIdx).animal_group;
        animal_group{groupIdx} = current_animal_group;
        current_dates_group = selected_groups(groupIdx).dates;
        current_folders_group = selected_groups(groupIdx).folders;
        current_ani_path_group = selected_groups(groupIdx).path;
        current_ages_group = selected_groups(groupIdx).ages;

        current_ages = cellfun(@(x) str2double(x(2:end)), current_ages_group); % Remove 'P' and convert to number

        % Reset lists for each animal to prevent overlap
        animal_ncell_list = [];
        animal_num_sces_list = [];
        animal_sce_frequencies = [];
        animal_avg_active_cell_list = [];
        animal_ratio_list = [];

        % Iterate over directories for the current animal
        for pathIdx = 1:length(current_ages_group)
            try
                % number of cells
                DF = all_DF_groups{groupIdx}{pathIdx};
                [NCell, Nz] = size(DF);
                animal_ncell_list = [animal_ncell_list; NCell];
                
                % number of SCEs
                TRace = all_TRace_groups{groupIdx}{pathIdx};
                TRace = TRace(:);
                num_sces = numel(TRace);
                animal_num_sces_list = [animal_num_sces_list; num_sces];

                % SCE frequency
                sampling_rate = all_sampling_rate_groups{groupIdx}{pathIdx};
                nb_seconds = Nz / sampling_rate;
                sce_frequency_seconds = num_sces / nb_seconds;
                sce_frequency_minutes = sce_frequency_seconds * 60;
                animal_sce_frequencies = [animal_sce_frequencies; sce_frequency_minutes];

                % Average number of active cells in SCEs
                Race = all_Race_groups{groupIdx}{pathIdx};
                if size(Race, 2) >= num_sces  % Ensure correct indexing
                    avg_active_cell_SCEs = mean(sum(Race, 1));
                    animal_avg_active_cell_list = [animal_avg_active_cell_list; avg_active_cell_SCEs];
                else
                    animal_avg_active_cell_list = [animal_avg_active_cell_list; NaN];
                end

                % Ratio of active cells in SCEs/outside SCEs
                Raster = all_Raster_groups{groupIdx}{pathIdx};
                num_columns = size(Raster, 2); % Ensure Raster is defined
                inds = 1:num_columns;
                indices_not_SCEs = setdiff(inds, TRace);
        
                if ~isempty(indices_not_SCEs)  % Ensure there are valid indices to compare
                    avg_active_cells_not_in_SCEs = mean(sum(Raster(:, indices_not_SCEs), 1));
                    ratio = avg_active_cell_SCEs / avg_active_cells_not_in_SCEs;
                else
                    ratio = NaN;
                end
                animal_ratio_list = [animal_ratio_list; ratio];
               

            catch ME
                fprintf('Error in directory %s: %s\n', directories{k}, ME.message);
                 % Append NaN for each list if an error occurs
                animal_ncell_list = [animal_ncell_list; NaN];
                animal_num_sces_list = [animal_num_sces_list; NaN];
                animal_sce_frequencies = [animal_sce_frequencies; NaN];
                animal_avg_active_cell_list = [animal_avg_active_cell_list; NaN];
                animal_ratio_list = [animal_ratio_list; NaN];
        end

        % Map the current ages to x positions
        [~, x_indices] = ismember(current_ages, age_values);

        % Plot the data for the current animal
        subplot(4, 2, 1); hold on;
        plot_segments(x_indices, animal_ncell_list, colors(a, :));
        legend_entries{a} = animal_group;

        subplot(4, 2, 2); hold on;   
        plot_segments(x_indices, animal_num_sces_list, colors(a, :));
        legend_entries{a} = animal_group;

        subplot(4, 2, 3); hold on;
        plot_segments(x_indices, animal_sce_frequencies, colors(a, :));
        legend_entries{a} = animal_group;

        subplot(4, 2, 4); hold on;
        
        
        % subplot(4, 2, 8); hold on;
        % plot_segments(x_indices, , colors(a, :));
        % legend_entries{a} = animal_group;

        drawnow; % Force MATLAB to render immediately to catch potential issues

    end

    % Adjust the x-axis limits and ticks for all subplots
    for i = 1:7
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

    % Set the legend and titles for each subplot
    subplot(4, 2, 1);
    legend(legend_entries, 'Location', 'best');
    title('Number of Cells by Age');

    subplot(4, 2, 2);
    title('Number of SCEs by Age');

    subplot(4, 2, 3);
    title('SCE Frequency by Age');

    subplot(4, 2, 6);
    title('Entropy by Age');
    
    subplot(4, 2, 7);
    title('Proportion of active cells in SCEs (%)');
    
    % Define title for the figure
    first_animal_group = animal_group{1};
    last_animal_group = animal_group{end};
    fig_name = sprintf('SCEs measures by age from %s to %s', first_animal_group, last_animal_group);
    sgtitle(fig_name); % Set the title of the figure

    PathSave = fullfile('D:', 'after_processing', 'Global SCEs analysis');
    save_path = fullfile(PathSave, [fig_name, '.png']);
    saveas(gcf, save_path);
    close(gcf)
end


function plot_segments(x, y, color)
    % Helper function to plot data with gaps for missing values
    gaps = find(diff(x) > 1); 
    segment_starts = [1; gaps + 1];
    segment_ends = [gaps; length(x)];
    
    % Plot each continuous segment separately
    for i = 1:length(segment_starts)
        range = segment_starts(i):segment_ends(i);
        plot(x(range), y(range), 'o-', 'Color', color);
    end
end
