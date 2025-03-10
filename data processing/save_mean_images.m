function save_mean_images(current_animal_group, all_ops, current_dates_group, tseries_results_path)
    % save_mean_images generates and saves mean images based on input data.

    % Import necessary Python module if using Python dictionaries
    py.importlib.import_module('numpy');

    % Loop through each file path in directories
    for m = 1:length(tseries_results_path)
        try
            % Ensure all_ops{m} is correctly handled
            if isa(all_ops{m}, 'py.dict')
                ops = all_ops{m};  % Python dictionary
                meanImg = double(ops{'meanImg'});  % Convert to MATLAB array
            elseif isstruct(all_ops{m})
                ops = all_ops{m};  % MATLAB structure
                meanImg = ops.meanImg;
            else
                % Enhanced error message including tseries_results_path
                error('Unexpected data type for all_ops{%d} at path: %s\n Data type: %s', ...
                      m, tseries_results_path{m}, class(all_ops{m}));
            end

            % Ensure the directory exists
            if ~isfolder(tseries_results_path{m})
                mkdir(tseries_results_path{m}); % Create directory if it doesn’t exist
            end

            % Ensure the file path is correctly formed
            png_filename = fullfile(tseries_results_path{m}, 'Mean_image.png');
            disp(['Saving image to: ' png_filename]);

            % Check if the file already exists to avoid overwriting
            % if ~isfile(png_filename)
            %     % Display and save the mean image
            %     figure('Units', 'pixels', 'Position', [100, 100, 1200, 900]); 
            %     imagesc(meanImg);  
            %     colormap('gray');
            %     title(['Mean Image for ' current_animal_group ' on ' current_dates_group{m}]);
            % 
            %     % Save the mean image
            %     saveas(gcf, png_filename);
            %     disp(['Mean image saved in: ' png_filename]);
            % 
            %     % Close the figure after saving
            %     close(gcf);
            % else
            %     disp(['File already exists, skipping save: ' png_filename]);
            % end

            % Display and save the mean image
            figure('Units', 'pixels', 'Position', [100, 100, 1200, 900]); 
            imagesc(meanImg);  
            colormap('gray');
            title(['Mean Image for ' current_animal_group ' on ' current_dates_group{m}]);

            % Save the mean image
            saveas(gcf, png_filename);
            disp(['Mean image saved in: ' png_filename]);

            % Close the figure after saving
            close(gcf);

        catch ME
            % Print error message
            fprintf('Error in processing %d: %s\n', m, ME.message);
        end
    end
end
