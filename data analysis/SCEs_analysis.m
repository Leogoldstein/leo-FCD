function SCEs_analysis(directories, all_DF, all_data, all_Race, all_Raster, sampling_rate, animal_date_list)
    % Initialize lists to store results
    animal_ncell_list = [];
    animal_num_sces_list = [];
    animal_sce_frequencies = [];
    animal_avg_isis_list = [];
    animal_skewness_list = [];
    elbow_points_list = [];
    animal_entropy_list = [];  % List to store entropy values
    animal_mean_pairwise_correlation_list = [];  % List to store mean pairwise correlations

    % Extract parts from the animal_date_list
    type_part = animal_date_list(:, 1);
    animal_part = animal_date_list(:, 3);
    mTor_part = animal_date_list(:, 2);

    % Create unique combinations of animal and group based on type_part
    if strcmp(type_part{1}, 'jm')
        unique_animal_group = unique(animal_part);
    else
        animal_group = strcat(animal_part, ' (', mTor_part, ')');
        unique_animal_group = unique(animal_group);
    end

    unique_combined = unique(unique_animal_group); % Get unique combinations
    num_animals = length(unique_combined);
    colors = lines(num_animals); % Generate distinct colors

    % Initialize the figure
    figure('Position', [100, 100, 1200, 800]);
    age_labels = {'P7', 'P8', 'P9', 'P10', 'P11', 'P12', 'P13', 'P14', 'P15'};
    age_values = 7:15;
    legend_entries = cell(num_animals, 1);

    % Iterate over each unique animal-group combination
    for a = 1:num_animals
        animal_group = unique_combined{a};
        disp(['Processing: ', animal_group]) % Debug: display animal group being processed

        % Extract animal name and group
        parts = regexp(animal_group, ' \(', 'split');
        animal = parts{1};

        if ~strcmp(type_part{1}, 'jm')
            group = strrep(parts{2}, ')', '');
            animal_indices = strcmp(animal_date_list(:, 3), animal) & strcmp(animal_date_list(:, 2), group);
        else
            animal_indices = strcmp(animal_date_list(:, 3), animal);
        end

        % Determine the dates (ages) for the current animal
        ages_for_animal = find(animal_indices);
        current_age_labels = animal_date_list(ages_for_animal, 5); % Extract age labels
        current_ages = cellfun(@(x) str2double(x(2:end)), current_age_labels); % Remove 'P' and convert to number

        % Reset lists for each animal to prevent overlap
        animal_ncell_list = [];
        animal_num_sces_list = [];
        animal_sce_frequencies = [];
        animal_skewness_list = [];
        elbow_points_list = [];
        animal_entropy_list = [];  % Reset entropy list
        animal_mean_pairwise_correlation_list = [];  % Reset mean pairwise correlation list

        % Iterate over directories for the current animal
        for k = ages_for_animal'
            try
                % number of cells
                DF = all_DF{k};
                [NCell, Nz] = size(DF);
                animal_ncell_list = [animal_ncell_list; NCell];
                
                % number of frequency
                TRace = all_data.TRace{k};
                TRace = TRace(:);
                num_sces = numel(TRace);
                animal_num_sces_list = [animal_num_sces_list; num_sces];

                % SCE frequency
                nb_seconds = Nz / sampling_rate;
                sce_frequency_seconds = num_sces / nb_seconds;
                sce_frequency_minutes = sce_frequency_seconds * 60;
                animal_sce_frequencies = [animal_sce_frequencies; sce_frequency_minutes];

                % Skewness
                Raster = all_Raster{k};
                yall = skewness(Raster, 1, 'all');
                animal_skewness_list = [animal_skewness_list; yall];

                % Elbow points
                [~, ~, eigenvalues] = pca(Raster);
                cumulative_variance = cumsum(eigenvalues) / sum(eigenvalues);
                num_components_70 = find(cumulative_variance >= 0.7, 1);  % Find the first component where cumulative variance is >= 70%
                elbow_points_list = [elbow_points_list; num_components_70];

                % Entropy calculation on columns (frames)
                entropy_value = calculate_entropy(Raster);
                animal_entropy_list = [animal_entropy_list; entropy_value];

                % Compute the mean of the pairwise correlation
                corr_matrix = corrcoef(Raster'); 
                triu_mask = triu(true(size(corr_matrix)), 1);
                pairwise_correlations = corr_matrix(triu_mask);
                mean_pairwise_correlation = mean(pairwise_correlations);
                animal_mean_pairwise_correlation_list = [animal_mean_pairwise_correlation_list; mean_pairwise_correlation];

            catch ME
                fprintf('Error in directory %s: %s\n', directories{k}, ME.message);
                animal_ncell_list = [animal_ncell_list; NaN];
                animal_num_sces_list = [animal_num_sces_list; NaN];
                animal_sce_frequencies = [animal_sce_frequencies; NaN];
                animal_skewness_list = [animal_skewness_list; NaN];
                elbow_points_list = [elbow_points_list; NaN];
                animal_entropy_list = [animal_entropy_list; NaN];  % Ensure consistency in case of error
                animal_mean_pairwise_correlation_list = [animal_mean_pairwise_correlation_list; NaN];  % Handle errors for pairwise correlation
            end
        end

        % Map the current ages to x positions
        [~, x_indices] = ismember(current_ages, age_values);

        % Plot the data for the current animal
        subplot(4, 2, 1); hold on;
        plot_segments(x_indices, animal_ncell_list, colors(a, :));
        legend_entries{a} = animal_group;

        subplot(4, 2, 2); hold on;
        plot_segments(x_indices, animal_skewness_list, colors(a, :));
        legend_entries{a} = animal_group;

        subplot(4, 2, 3); hold on;
        plot_segments(x_indices, elbow_points_list, colors(a, :));
        legend_entries{a} = animal_group;

        subplot(4, 2, 4); hold on;
        plot_segments(x_indices, animal_num_sces_list, colors(a, :));
        legend_entries{a} = animal_group;

        subplot(4, 2, 5); hold on;
        plot_segments(x_indices, animal_sce_frequencies, colors(a, :));
        legend_entries{a} = animal_group;

        subplot(4, 2, 6); hold on;
        plot_segments(x_indices, animal_entropy_list, colors(a, :));
        legend_entries{a} = animal_group;

        subplot(4, 2, 7); hold on;
        plot_segments(x_indices, animal_mean_pairwise_correlation_list, colors(a, :));
        legend_entries{a} = animal_group;
        
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
    title('Skewness of Activity by Age');

    subplot(4, 2, 3);
    title('Number of PCs explaining at least 70% of the variance');

    subplot(4, 2, 4);
    title('Number of SCEs by Age');

    subplot(4, 2, 5);
    title('SCE Frequency by Age');

    subplot(4, 2, 6);
    title('Entropy by Age');
    
    subplot(4, 2, 7);
    title('Mean Pairwise Correlation by Age');
    
    % Define title for the figure
    first_animal_group = unique_combined{1};
    last_animal_group = unique_combined{end};
    fig_name = sprintf('SCEs measures by age from %s to %s', first_animal_group, last_animal_group);
    sgtitle(fig_name); % Set the title of the figure

    PathSave = fullfile('D:', 'after_processing', 'Presentations');
    save_path = fullfile(PathSave, [fig_name, '.png']);
    saveas(gcf, save_path);
    close(gcf)
end

function entropy = calculate_entropy(raster_data)
    [num_cells, num_frames] = size(raster_data);  % num_cells: rows (neurons), num_frames: columns (time)
    entropy = zeros(num_frames, 1);  % Initialize entropy array to store results

    for i = 1:num_frames
        % Calculate the probability of activity (1) in the frame (column)
        p_1 = sum(raster_data(:, i) == 1) / num_cells;  % Probability of activity (1)
        p_0 = 1 - p_1;  % Probability of inactivity (0)
        
        % Initialize entropy for the current frame
        frame_entropy = 0;
        
        % If p_1 > 0, calculate contribution of p_1 to entropy
        if p_1 > 0
            frame_entropy = frame_entropy - p_1 * log2(p_1);
        end
        
        % If p_0 > 0, calculate contribution of p_0 to entropy
        if p_0 > 0
            frame_entropy = frame_entropy - p_0 * log2(p_0);
        end
        
        % Store the calculated entropy for the current frame
        entropy(i) = frame_entropy;
    end
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
