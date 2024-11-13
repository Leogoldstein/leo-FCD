function build_rasterplots(all_DF, all_isort1, all_MAct, animal_date_list, fig_save_paths, animal_group, unique_animal_group)
    % build_rasterplot generates and saves separate figures for each unique animal group with raster plots
    %
    % Inputs:
    % - all_DF, all_isort1, all_MAct: Cell arrays containing the data needed for plotting
    % - save_paths: Cell array of output directories for saving figures
    % - animal_date_list: Cell array containing the animal and date parts for naming figures

    % Nested function to calculate scaling based on the 5th and 99.9th percentiles
    function [min_val, max_val] = calculate_scaling(data)
        flattened_data = data(:);
        min_val = prctile(flattened_data, 5);   % 5th percentile
        max_val = prctile(flattened_data, 99.9); % 99.9th percentile
    end

    % Iterate over each unique animal group to create a subplot
    for group_idx = 1:length(unique_animal_group)
        % Determine the current unique group
        current_group = unique_animal_group{group_idx};

        fig_save_path = fig_save_paths{group_idx};
        
        % Find the indices corresponding to the current unique group
        indices = find(strcmp(animal_group, current_group));

        % Create a new figure for the current unique animal group
        figure;
        set(gcf, 'Position', get(0, 'ScreenSize'));  % Set figure to fullscreen

        % Initialize variables for global scaling
        [minValue, maxValue] = deal(Inf, -Inf);
        global_ymax = 0;

        % First loop to calculate global scaling across all data and find global_ymax for activity plots
        for k = indices'  % Use the indices for current group
            DF = all_DF{k};
            MAct = all_MAct{k};
            [minVal, maxVal] = calculate_scaling(DF);  % Scaling for current dataset
            minValue = min(minValue, minVal);
            maxValue = max(maxValue, maxVal);

            % Calculate proportion of active cells and update global_ymax
            prop_MAct = MAct / size(DF, 1);
            global_ymax = max(global_ymax, max(prop_MAct));  % Update with the maximum across all datasets
        end

        % Round up global_ymax to the nearest 0.1
        global_ymax = ceil(global_ymax * 10) / 10;  % E.g., 0.6927 becomes 0.7

        % Plotting loop for the current group
        for k = indices'  % Use the indices for current group
            try
                % Extract data from the input cell arrays
                DF = all_DF{k};
                isort1 = all_isort1{k};
                MAct = all_MAct{k};

                % Filter out neurons with NaN values from DF
                valid_neurons = all(~isnan(DF), 2);  % Check for NaN values in each row (neuron)
                DF = DF(valid_neurons, :);           % Keep only rows without NaN values

                % Adjust isort1 to ensure it's valid after filtering
                valid_neuron_indices = find(valid_neurons);  % Get the valid indices
                isort1 = isort1(ismember(isort1, valid_neuron_indices));  % Filter out invalid indices
                [~, isort1] = ismember(isort1, valid_neuron_indices);  % Adjust the indices

                % Proportion of active cells
                [NCell, num_columns] = size(DF);
                prop_MAct = MAct / NCell;

                % Define subplot grid for the current dataset
                subplot(length(indices), 2, 2*(k - indices(1)) + 1);  % Each dataset occupies two adjacent subplots

                % Raster plot
                imagesc(DF(isort1, :));  % Use the filtered isort1 for sorting valid neurons

                % Set color limits for all plots to the global min and max
                clim([minValue, maxValue]);

                % Define x-axis tick positions for every 1000 frames
                tick_step = 1000;
                tick_positions = 0:tick_step:num_columns;
                tick_labels = (0:length(tick_positions)-1);  % Display 0, 1, 2, ...

                % Set x-axis ticks for raster plot
                ax1 = gca;
                ax1.XAxisLocation = 'bottom';
                ax1.XTick = tick_positions;
                ax1.XTickLabel = tick_labels;
                xlabel('Frames (x 10^4)');

                % Label axes
                ylabel('Neurons');

                % Title above each raster plot for the specific age part
                age_part = animal_date_list{k, 5};
                title(age_part, 'FontSize', 10, 'FontWeight', 'normal');

                % Activity plot in the adjacent subplot
                subplot(length(indices), 2, 2*(k - indices(1)) + 2);  % The next subplot for the activity plot
                plot(prop_MAct, 'LineWidth', 2);
                xlabel('Frames (x 10^4)');
                ylabel('Proportion of Active Cells');
                grid on;

                % Set x-axis ticks with the same scaling as the raster plot
                ax2 = gca;
                ax2.XTick = tick_positions;
                ax2.XTickLabel = tick_labels;

                % Set y-axis limit to the rounded global maximum for consistent scaling
                ylim([0 global_ymax]);

                % Define custom y-ticks to display only up to the rounded global_ymax
                yticks(0:0.1:global_ymax);

                % Link the x-axes of the raster and activity subplots
                linkaxes([ax1, ax2], 'x');
                xlim([0 num_columns]);

            catch ME
                % Print the error message
                fprintf('\nError: %s\n', ME.message);
            end
        end
        
        % Add a single colorbar on the right side of the figure
        h = colorbar('Position', [0.92 0.2 0.02 0.6]);  % Positioning on the right
        ylabel(h, 'Activity Intensity', 'FontSize', 12);

        % Set the main title with the current unique group
        sgtitle(current_group, 'FontSize', 14, 'FontWeight', 'bold');

         % Check if the file already exists to avoid overwriting
        if ~isfile(fig_save_path)
            % Save the figure as a PNG in the designated save path
            exportgraphics(gcf, fig_save_path, 'Resolution', 300);
            disp(['Saved new figure: ' fig_save_path]);
        else
            disp(['Figure already exists and was skipped: ' fig_save_path]);
        end

        % Close the figure to free up memory
        close(gcf);
    end
end