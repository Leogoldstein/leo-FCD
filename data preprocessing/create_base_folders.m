function [chosen_folder_processing_gcamp, chosen_folder_processing_blue] = create_base_folders(date_group_paths, current_gcamp_folders_names_group, current_blue_folders_names_group, daytime, user_choice1, user_choice2, current_animal_group)
    % Function to create base folders for each date and process subfolders
    
    chosen_folder_processing_gcamp = cell(length(date_group_paths), 1); % Store paths for gcamp folders being processed
    chosen_folder_processing_blue = cell(length(date_group_paths), 1); % Store paths for blue folders being processed

    all_specificSubfolders = {};  % Cell array to hold all specific subfolders

    for k = 1:length(date_group_paths)
        % List and filter subfolders in the main date folder
        subfolders = dir(date_group_paths{k});
        subfolders = subfolders([subfolders.isdir]);  % Keep only directories
        subfolders = subfolders(~ismember({subfolders.name}, {'.', '..'}));  % Remove '.' and '..'

        % Filter subfolders that match the date format (e.g., dd_mm_yy_HH_MM)
        specificSubfolders = subfolders(~cellfun('isempty', regexp({subfolders.name}, '^\d{2}_\d{2}_\d{2}_\d{2}_\d{2}$', 'once')));

        % Add to the list of all specific subfolders
        all_specificSubfolders{k} = specificSubfolders;
    end

    all_unique_subfolders = {};  % Hold all unique subfolders across dates

    for k = 1:length(date_group_paths)
        specificSubfolders = all_specificSubfolders{k};  % Get the specific subfolders for the current date

        % If no subfolders match the format, create a new folder
        if isempty(specificSubfolders)
            % For gcamp
            newSubfolderPath_gcamp = fullfile(date_group_paths{k}, daytime, current_gcamp_folders_names_group{k});
            mkdir(newSubfolderPath_gcamp);
            disp(['No subfolder found. Created new gcamp folder: ', newSubfolderPath_gcamp]);
            chosen_folder_processing_gcamp{k} = newSubfolderPath_gcamp;
            
            % For blue (only if the name exists)
            if ~isempty(current_blue_folders_names_group) && ~isempty(current_blue_folders_names_group{k})
                newSubfolderPath_blue = fullfile(date_group_paths{k}, daytime, current_blue_folders_names_group{k});
                mkdir(newSubfolderPath_blue);
                disp(['No subfolder found. Created new folder for analysis: ', newSubfolderPath_blue]);
                chosen_folder_processing_blue{k} = newSubfolderPath_blue;
            else
                disp('Skipping blue folder creation due to missing folder name.');
                chosen_folder_processing_blue{k} = [];
            end
            continue;
        end

        % Sort subfolders in descending order (most recent first)
        dates = datetime({specificSubfolders.name}, 'InputFormat', 'dd_MM_yy_HH_mm', 'Format', 'dd_MM_yy_HH_mm');
        [~, sortedIndices] = sort(dates, 'descend');
        specificSubfolders = specificSubfolders(sortedIndices);  

        % Store unique subfolders
        all_unique_subfolders = [all_unique_subfolders, {specificSubfolders.name}];
    end

    unique_subfolders = unique(all_unique_subfolders);  % Remove duplicates

    if ~isempty(user_choice1) && strcmpi(user_choice1, '2')
        if ~isempty(user_choice2) && strcmpi(user_choice2, '1')
            % Show available subfolders
            disp(['Here are all the available subfolders for ', current_animal_group, ':']);
            for j = 1:length(unique_subfolders)
                disp(['Subfolder ', num2str(j), ': ', unique_subfolders{j}]);
            end

            % User input for selection
            selectedIndex = input('Enter the number corresponding to your choice: ');

            if selectedIndex < 1 || selectedIndex > length(unique_subfolders)
                disp('Invalid choice. Please select a valid subfolder.');
                return;
            end

            % Get the selected subfolder name
            selected_subfolder_name = unique_subfolders{selectedIndex};

            % Assign selected subfolder paths
            for k = 1:length(date_group_paths)
                specificSubfolders = all_specificSubfolders{k};

                % Find the matching subfolder
                matchingSubfolder = specificSubfolders(strcmp({specificSubfolders.name}, selected_subfolder_name));

                if ~isempty(matchingSubfolder)
                    chosen_folder_processing_gcamp{k} = fullfile(date_group_paths{k}, matchingSubfolder.name, current_gcamp_folders_names_group{k});
                    disp(['Selected gcamp subfolder: ', chosen_folder_processing_gcamp{k}]);

                    if ~isempty(current_blue_folders_names_group) && ~isempty(current_blue_folders_names_group{k})
                        chosen_folder_processing_blue{k} = fullfile(date_group_paths{k}, matchingSubfolder.name, current_blue_folders_names_group{k});
                        disp(['Selected blue subfolder: ', chosen_folder_processing_blue{k}]);
                    else
                        chosen_folder_processing_blue{k} = [];
                    end
                end
            end
        else
            for k = 1:length(date_group_paths)
                newFolderPath_gcamp = fullfile(date_group_paths{k}, daytime, current_gcamp_folders_names_group{k});
                mkdir(newFolderPath_gcamp);
                disp(['Created new gcamp saving folder: ', newFolderPath_gcamp]);
                chosen_folder_processing_gcamp{k} = newFolderPath_gcamp;

                if ~isempty(current_blue_folders_names_group) && ~isempty(current_blue_folders_names_group{k})
                    newFolderPath_blue = fullfile(date_group_paths{k}, daytime, current_blue_folders_names_group{k});
                    mkdir(newFolderPath_blue);
                    disp(['Created new blue saving folder: ', newFolderPath_blue]);
                    chosen_folder_processing_blue{k} = newFolderPath_blue;
                else
                    chosen_folder_processing_blue{k} = [];
                end
            end
        end
    elseif ~isempty(user_choice1) && strcmpi(user_choice1, '1')
        % Auto-select most recent subfolder
        for k = 1:length(date_group_paths)
            specificSubfolders = all_specificSubfolders{k};

            if ~isempty(specificSubfolders)
                most_recent_subfolder_gcamp = specificSubfolders(1);
                chosen_folder_processing_gcamp{k} = fullfile(date_group_paths{k}, most_recent_subfolder_gcamp.name, current_gcamp_folders_names_group{k});
                disp(['Automatically selected the most recent gcamp subfolder: ', chosen_folder_processing_gcamp{k}]);

                if ~isempty(current_blue_folders_names_group) && ~isempty(current_blue_folders_names_group{k})
                    most_recent_subfolder_blue = specificSubfolders(1);
                    chosen_folder_processing_blue{k} = fullfile(date_group_paths{k}, most_recent_subfolder_blue.name, current_blue_folders_names_group{k});
                    disp(['Automatically selected the most recent blue subfolder: ', chosen_folder_processing_blue{k}]);
                else
                    chosen_folder_processing_blue{k} = [];
                end
            end
        end
    end
end
