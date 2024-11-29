function build_rasterplots(all_DF, all_isort1, all_MAct, animal_date_list, raster_paths, unique_animal_group, inds_group)
    % build_rasterplot generates and saves separate figures for each unique animal group with raster plots
    %
    % Inputs:
    % - all_DF, all_isort1, all_MAct: Cell arrays containing the data needed for plotting
    % - animal_date_list: Cell array containing the animal and date parts for naming figures
    % - raster_paths: Paths for saving the raster plot figures
    % - unique_animal_group: List of unique animal groups
    % - inds_group: Indices for each group to process
    
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

        fig_save_path = fullfile(raster_paths{group_idx}, sprintf('%s_rastermap.png', strrep(current_group, ' ', '_')));

        if ~exist(fig_save_path, 'file')
    
            % Create a new figure for the current unique animal group
            figure;
            set(gcf, 'Position', get(0, 'ScreenSize'));  % Set figure to fullscreen
    
            % Initialize variables for global scaling
            [minValue, maxValue] = deal(Inf, -Inf);
            global_ymax = 0;
    
            % First loop to calculate global scaling across all data and find global_ymax for activity plots
            for k = 1:length(inds_group{group_idx})  % Iterate over the indices for the current group
        
                DF = all_DF{group_idx}{k};  % Data for the current index in this group
                MAct = all_MAct{group_idx}{k};
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
                for k = 1:length(inds_group{group_idx})  % Iterate over the indices for the current group
                    try
                        % Ensure valid index range
                        if k > length(all_DF{group_idx}) || k > length(all_MAct{group_idx}) || k > length(all_isort1{group_idx})
                            warning('Index k=%d exceeds the size of the provided cell arrays. Skipping...', k);
                            continue;
                        end

                        % Extract data from the input cell arrays for the current group and index
                        DF = all_DF{group_idx}{k};
                        isort1 = all_isort1{group_idx}{k};
                        MAct = all_MAct{group_idx}{k};
        
                        % Check if DF is empty or improperly formed
                        [NCell, num_columns] = size(DF);
                        if NCell == 0 || num_columns == 0
                            warning('Dataset %d is empty or malformed. Skipping...', k);
                            continue;
                        end
                        
                        % Calculate the proportion of active cells
                        prop_MAct = MAct / NCell;
                        
                        % Adjust isort1 to ensure valid indices
                        isort1 = isort1(isort1 > 0 & isort1 <= NCell);  % Ensure indices are valid
                        if isempty(isort1)
                            warning('isort1 is empty for dataset %d. Skipping...', k);
                            continue;
                        end
                        
                        % Raster plot
                        subplot(length(inds_group{group_idx}), 2, 2*(k - 1) + 1);  % Each dataset occupies two adjacent subplots
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
                        if size(animal_date_list, 2) >= 5
                            age_part = animal_date_list{k, 5};  % Assuming 5th column is for age part
                        else
                            age_part = 'Unknown';  % Fallback if not enough columns
                        end
                        title(age_part, 'FontSize', 10, 'FontWeight', 'normal');
                        
                        % Activity plot in the adjacent subplot
                        subplot(length(inds_group{group_idx}), 2, 2*(k - 1) + 2);
                        plot(prop_MAct, 'LineWidth', 2);
                        xlabel('Frames (x 10^4)');
                        ylabel('Proportion of Active Cells');
                        grid on;
                        
                        % Configure the x-axis ticks with the same scaling as for the raster plot
                        ax2 = gca;
                        ax2.XTick = tick_positions;
                        ax2.XTickLabel = tick_labels;
                        
                        % Set y-axis limits to the global ymax
                        ylim([0 global_ymax]);
                        
                        % Set custom ticks for the y-axis (up to global_ymax)
                        yticks(0:0.1:global_ymax);
                        
                        % Link x-axes of raster and activity plots
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
end
