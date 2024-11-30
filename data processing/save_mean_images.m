function save_mean_images(current_animal_group, current_date_group, ops, mean_group_path)
    % save_mean_image generates and saves a single mean image based on input data.
    %
    % Inputs:
    % - current_animal_group: Name of the current animal (string)
    % - current_date_group: Date associated with the current data (string)
    % - ops: Data structure or Python dictionary containing mean image data
    % - mean_group_path: Directory to save the mean image

    % Import the necessary Python module if not already done
    py.importlib.import_module('numpy');

    try
        % Check if ops is a Python dictionary or MATLAB structure
        if isa(ops, 'py.dict')
            meanImg = double(ops{'meanImg'});  % Convert to MATLAB array
        else
            meanImg = ops.meanImg;  % MATLAB structure
        end

        % Generate the file name for the mean image
        fig_save_path = fullfile(mean_group_path, ...
            sprintf('MeanImage_%s_%s.png', current_animal_group, current_date_group));

        % Check if the file already exists to avoid overwriting
        if ~isfile(fig_save_path)
            % Create the figure and display the mean image
            figure('Units', 'pixels', 'Position', [100, 100, 1200, 900]);  % Set figure size
            imagesc(meanImg);  % Display the mean image
            colormap('gray');
            title(['Mean Image for ' current_animal_group ' on ' current_date_group]);

            % Save the mean image as a .png file
            saveas(gcf, fig_save_path);
            disp(['Mean image saved in: ' fig_save_path]);

            % Close the figure after saving
            close(gcf);
        else
            % Notify that the file already exists and skip saving
            disp(['File already exists, skipping save: ' fig_save_path]);
        end

    catch ME
        % Print the error message in case of failure
        fprintf('\nError processing mean image for %s on %s: %s\n', ...
            current_animal_group, current_date_group, ME.message);
    end
end
