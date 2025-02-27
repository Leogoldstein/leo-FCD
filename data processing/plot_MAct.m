function plot_MAct(all_MAct, date_group_paths, current_animal_group, current_ages_group)
    % build_activity_plot_only generates and saves the activity plot.
    %
    % Inputs:
    % - all_MAct: Cell array containing the activity data needed for plotting
    % - date_group_paths: Cell array of output directories for saving figures
    % - current_animal_group: Names of the unique animal groups
    % - current_ages_group: Age information associated with each group

    for m = 1:length(date_group_paths)
        try
            % Extract data from the input cell arrays
            MAct = all_MAct{m};

            % Create the save path for the figure
            fig_save_path = fullfile(date_group_paths{m}, sprintf('%s_%s_activity_plot.png', ...
                strrep(current_animal_group, ' ', '_'), strrep(current_ages_group{m}, ' ', '_')));

            % Check if the figure already exists
            if exist(fig_save_path, 'file')
                disp(['Figure already exists and was skipped: ' fig_save_path]);
                continue; % Skip this iteration
            end

            % Proportion of active cells (just normalize or calculate the ratio)
            [NCell, ~] = size(MAct);
            prop_MAct = MAct / NCell;

            % Create a new figure for the current unique animal group
            figure;
            screen_size = get(0, 'ScreenSize');  % Get screen size
            set(gcf, 'Position', screen_size);   % Set the figure size to the screen's resolution

            % Plot the activity plot (proportion of active cells)
            plot(prop_MAct, 'LineWidth', 2);
            xlabel('Frame');
            ylabel('Proportion of Active Cells');
            title('Activity Over Consecutive Frames');
            grid on;

            % Set the x-axis limits to stop at the last frame
            num_columns = length(prop_MAct);
            xlim([0 num_columns]);

            % Save the figure
            saveas(gcf, fig_save_path);
            disp(['Activity plot saved in: ' fig_save_path]);

            % Close the figure to free up memory
            close(gcf);

        catch ME
            % Print the error message
            fprintf('\nError: %s\n', ME.message);
        end
    end
end
