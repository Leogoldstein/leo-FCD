function meanImgs = save_mean_images(current_animal_group, current_dates_group, current_ages_group, gcamp_output_folders, current_gcamp_folders_group)
    % save_mean_images generates and saves mean images based on input data.
    % Also returns a cell array of mean images.
    
    numFolders = length(current_gcamp_folders_group);
    meanImgs = cell(1, numFolders);  % Initialize output cell array
    
    for m = 1:numFolders
        png_filename = fullfile(gcamp_output_folders{m}, ...
            sprintf('Mean_image_of_%s_%s.png', ...
            strrep(current_animal_group, ' ', '_'), ...
            strrep(current_ages_group{m}, ' ', '_')));
    
        disp(['Saving image to: ' png_filename]);
        
        % Check if the file already exists to avoid overwriting
        try
            % Get the current folder path
            current_folder = current_gcamp_folders_group{m};

            % Determine file extension and check for .npy files
            [~, ~, ext] = fileparts(current_folder);
            files = dir(fullfile(current_folder, '*.npy'));

            if ~isempty(files)
                % Unpack .npy file paths
                newOpsPath = fullfile(current_folder, 'ops.npy');
                
                % Call the Python function to load stats and ops
                try
                    mod = py.importlib.import_module('python_function');
                    ops = mod.read_npy_file(newOpsPath);
                    meanImg = double(ops{'meanImg'});  % Convert to MATLAB array
                catch ME
                    error('Failed to call Python function: %s', ME.message);
                end

            elseif strcmp(ext, '.mat')
                % Load .mat files
                data = load(current_folder);
                ops = data.ops;
                meanImg = ops.meanImg;
            else
                error('Unsupported file type: %s', ext);
            end
 
            % Save the image to the output cell array
            meanImgs{m} = meanImg;

        catch ME
            % Handle any errors related to the current folder and continue the loop
            disp(ME.message);
            continue; 
        end

       
        if ~isfile(png_filename)
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
        else
            disp(['File already exists, skipping save: ' png_filename]);
        end
    end
end
