function build_rasterplot(all_DF, all_isort1, all_MAct, date_group_paths, current_animal_group, current_ages_group)
    % build_rasterplot generates and saves raster plots and activity plots.
    %
    % Inputs:
    % - all_DF, all_isort1, all_MAct: Cell arrays containing the data needed for plotting
    % - date_group_paths: Cell array of output directories for saving figures
    % - current_animal_group: Names of the unique animal groups
    % - current_ages_group: Age information associated with each group

    % Nested function to calculate scaling based on the 5th and 99.9th percentiles
    function [min_val, max_val] = calculate_scaling(data)
        flattened_data = data(:);
        min_val = prctile(flattened_data, 5);   % 5th percentile
        max_val = prctile(flattened_data, 99.9); % 99.9th percentile
    
        % Ensure that min_val is less than max_val
        if min_val >= max_val
            warning('The calculated scaling limits are invalid. Adjusting to default values.');
            min_val = min(flattened_data);  % Fallback to min of data
            max_val = max(flattened_data);  % Fallback to max of data
        end
    end


    for m = 1:length(date_group_paths)
        try
            % Extract data from the input cell arrays
            DF = all_DF{m};
            isort1 = all_isort1{m};
            MAct = all_MAct{m};

            % Create the save path for the figure
            fig_save_path = fullfile(date_group_paths{m}, sprintf('%s_%s_rastermap.png', ...
                strrep(current_animal_group, ' ', '_'), strrep(current_ages_group{m}, ' ', '_')));

            % Check if the figure already exists
            if exist(fig_save_path, 'file')
                disp(['Figure already exists and was skipped: ' fig_save_path]);
                continue; % Skip this iteration
            end

            % Filter out neurons with NaN values from DF
            valid_neurons = all(~isnan(DF), 2);  % Check for NaN values in each row (neuron)
            DF = DF(valid_neurons, :);           % Keep only rows without NaN values

            % Adjust isort1 to ensure it's valid after filtering
            valid_neuron_indices = find(valid_neurons);  % Get the valid indices
            isort1 = isort1(ismember(isort1, valid_neuron_indices));  % Filter out invalid indices
            [~, isort1] = ismember(isort1, valid_neuron_indices);  % Adjust the indices

            % Proportion of active cells
            [NCell, ~] = size(DF);
            prop_MAct = MAct / NCell;

            % Create a new figure for the current unique animal group
            figure;
            screen_size = get(0, 'ScreenSize');  % Get screen size
            set(gcf, 'Position', screen_size);   % Set the figure size to the screen's resolution

            % First subplot for the raster plot
            subplot(2, 1, 1);  % 2 rows, 1 column, 1st subplot
            imagesc(DF(isort1, :));  % Use the filtered isort1 for sorting valid neurons

            % Calculate scaling and set color limits
            [minValue, maxValue] = calculate_scaling(DF);  % Scaling for current data
            clim([minValue, maxValue]);  % Apply calculated limits
            colorbar;

            % Set colormap
            % colormap('hot');

            % Tight axis
            axis tight;

            % Set x-axis ticks
            num_columns = size(DF, 2);
            tick_step = 1000;  % Tick separation of 1000 frames
            tick_positions = 0:tick_step:num_columns;
            tick_labels = sprintfc('%d', tick_positions);

            % Place ticks at the bottom of the x-axis
            ax1 = gca;
            ax1.XAxisLocation = 'bottom';
            ax1.XTick = tick_positions;
            ax1.XTickLabel = tick_labels;

            % Label axes
            ylabel('Neurons');
            xlabel('Number of frames');

            % Adjust position to make space for the second plot
            set(gca, 'Position', [0.1, 0.55, 0.85, 0.4]);  % [left, bottom, width, height]

            % Second subplot for the MAct plot
            subplot(2, 1, 2);  % 2 rows, 1 column, 2nd subplot
            plot(prop_MAct, 'LineWidth', 2);
            xlabel('Frame');
            ylabel('Proportion of Active Cells');
            title('Activity Over Consecutive Frames');
            grid on;

            % Adjust position of the second plot
            set(gca, 'Position', [0.1, 0.1, 0.85, 0.35]);  % [left, bottom, width, height]

            % Link the x-axes of the two subplots
            linkaxes([ax1, gca], 'x');

            % Set the x-axis limits to stop at the last frame
            xlim([0 num_columns]);

            % Save the figure
            saveas(gcf, fig_save_path);
            disp(['Raster plot saved in: ' fig_save_path]);

            % Close the figure to free up memory
            close(gcf);

        catch ME
            % Print the error message
            fprintf('\nError: %s\n', ME.message);
        end
    end
end
