function selectedFolders = select_folders(initial_folder)
    % Check if the initial folder exists
    if ~isfolder(initial_folder)
        error('The initial folder does not exist.');
    end

    % Determine last folder name
    [~, lastFolderName] = fileparts(initial_folder);

    % Ask the user which selection mode to use
    if lastFolderName == "FCD"
        options = {'Specific Folders', 'All Good Folders', 'All Good Folders with Blue Cells'};
        [idx, ok] = listdlg('PromptString','Select folder selection mode:', ...
                            'SelectionMode','single', 'ListString',options);
        if ~ok
            disp('User canceled the selection.');
            return;
        end
        choice = options{idx};
    else
        choice = questdlg('Do you want to select specific folders or all folders?', ...
                          'Folder Selection Mode', ...
                          'Specific Folders', 'All Good Folders', 'Cancel');
    end

    % Initialize selected folders
    selectedFolders = {};

    switch choice
        case 'Specific Folders'
            while true
                selectedFolder = uigetdir(initial_folder, 'Select a folder');
                if isequal(selectedFolder, 0)
                    disp('User clicked Cancel. Exiting folder selection.');
                    break;
                end
                selectedFolders = [selectedFolders, process_folder(selectedFolder)];
                anotherChoice = questdlg('Select another folder?', 'Folder Selection', 'Yes', 'No', 'No');
                if strcmp(anotherChoice, 'No')
                    break;
                end
            end

        case 'All Good Folders'
            folder_names = get_folder_list('gcamp', lastFolderName);
            selectedFolders = process_folder_list(folder_names, initial_folder);

        case 'All Good Folders with Blue Cells'
            folder_names = get_folder_list('blue', lastFolderName);
            selectedFolders = process_folder_list(folder_names, initial_folder);

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

%% --- Helper Functions ---

function selectedFolders = process_folder_list(folder_names, initial_folder)
    selectedFolders = {};
    for idx = 1:length(folder_names)
        item_name = folder_names{idx};
        item_path = fullfile(initial_folder, item_name);
        if isfolder(item_path)
            fprintf('Processing folder: %s\n', item_path);
            selectedFolders = [selectedFolders, process_folder(item_path)];
        else
            fprintf('Folder not found: %s\n', item_path);
        end
    end
end

function folder_names = get_folder_list(type, lastFolderName)
    switch lastFolderName
        case "jm"
            folder_names = {'jm031','jm032','jm038','jm039','jm040','jm046'};
        case "WT"
            folder_names = {
                'an1\2024-03-04';
                'an2\2024-04-29';
                'an2\2024-04-30';
                'an4\2024-06-07';
                'an5\2024-06-12';
                'an5\2024-06-13';
                'an5\2024-06-14';
                'an7\2024-09-24';
                'an7\2024-09-25';
                'an7\2024-09-26';
                'an7\2024-09-27';
            };
        case "FCD"
            switch type
                case 'gcamp'
                    folder_names = {
                        'ani3\2024-06-26';
                        'ani3\2024-06-28';
                        'ani5\2024-06-27';
                        'mTor13\ani2\2024-10-22';
                        'mTor14\ani1\2024-10-23';
                        'mTor14\ani1\2024-10-24';
                        'mTor14\ani1\2024-10-25';
                        'mTor14\ani3\2024-10-24';
                        'mTor14\ani3\2024-10-26';
                        'mTor14\ani3\2024-10-27';
                        'mTor14\ani3\2024-10-28';
                        'mTor16\ani3\2024-11-21';
                        'mTor16\ani4\2024-11-21';
                        'mTor17\ani3\2024-12-19';
                    };
                case 'blue'
                    folder_names = {
                        %'mTor20\ani4\2025-01-30';14 cellules gcamp conservées sur 99
                        %'mTor20\ani4\2025-01-31'; 0 cellules conservée sur 88
                        'mTor20\ani5\2025-01-30'; % 177 sur 178 (7 bleues)
                        'mTor19\ani6\2025-01-31'; % 34 sur 110 (2 bleues)
                        % 'mTor19\ani6\2025-02-01'; 11 cellules conservées sur 28
                        % 'mTor19\ani7\2025-01-31'; 2 cellules conservées sur 14
                        %'mTor17\ani1\2024-12-21'; % 24 cellules conservées sur 191 (1 bleue)
                        % 'mTor17\ani3\2024-12-21'; 8 cellules conservées sur 97
                        %'mTor17\ani3\2024-12-22'; 0 cellules sur 90
                        'mTor17\ani3\2024-12-23'; % 39 cellules sur 203 (14 bleues)
                    };
            end
        otherwise
            folder_names = {};
    end
end

function processedFolders = process_folder(folderPath)
    processedFolders = {};
    [~, folderName] = fileparts(folderPath);

    if is_date_format(folderName)
        processedFolders{end+1} = [folderPath, filesep];
        return;
    end

    subFolders = dir(folderPath);
    for j = 1:length(subFolders)
        subFolderName = subFolders(j).name;
        if subFolders(j).isdir && ~ismember(subFolderName, {'.','..'})
            subFolderPath = fullfile(folderPath, subFolderName);
            if contains(folderName, 'mTor')
                secondLevelSubFolders = dir(subFolderPath);
                for k = 1:length(secondLevelSubFolders)
                    if secondLevelSubFolders(k).isdir && ~ismember(secondLevelSubFolders(k).name, {'.','..'}) && is_date_format(secondLevelSubFolders(k).name)
                        processedFolders{end+1} = fullfile(subFolderPath, secondLevelSubFolders(k).name, filesep);
                    end
                end
            elseif is_date_format(subFolderName)
                processedFolders{end+1} = [subFolderPath, filesep];
            end
        end
    end

    if isempty(processedFolders)
        processedFolders{end+1} = [folderPath, filesep];
    end
end

function isDate = is_date_format(folderName)
    isDate = false;
    if length(folderName) == 10 || length(folderName) == 12
        year = str2double(folderName(1:4));
        month = str2double(folderName(6:7));
        day = str2double(folderName(9:10));
        if ~isnan(year) && ~isnan(month) && ~isnan(day) && folderName(5) == '-' && folderName(8) == '-'
            if length(folderName) == 12 && strcmp(folderName(end-1:end), '_a')
                isDate = true;
            elseif length(folderName) == 10
                isDate = true;
            end
        end
    end
end