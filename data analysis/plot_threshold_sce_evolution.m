function all_num_sces = plot_threshold_sce_evolution(current_ani_path_group, current_animal_group, date_group_paths, current_ages_group, all_sce_n_cells_threshold, all_TRace)
    % Function to plot thresholds for SCEs based on pre-computed data
    %
    % Inputs:
    % - current_ani_path_group: Paths to save figures
    % - date_group_paths: Dataset paths
    % - current_animal_group: Cell array of animal names
    % - current_ages_group: Cell array of animal ages (e.g., 'P7', 'P8', ...)
    % - all_sce_n_cells_threshold: Precomputed thresholds for SCE detection
    % - all_TRace: Precomputed TRace (detected SCE peaks)

    % Data containers for aggregation
    age_labels = {'P7', 'P8', 'P9', 'P10', 'P11', 'P12', 'P13', 'P14', 'P15'}; % Age categories
    age_values = 7:15;  % Numeric age representation

    % Extract ages and map them to age indices
    current_ages = cellfun(@(x) str2double(x(2:end)), current_ages_group); % Remove 'P' and convert to numbers
    [~, x_indices] = ismember(current_ages, age_values); % Find corresponding indices in age_values

    % Ensure x_indices is numeric
    x_indices = double(x_indices);

    % Check if all_sce_n_cells_threshold is a cell array and convert it
    if iscell(all_sce_n_cells_threshold)
        % Check if the cells have consistent dimensions
        cell_sizes = cellfun(@(x) size(x), all_sce_n_cells_threshold, 'UniformOutput', false);
        unique_sizes = unique(cell2mat(cell_sizes), 'rows');  % Get unique sizes

        % If there are multiple sizes, display an error
        if size(unique_sizes, 1) > 1
            error('Elements in all_sce_n_cells_threshold have inconsistent dimensions.');
        end

        % If dimensions are consistent, convert the cell array to a numeric array
        all_sce_n_cells_threshold = cell2mat(all_sce_n_cells_threshold);
    end

    % Ensure all_sce_n_cells_threshold is now a numeric array
    all_sce_n_cells_threshold = double(all_sce_n_cells_threshold);

    % Remove NaN or invalid values from x_indices and all_sce_n_cells_threshold
    valid_indices = ~isnan(x_indices) & ~isnan(all_sce_n_cells_threshold); % Exclude NaNs
    x_indices_valid = x_indices(valid_indices);
    all_sce_n_cells_threshold_valid = all_sce_n_cells_threshold(valid_indices);

    % Initialize container for number of SCEs
    all_num_sces = zeros(size(date_group_paths));

    % Loop through each dataset to compute the number of SCEs
    for k = 1:length(date_group_paths)
        % Extract TRace data for the current dataset
        TRace = all_TRace{k};
        % Calculate the number of SCEs for the current dataset
        all_num_sces(k) = length(TRace);
    end

    % Plot the results
    figure;
    hold on;

    % Plot thresholds on the left y-axis
    yyaxis left;
    plot(x_indices_valid, all_sce_n_cells_threshold_valid, 'b-o', 'LineWidth', 2);
    ylabel('Threshold for SCE Detection');
    xlabel('Animal Age (Postnatal Days)');
    title(sprintf('SCE Detection Thresholds and Counts for %s', current_animal_group));
    xlim([min(x_indices_valid) - 0.5, max(x_indices_valid) + 0.5]);
    ylim([0 max(all_sce_n_cells_threshold_valid) * 1.1]); % Adjust y-axis limit to fit thresholds
    xticks(1:length(age_labels));
    xticklabels(age_labels);
    grid on;

    % Create a second y-axis for the number of SCEs
    yyaxis right;
    plot(x_indices_valid, all_num_sces(valid_indices), 'r-o', 'LineWidth', 2);
    ylabel('Number of SCEs');
    ylim([0 max(all_num_sces(valid_indices)) * 1.1]); % Adjust y-axis limit to fit number of SCEs

    % Add legend
    legend('Detection Thresholds', 'Number of SCEs', 'Location', 'best');
    hold off;

    % Save the figure
    fig_name = sprintf('SCE Detection as a function of Animal Age (%s)', current_animal_group);
    save_path = fullfile(current_ani_path_group, [fig_name, '.png']);
    saveas(gcf, save_path);
    close(gcf);
end
