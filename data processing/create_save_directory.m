function save_directory = create_save_directory(PathSave, animal_date_list, workingFolders, daytime)
    % Save results by creating directories if they don't exist
    
    for k = 1:length(workingFolders)
        % Extract the animal part from the list
        disp(animal_date_list)
        animal_part = animal_date_list{k, 1};

        % Create the directory path for saving analysis
        save_directory = fullfile(PathSave, animal_part, daytime);
        disp(save_directory)
        
        % Check if the directory exists, if not, create it
        if ~exist(save_directory, 'dir')
            mkdir(save_directory);  % Make the directory if it does not exist
            disp(['Created new folder: ' save_directory]);
        else
            disp(['Folder already exists: ' save_directory]);
        end
    end
end
