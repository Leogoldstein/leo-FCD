function [chosen_folder_processing_gcamp, chosen_folder_processing_blue] = create_base_folders(date_group_paths, current_gcamp_folders_names_group, current_blue_folders_names_group, daytime, user_choice1, user_choice2, current_animal_group)
    % Function to create base folders for each date and process subfolders

    chosen_folder_processing_gcamp = cell(length(date_group_paths), 1); % Store paths for gcamp folders being processed
    chosen_folder_processing_blue = cell(length(date_group_paths), 1); % Store paths for blue folders being processed

    % List and filter subfolders based on a specific naming convention (outside loop)
    all_specificSubfolders = {};  % Cell array to hold all specific subfolders

    for k = 1:length(date_group_paths)
        % List and filter subfolders in the main date folder
        subfolders = dir(date_group_paths{k});
        subfolders = subfolders([subfolders.isdir]);  % Filter out files and keep only directories
        subfolders = subfolders(~ismember({subfolders.name}, {'.', '..'}));  % Remove '.' and '..' entries

        % Filter subfolders that match the date format (e.g., dd_mm_yy_HH_MM)
        specificSubfolders = subfolders(~cellfun('isempty', regexp({subfolders.name}, '^\d{2}_\d{2}_\d{2}_\d{2}_\d{2}$', 'once')));

        % Add the filtered subfolders to the list of all specific subfolders
        all_specificSubfolders{k} = specificSubfolders;
    end

    % Now, after the loop, we process the user choice and sorting
    all_unique_subfolders = {};  % This will hold all unique subfolders across dates
    for k = 1:length(date_group_paths)
        specificSubfolders = all_specificSubfolders{k};  % Get the specific subfolders for the current date

        % If no subfolders match the format, create a new folder with the current datetime
        if isempty(specificSubfolders)
            % For gcamp
            newSubfolderPath_gcamp = fullfile(date_group_paths{k}, daytime, current_gcamp_folders_names_group{k});
            mkdir(newSubfolderPath_gcamp);
            disp(['No subfolder found. Created new gcamp folder: ', newSubfolderPath_gcamp]);
            chosen_folder_processing_gcamp{k} = newSubfolderPath_gcamp;
            
            % For blue
            newSubfolderPath_blue = fullfile(date_group_paths{k}, daytime, current_blue_folders_names_group{k});
            mkdir(newSubfolderPath_blue);
            disp(['No subfolder found. Created new blue folder: ', newSubfolderPath_blue]);
            chosen_folder_processing_blue{k} = newSubfolderPath_blue;
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

    % Process user_choice1 and user_choice2 only if they are not empty
    if ~isempty(user_choice1) && strcmpi(user_choice1, '2')
        if ~isempty(user_choice2) && strcmpi(user_choice2, '1')
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

            % Reconstruct the path to the selected subfolder for gcamp and blue
            for k = 1:length(date_group_paths)
                specificSubfolders = all_specificSubfolders{k};  % Get the specific subfolders for the current date

                % Find the matching subfolder
                matchingSubfolder = specificSubfolders(strcmp({specificSubfolders.name}, selected_subfolder_name));

                if ~isempty(matchingSubfolder)
                    % Reconstruct the full path to the selected subfolder for gcamp
                    chosen_folder_processing_gcamp{k} = fullfile(date_group_paths{k}, matchingSubfolder.name, current_gcamp_folders_names_group{k});
                    disp(['Selected gcamp subfolder: ', chosen_folder_processing_gcamp{k}]);

                    % Reconstruct the full path to the selected subfolder for blue
                    chosen_folder_processing_blue{k} = fullfile(date_group_paths{k}, matchingSubfolder.name, current_blue_folders_names_group{k});
                    disp(['Selected blue subfolder: ', chosen_folder_processing_blue{k}]);
                end            
            end
        else
            for k = 1:length(date_group_paths)
                % Create a new folder with the current datetime for gcamp
                newFolderPath_gcamp = fullfile(date_group_paths{k}, daytime, current_gcamp_folders_names_group{k});
                mkdir(newFolderPath_gcamp);
                disp(['Created new gcamp saving folder: ', newFolderPath_gcamp]);
                chosen_folder_processing_gcamp{k} = newFolderPath_gcamp;

                % Create a new folder with the current datetime for blue
                newFolderPath_blue = fullfile(date_group_paths{k}, daytime, current_blue_folders_names_group{k});
                mkdir(newFolderPath_blue);
                disp(['Created new blue saving folder: ', newFolderPath_blue]);
                chosen_folder_processing_blue{k} = newFolderPath_blue;
            end
        end
    elseif ~isempty(user_choice1) && strcmpi(user_choice1, '1')
        % Handle the case when user selects "yes" (choose most recent subfolder automatically)
        for k = 1:length(date_group_paths)
            specificSubfolders = all_specificSubfolders{k};  % Get the specific subfolders for the current date

            % If there are any specific subfolders
            if ~isempty(specificSubfolders)
                % Select the most recent one for gcamp
                most_recent_subfolder_gcamp = specificSubfolders(1);  % The first after sorting in descending order
                chosen_folder_processing_gcamp{k} = fullfile(date_group_paths{k}, most_recent_subfolder_gcamp.name, current_gcamp_folders_names_group{k});
                disp(['Automatically selected the most recent gcamp subfolder: ', chosen_folder_processing_gcamp{k}]);

                % Select the most recent one for blue
                most_recent_subfolder_blue = specificSubfolders(1);  % The first after sorting in descending order
                chosen_folder_processing_blue{k} = fullfile(date_group_paths{k}, most_recent_subfolder_blue.name, current_blue_folders_names_group{k});
                disp(['Automatically selected the most recent blue subfolder: ', chosen_folder_processing_blue{k}]);
            end
        end
    end
end
