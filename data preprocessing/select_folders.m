function selectedFolders = select_folders(initial_folder)
    % Check if the initial folder exists
    if ~isfolder(initial_folder)
        error('The initial folder does not exist.');
    end

    % Ask the user if they want to select specific folders or all folders
    choice = questdlg('Do you want to select specific folders or all folders?', ...
        'Folder Selection Mode', ...
        'Specific Folders', 'All Folders', 'Cancel', 'Cancel');

    % Initialize an empty cell array to store the selected folders
    selectedFolders = {};

    % Handle the user's choice
    switch choice
        case 'Specific Folders'
            while true
                % Prompt the user to select a folder
                selectedFolder = uigetdir(initial_folder, 'Select a folder');

                % Check if the user canceled the selection
                if isequal(selectedFolder, 0)
                    disp('User clicked Cancel. Exiting folder selection.');
                    break;  % Exit the loop
                end

                % Process the selected folder
                selectedFolders = [selectedFolders, process_folder(selectedFolder)];

                % Ask the user if they want to select another folder
                anotherChoice = questdlg('Select another folder?', 'Folder Selection', 'Yes', 'No', 'No');

                if strcmp(anotherChoice, 'No')
                    break;  % Exit the loop if the user does not want to select another folder
                end
            end
            
        case 'All Folders'
            % Get a list of all items (files and folders) in the initial folder
            items = dir(initial_folder);

            % Iterate through all items
            for idx = 1:length(items)
                % Get the name of the item
                item_name = items(idx).name;

                % Get the full path of the item
                item_path = fullfile(initial_folder, item_name);

                % Check if the item is a directory and not '.' or '..'
                if items(idx).isdir && ~strcmp(item_name, '.') && ~strcmp(item_name, '..')
                    % Process the folder and append results
                    selectedFolders = [selectedFolders, process_folder(item_path)];
                end
            end

        otherwise
            disp('User canceled the selection. No folders selected.');
            return;
    end

    % Display the list of selected folders
    disp('Selected folders:');
    for k = 1:length(selectedFolders)
        disp(selectedFolders{k});
    end
end

function processedFolders = process_folder(folderPath)
    % Initialize a cell array for processed folders
    processedFolders = {};

    % Get the name of the last part of the path
    [~, folderName] = fileparts(folderPath);

    % Check if the folder name resembles a date format
    if is_date_format(folderName)
        processedFolders{end+1} = [folderPath, filesep];
        return; % Return early if it's a date format
    end

    % Get all subfolders (1st level and deeper)
    subFolders = dir(folderPath);
    
    for j = 1:length(subFolders)
        subFolderName = subFolders(j).name;
        
        % Skip '.' and '..' directories
        if subFolders(j).isdir && ~ismember(subFolderName, {'.', '..'})
            subFolderPath = fullfile(folderPath, subFolderName);

            % Check second-level subfolders if the name contains 'mTor'
            if contains(folderName, 'mTor')
                secondLevelSubFolders = dir(subFolderPath);
                for k = 1:length(secondLevelSubFolders)
                    if secondLevelSubFolders(k).isdir && ~ismember(secondLevelSubFolders(k).name, {'.', '..'}) && is_date_format(secondLevelSubFolders(k).name)
                        processedFolders{end+1} = fullfile(subFolderPath, secondLevelSubFolders(k).name, filesep);
                    end
                end
            % Otherwise, check if the subfolder name matches a date format
            elseif is_date_format(subFolderName)
                processedFolders{end+1} = [subFolderPath, filesep];
            end
        end
    end
    
    % If no date-formatted subfolder is found, add the main folder
    if isempty(processedFolders)
        processedFolders{end+1} = [folderPath, filesep];
    end
end



function isDate = is_date_format(folderName)
    % Check if the folder name follows the 'YYYY-MM-DD' or 'YYYY-MM-DD_a' pattern
    isDate = false;
    
    % Check if the folder name is of the correct length (10 or 12 characters)
    if length(folderName) == 10 || length(folderName) == 12
        % Extract the year, month, and day from the folder name
        year = str2double(folderName(1:4));
        month = str2double(folderName(6:7));
        day = str2double(folderName(9:10));
        
        % Check if year, month, and day are valid numbers
        if ~isnan(year) && ~isnan(month) && ~isnan(day)
            % Validate the date format: 'YYYY-MM-DD'
            if folderName(5) == '-' && folderName(8) == '-'
                % If the folder name is 12 characters, it must end with '_a'
                if length(folderName) == 12 && strcmp(folderName(end-1:end), '_a')
                    isDate = true;
                % Otherwise, it must exactly match 'YYYY-MM-DD'
                elseif length(folderName) == 10
                    isDate = true;
                end
            end
        end
    end
end
