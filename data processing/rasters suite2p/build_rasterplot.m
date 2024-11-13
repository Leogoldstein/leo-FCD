function build_rasterplot(all_DF, all_isort1, all_MAct, animal_date_list, fig_save_paths)
    % build_rasterplot generates and saves raster plots and activity plots.
    %
    % Inputs:
    % - all_DF, all_isort1, all_MAct: Cell arrays containing the data needed for plotting
    % - animal_date_list: Cell array containing the animal and date parts for naming figures
    % - save_paths: Cell array of output directories for saving figures
    % - fig_save_paths: Cell array of figure save paths to avoid re-generating in this function

    % Nested function to calculate scaling based on the 5th and 99.9th percentiles
    function [min_val, max_val] = calculate_scaling(data)
        flattened_data = data(:);
        min_val = prctile(flattened_data, 5);   % 5th percentile
        max_val = prctile(flattened_data, 99.9); % 99.9th percentile
    end

    % Iterate over each entry in animal_date_list and process the data
    for k = 1:size(animal_date_list, 1)
        try
            % Extract data from the input cell arrays
            DF = all_DF{k};
            isort1 = all_isort1{k};
            MAct = all_MAct{k};
            fig_save_path = fig_save_paths{k};

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

            % Create a new figure for each entry
            figure;
            set(gcf, 'Position', [100, 100, 1200, 800]);  % Set figure size

            % First subplot for the raster plot
            subplot(2, 1, 1);  % 2 rows, 1 column, 1st subplot
            imagesc(DF(isort1, :));  % Use the filtered isort1 for sorting valid neurons

            % Calculate scaling and set color limits
            [minValue, maxValue] = calculate_scaling(DF);  % Scaling for current data
            clim([minValue, maxValue]);  % Apply calculated limits
            colorbar;

            % Set colormap
            colormap('hot');

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
