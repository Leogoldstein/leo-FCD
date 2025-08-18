function build_rasterplots(all_DF, all_isort1, all_MAct, current_animal_group, current_dates_group, current_age_group)
    % build_rasterplot generates and saves a figure for a single animal group with raster plots
    %
    % Inputs:
    % - all_DF, all_isort1, all_MAct: Cell arrays containing the data needed for plotting
    % - current_ani_path_group: Path for saving the raster plot figure
    % - current_animal_group: Name or identifier of the current animal group
    % - current_dates_group: Indices for the dates to process within this animal group
    % - current_age_group: Cell array with the age information for each date
    
    % Nested function to calculate scaling based on the 5th and 99.9th percentiles
    function [min_val, max_val] = calculate_scaling(data)
        flattened_data = data(:);
        min_val = prctile(flattened_data, 5);   % 5th percentile
        max_val = prctile(flattened_data, 99.9); % 99.9th percentile
    end

    % Create the figure and set it to fullscreen
    figure;
    set(gcf, 'Position', get(0, 'ScreenSize'));

    % Initialize variables for global scaling
    [minValue, maxValue] = deal(Inf, -Inf);
    % global_ymax = 0;

    % First loop to calculate global scaling across all data
    for k = 1:length(current_dates_group)  % Iterate over the dates for the current group
        % Convert current date string to its index in the data
        date_str = current_dates_group{k};
        idx = find(strcmp(date_str, current_dates_group));  % Find the index of the current date
        
        if isempty(idx)
            warning('Date %s not found in current_dates_group. Skipping...', date_str);
            continue;
        end

        DF = all_DF{idx};
        MAct = all_MAct{idx};
        isort1 = all_isort1{idx};
        [minVal, maxVal] = calculate_scaling(DF);  % Scaling for current dataset
        minValue = min(minValue, minVal);
        maxValue = max(maxValue, maxVal);
        
        % Check if DF is empty or improperly formed
        [NCell, num_columns] = size(DF);
        if NCell == 0 || num_columns == 0
            warning('Dataset %d is empty or malformed. Skipping...', k);
            continue;
        end

        % Calculate the proportion of active cells
        prop_MAct = MAct / NCell;

        % global_ymax = max(global_ymax, max(prop_MAct));  % Update with the maximum across all datasets
        % global_ymax = ceil(global_ymax * 10) / 10;   % Round up global_ymax to the nearest 0.1

        % Adjust isort1 to ensure valid indices
        isort1 = isort1(isort1 > 0 & isort1 <= NCell);  % Ensure indices are valid
        if isempty(isort1)
            warning('isort1 is empty for dataset %d. Skipping...', k);
            continue;
        end

        % Raster plot
        subplot(length(current_dates_group), 2, 2*(k - 1) + 1);  % Each dataset occupies two adjacent subplots
        imagesc(DF(isort1, :));

        % Adjust color limits
        clim([minValue, maxValue]);

        % Set x-axis ticks every 1000 frames
        tick_step = 1000;
        tick_positions = 0:tick_step:num_columns;
        tick_labels = (0:length(tick_positions)-1);

        % Configure the x-axis for the raster plot
        ax1 = gca;
        ax1.XAxisLocation = 'bottom';
        ax1.XTick = tick_positions;
        ax1.XTickLabel = tick_labels;
        xlabel('Frames (x 10^4)');

        % Axis labels
        ylabel('Neurons');

        % Title above each raster plot indicating the "age" part
        if length(current_age_group) >= k
            age_part = current_age_group{k};  % Use the age information directly
        else
            age_part = 'Unknown';  % Fallback if no age information
        end
        title(age_part, 'FontSize', 10, 'FontWeight', 'normal');

        % Activity plot in the adjacent subplot
        subplot(length(current_dates_group), 2, 2*(k - 1) + 2);
        plot(prop_MAct, 'LineWidth', 2);
        xlabel('Frames (x 10^4)');
        ylabel('Proportion of Active Cells');
        grid on;

        % Configure the x-axis ticks with the same scaling as for the raster plot
        ax2 = gca;
        ax2.XTick = tick_positions;
        ax2.XTickLabel = tick_labels;

        % Set y-axis limits to the global ymax
        %ylim([0 global_ymax]);

        % Set custom ticks for the y-axis (up to global_ymax)
        %yticks(0:0.1:global_ymax);

        % Link x-axes of raster and activity plots
        linkaxes([ax1, ax2], 'x');
        xlim([0 num_columns]);
    end

    % Add a single colorbar on the right side of the figure
    h = colorbar('Position', [0.92 0.2 0.02 0.6]);  % Positioning on the right
    ylabel(h, 'Activity Intensity', 'FontSize', 12);

    % Set the main title with the current unique group
    sgtitle(current_animal_group, 'FontSize', 14, 'FontWeight', 'bold');

    % Save the figure as a PNG in the designated save path
    exportgraphics(gcf, fig_save_path, 'Resolution', 300);
    disp(['Saved new figure: ' fig_save_path]);

    % Close the figure to free up memory
    close(gcf);
end
