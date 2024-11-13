function save_mean_images(animal_date_list, all_ops, fig_save_paths)
    % save_mean_images generates and saves mean images based on input data.
    %
    % Inputs:
    % - animal_date_list: Cell array containing information on animals and dates
    % - all_ops: Data used for generating mean images (Python dictionaries or MATLAB structures)
    % - save_paths: Cell array of output directories for saving figures

    % Import the necessary Python module if not already done
    py.importlib.import_module('numpy');

    % Loop through each file path in directories
    for k = 1:size(animal_date_list, 1)
        try
            % Extract animal and date information from animal_date_list
            animal_part = animal_date_list{k, 3};
            date_part = animal_date_list{k, 4};
            fig_save_path = fig_save_paths{k};

            % Check if all_ops{k} is a Python dictionary
            if isa(all_ops{k}, 'py.dict')
                ops = all_ops{k};  % Python dictionary
                meanImg = double(ops{'meanImg'});  % Convert to MATLAB array
            else
                ops = all_ops{k};  % MATLAB structure
                meanImg = ops.meanImg;
            end

            % Check if the file already exists to avoid overwriting
            if ~isfile(fig_save_path)
                % Display the mean image
                figure('Units', 'pixels', 'Position', [100, 100, 1200, 900]);  % Set figure size
                imagesc(meanImg);  % Display the mean image
                colormap('gray');
                title(['Mean Image for ' animal_part ' on ' date_part]);

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
            fprintf('\nError: %s\n', ME.message);
        end
    end
end
