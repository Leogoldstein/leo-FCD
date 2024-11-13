function compare_rasterplots(all_DF, all_isort1, all_prop_MAct, directories, animal_date_list)
    % compare_rasterplots generates and saves raster plots for comparison

    num_pairs = size(directories, 1);

    % Function to calculate the scaling between the 5th and 99.9th percentiles
    function [min_val, max_val] = calculate_scaling(data)
        flattened_data = data(:);
        min_val = prctile(flattened_data, 5);   % 5th percentile
        max_val = prctile(flattened_data, 99.9); % 99.9th percentile
    end

    % Process each pair
    for pair_idx = 1:num_pairs
        try
            % Display dimensions of the current pair
            disp(['Processing pair index: ', num2str(pair_idx)]);
            
            % Extract data for the current pair
            DF1 = all_DF{pair_idx,1}{1,1}; % Raster data for the first animal
            isort1_1 = all_isort1{pair_idx,1}{1,1};
            prop_MAct1 = all_prop_MAct{pair_idx,1}{1,1};

            DF2 = all_DF{pair_idx,1}{2,1}; % Raster data for the second animal
            isort1_2 = all_isort1{pair_idx,1}{2,1};
            prop_MAct2 = all_prop_MAct{pair_idx,1}{2,1};

            % Check if indices are valid
            if isempty(DF1) || isempty(DF2)
                error('DF1 or DF2 is empty for pair index %d.', pair_idx);
            end
            if isempty(isort1_1) || isempty(isort1_2)
                error('isort1_1 or isort1_2 is empty for pair index %d.', pair_idx);
            end
            if isempty(prop_MAct1) || isempty(prop_MAct2)
                error('prop_MAct1 or prop_MAct2 is empty for pair index %d.', pair_idx);
            end

            % Filter out neurons with NaN values
            valid_neurons_1 = all(~isnan(DF1), 2);  % Determine valid neurons
            valid_indices_1 = find(valid_neurons_1); % Get valid indices for DF1
            isort1_1_filtered = isort1_1(ismember(isort1_1, valid_indices_1)); % Filter isort1_1
            
            valid_neurons_2 = all(~isnan(DF2), 2);  % Determine valid neurons
            valid_indices_2 = find(valid_neurons_2); % Get valid indices for DF2
            isort1_2_filtered = isort1_2(ismember(isort1_2, valid_indices_2)); % Filter isort1_2

            % Filter the data based on valid neurons
            DF1_filtered = DF1(valid_neurons_1, :);
            DF2_filtered = DF2(valid_neurons_2, :);

            % Determine the maximum number of frames for x-axis limits
            numFrames1_filtered = size(DF1_filtered, 2);
            numFrames2_filtered = size(DF2_filtered, 2);
            minFrames = min(numFrames1_filtered, numFrames2_filtered);

            % Create a new figure for the comparison
            figure;
            set(gcf, 'Position', [100, 100, 1800, 800]);  % [left, bottom, width, height]

            % Extract information for titles
            animal_part1 = animal_date_list{pair_idx,1}{1,1}{1,1};
            date_part1 = animal_date_list{pair_idx,1}{1,1}{1,2};
            animal_part2 = animal_date_list{pair_idx,1}{2,1}{1,1};
            date_part2 = animal_date_list{pair_idx,1}{2,1}{1,2};

            % Display extracted data information
            disp(['Animal 1: ', animal_part1, ' Date 1: ', date_part1]);
            disp(['Animal 2: ', animal_part2, ' Date 2: ', date_part2]);

            % Calculate scaling limits for the raster plots
            [minValue1, maxValue1] = calculate_scaling(DF1_filtered);
            [minValue2, maxValue2] = calculate_scaling(DF2_filtered);
            minValue = min([minValue1, minValue2]); % Common min value
            maxValue = max([maxValue1, maxValue2]); % Common max value
            climValue = [minValue, maxValue]; % Common color limit between 5th and 99.9th percentiles

            % First subplot for the first raster plot
            subplot('Position', [0.05, 0.55, 0.4, 0.35]);  % Custom position to allocate more space
            imagesc(DF1(isort1_1_filtered, :));  % Use the filtered isort1 and DF1
            clim(climValue);
            colormap('hot');
            colorbar('Position', [0.46, 0.55, 0.02, 0.35]);  % Place colorbar next to the plot
            axis tight;
            ylabel('Neurons');
            xlabel('Number of frames');
            title(sprintf('Raster Plot %s (%s)', animal_part1, date_part1));
            xlim([1 minFrames]);  % Set x-axis limit based on the maximum number of frames

            % Second subplot for the second raster plot
            subplot('Position', [0.55, 0.55, 0.4, 0.35]);  % Custom position for alignment
            imagesc(DF2(isort1_2_filtered, :));  % Use the filtered isort1 and DF2
            clim(climValue);
            colormap('hot');
            colorbar('Position', [0.96, 0.55, 0.02, 0.35]);  % Place colorbar next to the plot
            axis tight;
            ylabel('Neurons');
            xlabel('Number of frames');
            title(sprintf('Raster Plot %s (%s)', animal_part2, date_part2));
            xlim([1 minFrames]);  % Set x-axis limit based on the maximum number of frames

            % Third subplot for the first MAct plot
            subplot('Position', [0.05, 0.1, 0.4, 0.35]);  % Align with first raster plot
            plot(prop_MAct1, 'LineWidth', 2);
            xlabel('Frame');
            ylabel('Proportion of Active Cells');
            title(sprintf('Activity Plot (%s %s)', animal_part1, date_part1));
            xlim([1 minFrames]);  % Set x-axis limit based on the maximum number of frames
            grid on;

            % Fourth subplot for the second MAct plot
            subplot('Position', [0.55, 0.1, 0.4, 0.35]);  % Align with second raster plot
            plot(prop_MAct2, 'LineWidth', 2);
            xlabel('Frame');
            ylabel('Proportion of Active Cells');
            title(sprintf('Activity Plot (%s %s)', animal_part2, date_part2));
            xlim([1 minFrames]);  % Set x-axis limit based on the maximum number of frames
            grid on;

	    % Ensure a common Y-axis for both activity plots
            commonYLim = [min([min(prop_MAct1), min(prop_MAct2)]), max([max(prop_MAct1), max(prop_MAct2)])];
            subplot(3); ylim(commonYLim);  % Apply common ylim to the first MAct plot
            subplot(4); ylim(commonYLim);  % Apply common ylim to the second MAct plot

            % Generate the figure name using animal_part and date_part
            fig_name = sprintf('Raster Comparison (match sizes) (%s %s vs %s %s)', animal_part1, date_part1, animal_part2, date_part2);

            % Save the figure
            save_path1 = fullfile(directories{pair_idx,1}{2,1}, [fig_name, '.png']);
            
            % Define the directory path and file name
            directory = 'C:\Users\goldstein\Desktop\temporary_files'; 
            save_path2 = fullfile(directory, [fig_name, '.png']);

            saveas(gcf, save_path1);
            saveas(gcf, save_path2);
            close(gcf);

        catch ME
            % Print the error message
            fprintf('\nError processing pair %d: %s\n', pair_idx, ME.message);
        end
    end
end
