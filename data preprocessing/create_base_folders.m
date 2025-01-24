function [date_group_paths, tseries_folders, tseries_results_paths, chosen_folder_processing] = create_base_folders(base_path, current_dates_group, current_env_group, daytime, user_choice1, user_choice2, current_animal_group)
    % Function to create base folders for each date and process subfolders
    
    % Initialize output variables
    date_group_paths = cell(length(current_dates_group), 1);  % Store paths for each date
    tseries_folders = cell(length(current_dates_group), 1);   % Store tseries folder names
    tseries_results_paths = cell(length(current_dates_group), 1); % Store tseries result paths
    chosen_folder_processing = cell(length(current_dates_group), 1); % Store paths for folders being processed

    % List and filter subfolders based on a specific naming convention (outside loop)
    all_specificSubfolders = {};  % Cell array to hold all specific subfolders
    
    for k = 1:length(current_dates_group)
        % Extract the last part of the path (folder name without extension)
        [~, tseries_folder, ~] = fileparts(current_env_group{k});

        % Create the full path for the date and result folder
        date_path = fullfile(base_path, current_dates_group{k});
        tseries_result_path = fullfile(base_path, current_dates_group{k}, tseries_folder);
        
        % Create the tseries result folder if it doesn't exist
        if ~exist(tseries_result_path, 'dir')
            mkdir(tseries_result_path);
            disp(['Created folder: ', tseries_result_path]);
        end

        % List and filter subfolders based on a specific naming convention
        subfolders = dir(tseries_result_path);
        subfolders = subfolders([subfolders.isdir]);  % Filter out files and keep only directories
        subfolders = subfolders(~ismember({subfolders.name}, {'.', '..'}));  % Remove '.' and '..' entries
        
        % Filter subfolders that match the date format (e.g., dd_mm_yy_HH_MM)
        specificSubfolders = subfolders(~cellfun('isempty', regexp({subfolders.name}, '^\d{2}_\d{2}_\d{2}_\d{2}_\d{2}$', 'once')));

        % Add the filtered subfolders to the list of all specific subfolders
        all_specificSubfolders{k} = specificSubfolders;
        
        % Store the paths and folder names for further processing
        date_group_paths{k} = date_path;
        tseries_folders{k} = tseries_folder;
        tseries_results_paths{k} = tseries_result_path;
    end
    
    % Now, after the loop, we process the user choice and sorting
    all_unique_subfolders = {};  % This will hold all unique subfolders across dates
    for k = 1:length(current_dates_group)
        specificSubfolders = all_specificSubfolders{k};  % Get the specific subfolders for the current date
        
        % If no subfolders match the format, create a new folder with the current datetime
        if isempty(specificSubfolders)
            newSubfolderPath = fullfile(tseries_results_paths{k}, daytime);
            mkdir(newSubfolderPath);
            disp(['No subfolder found. Created new folder: ', newSubfolderPath]);
            chosen_folder_processing{k} = newSubfolderPath;
            continue;  % Move to the next date in the loop
        end
        
        % Sort the subfolders in descending order (most recent first)
        dates = datetime({specificSubfolders.name}, 'InputFormat', 'dd_MM_yy_HH_mm', 'Format', 'dd_MM_yy_HH_mm');
        [~, sortedIndices] = sort(dates, 'descend');
        specificSubfolders = specificSubfolders(sortedIndices);  % Reorder subfolders
        
        % Store all unique subfolders in the cell array, combined across all dates
        all_unique_subfolders = [all_unique_subfolders, {specificSubfolders.name}];
    end
    
    % Now, remove duplicates by using unique() function
    unique_subfolders = unique(all_unique_subfolders);  % Get unique subfolder names

    % Now, ask the user to choose a subfolder from the unique list (if they chose "no")
    if strcmpi(user_choice1, '2')
        if strcmpi(user_choice2, '1')
            % Display the message for the current animal
            disp(['Here are all the available subfolders for ', current_animal_group, ':']);
            
            % Display each unique subfolder for the current animal
            for j = 1:length(unique_subfolders)
                disp(['Subfolder ', num2str(j), ': ', unique_subfolders{j}]);
            end
            
            % Ask the user to select a subfolder by entering the corresponding number
            selectedIndex = input('Enter the number corresponding to your choice: ');
            
            % Check if the user entered a valid index
            if selectedIndex < 1 || selectedIndex > length(unique_subfolders)
                disp('Invalid choice. Please select a valid subfolder.');
                return;  % Exit if the choice is invalid
            end
            
            % Get the selected subfolder name
            selected_subfolder_name = unique_subfolders{selectedIndex};
            
            % Reconstruct the path to the selected subfolder
            for k = 1:length(current_dates_group)
                specificSubfolders = all_specificSubfolders{k};  % Get the specific subfolders for the current date
                
                % Find the matching subfolder
                matchingSubfolder = specificSubfolders(strcmp({specificSubfolders.name}, selected_subfolder_name));
                
                if ~isempty(matchingSubfolder)
                    % Reconstruct the full path to the selected subfolder
                    chosen_folder_processing{k} = fullfile(tseries_results_paths{k}, matchingSubfolder.name);
                    disp(['Selected subfolder: ', chosen_folder_processing{k}]);
                end
            end
        else
            % Create a new folder with the current datetime
            newFolderPath = fullfile(tseries_results_paths{k}, daytime);
            mkdir(newFolderPath);
            disp(['Created new saving folder: ', newFolderPath]);
            
            % Store the path to the newly created folder
            chosen_folder_processing{k} = newFolderPath;
        end

    elseif strcmpi(user_choice1, '1')
        % Handle the case when user selects "yes" (choose most recent subfolder automatically)
        for k = 1:length(current_dates_group)
            specificSubfolders = all_specificSubfolders{k};  % Get the specific subfolders for the current date
            
            % If there are any specific subfolders
            if ~isempty(specificSubfolders)
                % Select the most recent one
                most_recent_subfolder = specificSubfolders(1);  % The first after sorting in descending order
                chosen_folder_processing{k} = fullfile(tseries_results_paths{k}, most_recent_subfolder.name);
                disp(['Automatically selected the most recent subfolder: ', chosen_folder_processing{k}]);
            end
        end
    end
end
