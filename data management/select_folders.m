function [selectedFolders, automatic_selection] = select_folders( ...
        initial_folder, include_blue_cells)

    if ~isfolder(initial_folder)
        error('The initial folder does not exist.');
    end

    if nargin < 2 || isempty(include_blue_cells)
        include_blue_cells = 0;
    end

    if ~ismember(include_blue_cells, [0 1])
        error('include_blue_cells must be 0 or 1.');
    end

    [~, lastFolderName] = fileparts(initial_folder);

    % False by default:
    % - manual selection
    % - canceled selection
    automatic_selection = false;

    %==============================================================%
    %   Folder selection mode
    %==============================================================%
    choice = questdlg( ...
        'Do you want to select specific folders or all folders?', ...
        'Folder Selection Mode', ...
        'Specific Folders', ...
        'Pre-selected folders', ...
        'Cancel', ...
        'Pre-selected folders');

    selectedFolders = {};

    switch choice

        %==========================================================%
        %   Manual selection
        %==========================================================%
        case 'Specific Folders'

            automatic_selection = false;

            while true

                selectedFolder = uigetdir( ...
                    initial_folder, ...
                    'Select a folder');

                if isequal(selectedFolder, 0)
                    disp('User clicked Cancel. Exiting folder selection.');
                    break;
                end

                selectedFolders = [ ...
                    selectedFolders, ...
                    process_folder(selectedFolder)]; %#ok<AGROW>

                anotherChoice = questdlg( ...
                    'Select another folder?', ...
                    'Folder Selection', ...
                    'Yes', ...
                    'No', ...
                    'No');

                if ~strcmp(anotherChoice, 'Yes')
                    break;
                end
            end

        %==========================================================%
        %   Automatic selection
        %==========================================================%
        case 'Pre-selected folders'

            automatic_selection = true;

            if strcmpi(lastFolderName, 'FCD')

                if include_blue_cells
                    folder_type = 'blue';

                    fprintf([ ...
                        '[SELECT] FCD folders with ' ...
                        'blue / mTOR cells\n']);

                else
                    folder_type = 'gcamp';

                    fprintf([ ...
                        '[SELECT] FCD GCaMP folders\n']);
                end

            else
                folder_type = 'gcamp';
            end

            folder_names = get_folder_list( ...
                folder_type, lastFolderName);

            selectedFolders = process_folder_list( ...
                folder_names, initial_folder);

        otherwise

            automatic_selection = false;

            disp('User canceled the selection. No folders selected.');

            selectedFolders = {};
            return;
    end

    %==============================================================%
    %   Display selection mode
    %==============================================================%
    if automatic_selection
        fprintf('[SELECT] Automatic folder selection.\n');
    else
        fprintf('[SELECT] Manual folder selection.\n');
    end

    %==============================================================%
    %   Display selected folders
    %==============================================================%
    disp('Selected folders:');

    for k = 1:numel(selectedFolders)
        disp(selectedFolders{k});
    end
end

%% --- Helper Functions ---

function selectedFolders = process_folder_list( ...
        folder_names, initial_folder)

    selectedFolders = {};

    for idx = 1:numel(folder_names)

        item_name = folder_names{idx};
        item_path = fullfile(initial_folder, item_name);

        if isfolder(item_path)

            fprintf('Processing folder: %s\n', item_path);

            selectedFolders = [ ...
                selectedFolders, ...
                process_folder(item_path)]; %#ok<AGROW>

        else
            fprintf('Folder not found: %s\n', item_path);
        end
    end
end

function folder_names = get_folder_list(type, lastFolderName)

    switch lastFolderName

        case "jm"
            folder_names = {
                'jm031';
                'jm032';
                'jm038';
                'jm039';
                'jm040';
                'jm046'
            };

        case "WT"
            folder_names = {
                'an1\2024-04-03';
                'an2\2024-04-29';
                'an2\2024-04-30';
                %'an2\2024-05-02'; %artefactuel, P17
                %'an2\2024-05-06'; %artefactuel, P21
                %'an2\2024-05-07'; % P22
                'an3\2024-05-15';
                'an3\2024-05-16';
                'an3\2024-05-17';
                'an4\2024-06-07';
                'an5\2024-06-12';
                'an5\2024-06-13';
                'an5\2024-06-14';
                'an7\2024-09-24';
                'an7\2024-09-25';
                'an7\2024-09-26';
                'an7\2024-09-27';
                'an8\2024-09-26';
            };

        case "SHAM"
            folder_names = {
                'mtor38\2206\06-02-2026';
            };

        case "FCD"

            switch type

                case 'gcamp'
                    folder_names = {
                        'ani3\2024-06-28';
                        'ani4\2024-06-29';
                        'ani5\2024-06-27';
                        'mTor13\ani2\2024-10-22';
                        'mTor13\ani2\2024-10-24';
                        'mTor14\ani1\2024-10-22';
                        'mTor14\ani1\2024-10-23';
                        'mTor14\ani1\2024-10-24';
                        'mTor14\ani1\2024-10-25';
                        'mTor14\ani3\2024-10-24';
                        %'mTor14\ani3\2024-10-25'; %doit etre croppé
                        'mTor14\ani3\2024-10-26';
                        'mTor14\ani3\2024-10-27';
                        %'mTor14\ani3\2024-10-28'; SNR low
                        %'mTor15\ani5\2024-11-23'; %trop peu de cellules
                        'mTor15\ani5\2024-11-24';
                        'mTor15\ani5\2024-11-25';
                        'mTor15\ani5\2024-11-26';
                        'mTor16\ani3\2024-11-21';
                        %'mTor16\ani4\2024-11-21'; %trop d'artefacts
                        'mTor17\ani1\2024-12-17';
                        'mTor17\ani3\2024-12-19';
                        'mTor17\ani3\2024-12-21';
                        'mTor19\ani6\2025-01-31';
                    };

                case 'blue'
                    folder_names = {
                        'mTor17\ani1\2024-12-17';
                        %'mTor17\ani1\2024-12-18'; % pas assez de neurones
                        % 'mTor17\ani1\2024-12-19'; %artefacts
                        %'mTor17\ani1\2024-12-20'; %artefacts
                        %'mTor17\ani1\2024-12-21'; %artefacts
                        %'mTor17\ani2\2024-12-19'; % artefacts et peu de
                        %neurones
                        %'mTor17\ani2\2024-12-20'; %pas assez de neurones
                        'mTor17\ani3\2024-12-19'; % très peu de nerones mais artefacts convenables
                        'mTor17\ani3\2024-12-20';
                        'mTor17\ani3\2024-12-21';
                        'mTor17\ani3\2024-12-22';
                        %'mTor17\ani3\2024-12-23'; % bcp d'artefacts mais
                        %peut valoir le coup car bcp de neurones
                        'mTor19\ani6\2025-01-31';
                        'mTor19\ani6\2025-02-01';  
                        %'mTor20\ani5\2025-01-30'; % attention aux artefacts                                                                     
                    };

                otherwise
                    folder_names = {};
            end

        otherwise
            folder_names = {};
    end
end

function processedFolders = process_folder(folderPath)

    processedFolders = {};

    [~, folderName] = fileparts(folderPath);

    if is_date_format(folderName)
        processedFolders{end + 1} = [folderPath, filesep];
        return;
    end

    subFolders = dir(folderPath);

    for j = 1:numel(subFolders)

        subFolderName = subFolders(j).name;

        if subFolders(j).isdir && ...
                ~ismember(subFolderName, {'.', '..'})

            subFolderPath = fullfile( ...
                folderPath, subFolderName);

            if contains(folderName, 'mTor') || ...
                    contains(folderName, 'mtor')

                secondLevelSubFolders = dir(subFolderPath);

                for k = 1:numel(secondLevelSubFolders)

                    secondName = ...
                        secondLevelSubFolders(k).name;

                    if secondLevelSubFolders(k).isdir && ...
                            ~ismember(secondName, {'.', '..'}) && ...
                            is_date_format(secondName)

                        processedFolders{end + 1} = ...
                            fullfile( ...
                                subFolderPath, ...
                                secondName, ...
                                filesep);
                    end
                end

            elseif is_date_format(subFolderName)

                processedFolders{end + 1} = ...
                    [subFolderPath, filesep];
            end
        end
    end

    if isempty(processedFolders)
        processedFolders{end + 1} = ...
            [folderPath, filesep];
    end
end

function isDate = is_date_format(folderName)

    isDate = false;

    if ~ischar(folderName) && ~isstring(folderName)
        return;
    end

    folderName = char(folderName);

    base = folderName;

    if numel(base) >= 2 && ...
            strcmp(base(end - 1:end), '_a')

        base = base(1:end - 2);
    end

    if numel(base) ~= 10
        return;
    end

    if ~isempty(regexp( ...
            base, ...
            '^\d{4}-\d{2}-\d{2}$', ...
            'once'))

        y = str2double(base(1:4));
        m = str2double(base(6:7));
        d = str2double(base(9:10));

        isDate = is_valid_ymd(y, m, d);
        return;
    end

    if ~isempty(regexp( ...
            base, ...
            '^\d{2}-\d{2}-\d{4}$', ...
            'once'))

        d = str2double(base(1:2));
        m = str2double(base(4:5));
        y = str2double(base(7:10));

        isDate = is_valid_ymd(y, m, d);
    end
end

function ok = is_valid_ymd(y, m, d)

    ok = false;

    if any(isnan([y, m, d]))
        return;
    end

    if y < 1900 || y > 2100
        return;
    end

    if m < 1 || m > 12
        return;
    end

    if d < 1 || d > 31
        return;
    end

    try
        datetime(y, m, d);
        ok = true;
    catch
        ok = false;
    end
end