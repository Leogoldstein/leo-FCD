function process_data(all_DF, all_ops, all_isort1, all_MAct, animal_date_list)
    % process_data generates and saves figures for raster plots or mean images based on user input
    % Inputs:
    % - all_DF, all_isort1, all_MAct: Cell arrays containing the data needed for plotting
    % - animal_date_list: Cell array containing the animal and date parts for naming figures
    
    % Extract parts from the animal_date_list
    type_part = animal_date_list(:, 1);
    animal_part = animal_date_list(:, 3);
    mTor_part = animal_date_list(:, 2);
    date_part = animal_date_list(:, 4);
    age_part = animal_date_list(:, 5); % Corrected indexing
    
    % Create unique combinations of animal and group based on type_part
    if strcmp(type_part{1}, 'jm')
        % If type_part is "jm", we do not include mTor_part in the iteration
        unique_animal_group = unique(animal_part);
    else
        % Otherwise, we create unique groups with mTor_part
        animal_group = strcat(animal_part, ' (', mTor_part, ')');
        unique_animal_group = unique(animal_group);
    end

    % Initialize save paths
    save_paths = {};
    fig_save_paths = {};

    % Prompt user for their choice
    choice = input('Analysis options: by animal (1) or by date (2)? ');

    % Ask the user for the type of analysis they want to perform
    analysis_choice = input('Choose analysis type: raster plot (1) or mean images (2)? ');

    % Set the save path based on analysis type
    if analysis_choice == 1
        PathSave = 'D:/after_processing/Rasterplots/';
    elseif analysis_choice == 2
        PathSave = 'D:/after_processing/mean images/';
    else
        error('Invalid analysis choice. Please enter 1 or 2.');
    end

    % Save by animal
    if choice == 1
        for k = 1:length(unique_animal_group)
            current_animal = unique_animal_group{k};
            
            % Create save path depending on type_part and mTor_part
            if strcmp(type_part{1}, 'jm')
                % If type_part is "jm", do not include mTor_part
                save_path = fullfile(PathSave, type_part{1}, current_animal); 
            else
                % Otherwise, include mTor_part in the path
                save_path = fullfile(PathSave, type_part{1}, mTor_part{k}, current_animal); 
            end
            
            if ~exist(save_path, 'dir')
                mkdir(save_path);
                disp(['Created folder: ' save_path]);
            end
            
            save_paths{end+1} = save_path;
        end
    
        if analysis_choice == 1
            for k = 1:length(unique_animal_group)
                current_animal = unique_animal_group{k};
                fig_save_path = fullfile(save_paths{k}, sprintf('%s_rastermap.png', strrep(current_animal, ' ', '_')));
                
                if ~exist(fig_save_path, 'file')
                    fig_save_paths{end+1} = fig_save_path;
                else
                    disp(['Raster plot already exists: ' fig_save_path]);
                end
            end
            
            if ~isempty(fig_save_paths)
                build_rasterplots(all_DF, all_isort1, all_MAct, animal_date_list, fig_save_paths, animal_part, unique_animal_group);
            end
        end

    % Save by date
    elseif choice == 2
        for k = 1:size(animal_date_list, 1)
            % If mTor_part exists, include it in the save path
            if ~isempty(mTor_part{k})
                save_path = fullfile(PathSave, type_part{k}, mTor_part{k}, animal_part{k}, date_part{k});
            else
                save_path = fullfile(PathSave, type_part{k}, animal_part{k}, date_part{k});
            end

            if ~exist(save_path, 'dir')
                mkdir(save_path);
                disp(['Created folder: ' save_path]);
            end

            save_paths{end+1} = save_path;
        end
                
        if analysis_choice == 1
            for k = 1:length(save_paths)
                fig_save_path = fullfile(save_paths{k}, sprintf('raster_plots_%s_%s_%s.png', mTor_part{k}, animal_part{k}, age_part{k}));  
                
                if ~exist(fig_save_path, 'file')
                    fig_save_paths{end+1} = fig_save_path;
                else
                    disp(['Raster plot already exists: ' fig_save_path]);
                end
            end
            
            if ~isempty(fig_save_paths)
                build_rasterplot(all_DF, all_isort1, all_MAct, animal_date_list, fig_save_paths);
            end

        elseif analysis_choice == 2
            for k = 1:length(save_paths)
                fig_save_path = fullfile(save_paths{k}, sprintf('mean_image_%s_%s_%s.png', mTor_part{k}, animal_part{k}, age_part{k}));
                
                if ~exist(fig_save_path, 'file')
                    fig_save_paths{end+1} = fig_save_path;
                else
                    disp(['Mean image already exists: ' fig_save_path]);
                end    
            end
            
            if ~isempty(fig_save_paths)
                save_mean_images(animal_date_list, all_ops, fig_save_paths);
            end 
        else    
            error('Invalid choice. Please enter 1 or 2.');
        end
    else
        error('Invalid choice. Please enter 1 or 2.');
    end
end
