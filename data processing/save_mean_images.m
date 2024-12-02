function save_mean_images(current_animal_group, all_ops, current_dates_group, date_group_paths)
    % save_mean_images generates and saves mean images based on input data.
    %
    % Inputs:
    % - current_animal_group: Cell array containing information on animals and dates
    % - all_ops: Data used for generating mean images (Python dictionaries or MATLAB structures)
    % - date_group_paths: Cell array of output directories for saving figures

    % Import the necessary Python module if not already done
    py.importlib.import_module('numpy');

    % Loop through each file path in directories
    for m = 1:length(date_group_paths)
        try
            % Check if all_ops{k} is a Python dictionary
            if isa(all_ops{m}, 'py.dict')
                ops = all_ops{m};  % Python dictionary
                meanImg = double(ops{'meanImg'});  % Convert to MATLAB array
            else
                ops = all_ops{m};  % MATLAB structure
                meanImg = ops.meanImg;
            end

            % Check if the file already exists to avoid overwriting
            if ~isfile(date_group_paths{m})
                % Display the mean image
                figure('Units', 'pixels', 'Position', [100, 100, 1200, 900]);  % Set figure size
                imagesc(meanImg);  % Display the mean image
                colormap('gray');
                title(['Mean Image for ' current_animal_group ' on ' current_dates_group{m}]);

                % Save the mean image as a .png file
                saveas(gcf, date_group_paths{m});
                disp(['Mean image saved in: ' date_group_paths{m}]);

                % Close the figure after saving
                close(gcf);
            else
                % Notify that the file already exists and skip saving
                disp(['File already exists, skipping save: ' date_group_paths{m}]);
            end

        catch ME
            % Print the error message in case of failure
            fprintf('\nError: %s\n', ME.message);
        end
    end
end
