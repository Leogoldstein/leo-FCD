function [selectedFolders, automatic_selection] = select_folders( ...
        initial_folder, include_electroporated_cells)

    if ~isfolder(initial_folder)
        error('The initial folder does not exist.');
    end

    if nargin < 2 || isempty(include_electroporated_cells)
        include_electroporated_cells = 0;
    end

    if ~ismember(include_electroporated_cells, [0 1])
        error('include_electroporated_cells must be 0 or 1.');
    end

    [~, lastFolderName] = fileparts(initial_folder);

    % False by default:
    % - manual selection
    % - canceled selection
    automatic_selection = false;

    %==============================================================%
    % Folder selection mode
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
        % Manual selection
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
        % Pre-selected folders
        %==========================================================%
        case 'Pre-selected folders'

            automatic_selection = true;

            %======================================================%
            % FCD / SHAM:
            %
            % First subdivision:
            %   Development
            %   Adult
            %
            % Then:
            %   GCaMP
            %   electroporated
            %
            % according to include_electroporated_cells.
            %======================================================%
            if ismember(upper(lastFolderName), {'FCD', 'SHAM'})

                %--------------------------------------------------%
                % Select Development / Adult
                %--------------------------------------------------%
                age_group = questdlg( ...
                    sprintf( ...
                        'Select pre-selected group for %s:', ...
                        upper(lastFolderName)), ...
                    'Pre-selected Group', ...
                    'Development', ...
                    'Adult', ...
                    'Cancel', ...
                    'Development');

                if isempty(age_group) || strcmp(age_group, 'Cancel')

                    automatic_selection = false;
                    selectedFolders = {};

                    fprintf( ...
                        '[SELECT] Pre-selected group selection canceled.\n');

                    return;
                end

                %--------------------------------------------------%
                % Determine GCaMP / electroporated
                %--------------------------------------------------%
                if include_electroporated_cells

                    folder_type = 'electroporated';

                    fprintf( ...
                        ['[SELECT] %s | %s | ' ...
                         'electroporated folders\n'], ...
                        upper(lastFolderName), ...
                        age_group);

                else

                    folder_type = 'gcamp';

                    fprintf( ...
                        '[SELECT] %s | %s | GCaMP folders\n', ...
                        upper(lastFolderName), ...
                        age_group);
                end

                %--------------------------------------------------%
                % Get corresponding folder list
                %--------------------------------------------------%
                folder_names = get_folder_list( ...
                    folder_type, ...
                    lastFolderName, ...
                    age_group);

                %--------------------------------------------------%
                % Empty list
                %--------------------------------------------------%
                if isempty(folder_names)

                    fprintf( ...
                        ['[SELECT] No pre-selected folders ' ...
                         'defined for:\n']);

                    fprintf( ...
                        '         Group : %s\n', ...
                        upper(lastFolderName));

                    fprintf( ...
                        '         Age   : %s\n', ...
                        age_group);

                    fprintf( ...
                        '         Type  : %s\n', ...
                        folder_type);

                    selectedFolders = {};
                    return;
                end

                %--------------------------------------------------%
                % Process selected list
                %--------------------------------------------------%
                selectedFolders = process_folder_list( ...
                    folder_names, ...
                    initial_folder);

            %======================================================%
            % JM / WT
            %======================================================%
            else

                folder_type = 'gcamp';

                fprintf( ...
                    '[SELECT] %s GCaMP folders\n', ...
                    lastFolderName);

                folder_names = get_folder_list( ...
                    folder_type, ...
                    lastFolderName, ...
                    '');

                selectedFolders = process_folder_list( ...
                    folder_names, ...
                    initial_folder);
            end

        %==========================================================%
        % Cancel
        %==========================================================%
        otherwise

            automatic_selection = false;

            disp('User canceled the selection. No folders selected.');

            selectedFolders = {};
            return;
    end

    %==============================================================%
    % Display selection mode
    %==============================================================%
    if automatic_selection

        fprintf( ...
            '[SELECT] Automatic folder selection.\n');

    else

        fprintf( ...
            '[SELECT] Manual folder selection.\n');
    end

    %==============================================================%
    % Display selected folders
    %==============================================================%
    disp('Selected folders:');

    for k = 1:numel(selectedFolders)
        disp(selectedFolders{k});
    end
end


%% ========================================================================%
% Helper Functions
% =========================================================================%

function selectedFolders = process_folder_list( ...
        folder_names, initial_folder)

    selectedFolders = {};

    for idx = 1:numel(folder_names)

        item_name = folder_names{idx};
        item_path = fullfile(initial_folder, item_name);

        if isfolder(item_path)

            fprintf( ...
                'Processing folder: %s\n', ...
                item_path);

            selectedFolders = [ ...
                selectedFolders, ...
                process_folder(item_path)]; %#ok<AGROW>

        else

            fprintf( ...
                'Folder not found: %s\n', ...
                item_path);
        end
    end
end


function folder_names = get_folder_list( ...
        type, lastFolderName, age_group)

    folder_names = {};

    switch upper(lastFolderName)

        %==========================================================%
        % JM
        %==========================================================%
        case 'JM'

            folder_names = {
                'jm031';
                'jm032';
                'jm038';
                'jm039';
                'jm040';
                'jm046'
            };

        %==========================================================%
        % WT
        %==========================================================%
        case 'WT'

            folder_names = {
                'an1\2024-04-03';
                'an2\2024-04-29';
                'an2\2024-04-30';
                %'an2\2024-05-02'; % artefactuel, P17
                %'an2\2024-05-06'; % artefactuel, P21
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

        %==========================================================%
        % SHAM
        %==========================================================%
        case 'SHAM'

            switch lower(age_group)

                %==================================================%
                % SHAM DEVELOPMENT
                %==================================================%
                case 'development'

                    switch lower(type)

                        %------------------------------------------%
                        % SHAM DEVELOPMENT - GCAMP
                        %------------------------------------------%
                        case 'gcamp'

                            folder_names = {
                                % Add SHAM Development GCaMP
                                % recordings here.
                            };

                        %------------------------------------------%
                        % SHAM DEVELOPMENT - ELECTROPORATED
                        %------------------------------------------%
                        case 'electroporated'

                            folder_names = {
                                % Add SHAM Development
                                % electroporated recordings here.
                            };

                        otherwise

                            folder_names = {};
                    end

                %==================================================%
                % SHAM ADULT
                %==================================================%
                case 'adult'

                    switch lower(type)

                        %------------------------------------------%
                        % SHAM ADULT - GCAMP
                        %------------------------------------------%
                        case 'gcamp'

                            folder_names = {
                                'mtor38\2199\30-01-2026';
                                'mtor38\2206\18-02-2026';
                                'mtor45\2487\21-04-2026';
                                'mtor45\2488\22-04-2026';
                            };

                        %------------------------------------------%
                        % SHAM ADULT - ELECTROPORATED
                        %------------------------------------------%
                        case 'electroporated'

                            folder_names = {
                                'mtor38\2206\06-02-2026';
                                'mtor41\2339\08-04-2026';
                                'mtor41\2340\08-04-2026';
                                'mtor45\2486\13-05-2026';
                            };

                        otherwise

                            folder_names = {};
                    end

                otherwise

                    folder_names = {};
            end

        %==========================================================%
        % FCD
        %==========================================================%
        case 'FCD'

            switch lower(age_group)

                %==================================================%
                % FCD DEVELOPMENT
                %==================================================%
                case 'development'

                    switch lower(type)

                        %------------------------------------------%
                        % FCD DEVELOPMENT - GCAMP
                        %------------------------------------------%
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
                                %'mTor14\ani3\2024-10-25'; % doit etre croppé
                                'mTor14\ani3\2024-10-26';
                                'mTor14\ani3\2024-10-27';
                                %'mTor14\ani3\2024-10-28'; % SNR low

                                %'mTor15\ani5\2024-11-23'; % trop peu de cellules
                                'mTor15\ani5\2024-11-24';
                                'mTor15\ani5\2024-11-25';
                                'mTor15\ani5\2024-11-26';

                                'mTor16\ani3\2024-11-21';
                                %'mTor16\ani4\2024-11-21'; % trop d'artefacts

                                'mTor17\ani1\2024-12-17';

                                'mTor17\ani3\2024-12-19';
                                'mTor17\ani3\2024-12-21';

                                'mTor19\ani6\2025-01-31';
                            };

                        %------------------------------------------%
                        % FCD DEVELOPMENT - ELECTROPORATED
                        %------------------------------------------%
                        case 'electroporated'

                            folder_names = {
                                'mTor17\ani1\2024-12-17';
                                %'mTor17\ani1\2024-12-18'; % pas assez de neurones
                                %'mTor17\ani1\2024-12-19'; % artefacts
                                %'mTor17\ani1\2024-12-20'; % artefacts
                                %'mTor17\ani1\2024-12-21'; % artefacts
                                %'mTor17\ani2\2024-12-19'; % artefacts et peu de neurones
                                %'mTor17\ani2\2024-12-20'; % pas assez de neurones

                                'mTor17\ani3\2024-12-19';
                                'mTor17\ani3\2024-12-20';
                                'mTor17\ani3\2024-12-21';
                                'mTor17\ani3\2024-12-22';
                                %'mTor17\ani3\2024-12-23'; % beaucoup d'artefacts

                                'mTor19\ani6\2025-01-31';
                                'mTor19\ani6\2025-02-01';

                                %'mTor20\ani5\2025-01-30'; % attention aux artefacts
                            };

                        otherwise

                            folder_names = {};
                    end

                %==================================================%
                % FCD ADULT
                %==================================================%
                case 'adult'

                    switch lower(type)

                        %------------------------------------------%
                        % FCD ADULT - GCAMP
                        %------------------------------------------%
                        case 'gcamp'

                            folder_names = {

                                'mtor29\1917\27-08-2025';
                            
                                'mtor31\1989\02-12-2025';
                                'mtor31\1989\09-01-2026';
                                'mtor31\1989\11-12-2025';
                                'mtor31\1989\16-01-2026';
                                'mtor31\1989\17-12-2025';
                                'mtor31\1989\21-01-2026';
                                'mtor31\1989\27-11-2025';
                            
                                'mtor31\1992\03-12-2025';
                                'mtor31\1992\09-01-2026';
                                'mtor31\1992\10-11-2025';
                                'mtor31\1992\11-12-2025';
                                'mtor31\1992\28-11-2025';
                            
                                'mtor31\1995\01-12-2025';
                                'mtor31\1995\06-11-2025';
                                'mtor31\1995\11-12-2025';
                                
                                'mtor35\2126\26-01-2026';
                                
                                'mtor35\2132\13-01-2026';
                                'mtor35\2132\22-01-2026';

                                'mtor35\2133\19-01-2026';

                                %'mtor35\2134\05-02-2026';
                                'mtor35\2134\05-02-2026(2)'; %deuxieme enregistrement vers 230, plus profond par rapport au 1er du meme jour
                                'mtor35\2134\19-01-2026';
                                'mtor35\2134\27-01-2026';

                                'mtor40\2308\26-02-2026';

                                'mtor40\2309\05-03-2026';
                                'mtor40\2309\05-03-2026(2)';
                              
                            };

                        %------------------------------------------%
                        % FCD ADULT - ELECTROPORATED
                        %------------------------------------------%
                        case 'electroporated'

                            folder_names = {

                                'mtor31\1989\14-11-2025';
                                'mtor31\1989\17-11-2025';
                                'mtor31\1989\24-11-2025';
                            
                                'mtor31\1992\14-11-2025';
                                'mtor31\1992\15-01-2026';
                                'mtor31\1992\17-12-2025';
                                'mtor31\1992\26-11-2025';
                            
                                'mtor31\1995\07-11-2025';
                                'mtor31\1995\17-11-2025';
                                'mtor31\1995\25-11-2025';

                                'mtor35\2133\27-01-2026';

                                'mtor40\2314\05-03-2026';
                                'mtor40\2314\05-03-2026(2)';
                                'mtor40\2314\20-02-2026';
                                'mtor40\2314\25-02-2026';

                            };

                        otherwise

                            folder_names = {};
                    end

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

    %==============================================================%
    % Folder itself is already a date folder
    %==============================================================%
    if is_date_format(folderName)

        processedFolders{end + 1} = ...
            [folderPath, filesep];

        return;
    end

    %==============================================================%
    % Search subfolders
    %==============================================================%
    subFolders = dir(folderPath);

    for j = 1:numel(subFolders)

        subFolderName = subFolders(j).name;

        if subFolders(j).isdir && ...
                ~ismember(subFolderName, {'.', '..'})

            subFolderPath = fullfile( ...
                folderPath, ...
                subFolderName);

            %------------------------------------------------------%
            % mTOR structure:
            %
            % mTorXX
            %   animal
            %       date
            %------------------------------------------------------%
            if contains(folderName, 'mTor') || ...
                    contains(folderName, 'mtor')

                secondLevelSubFolders = ...
                    dir(subFolderPath);

                for k = 1:numel(secondLevelSubFolders)

                    secondName = ...
                        secondLevelSubFolders(k).name;

                    if secondLevelSubFolders(k).isdir && ...
                        ~ismember(secondName, {'.', '..'}) && ...
                        is_date_format(secondName)
                
                        dateFolder = fullfile(subFolderPath, secondName);
                    
                        %==========================================================%
                        % Autre structure:
                        %
                        % mTorXX
                        %   animal
                        %      date
                        %         before
                        %         after
                        %==========================================================%
                        beforeFolder = fullfile(dateFolder, 'before');
                        afterFolder  = fullfile(dateFolder, 'after');
                    
                        if isfolder(beforeFolder)
                    
                            processedFolders{end + 1} = ...
                                [beforeFolder filesep];
                    
                        elseif isfolder(afterFolder)
                    
                            processedFolders{end + 1} = ...
                                [afterFolder filesep];
                    
                        else
                    
                            processedFolders{end + 1} = ...
                                [dateFolder filesep];
                    
                        end
                    end
                end
                
            %------------------------------------------------------%
            % Standard animal/date structure
            %------------------------------------------------------%
            elseif is_date_format(subFolderName)

                processedFolders{end + 1} = ...
                    [subFolderPath, filesep];
            end
        end
    end

    %==============================================================%
    % Nothing found -> retain input folder
    %==============================================================%
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

    %==============================================================%
    % Accept suffix "_a"
    %==============================================================%
    if numel(base) >= 2 && ...
            strcmp(base(end - 1:end), '_a')

        base = base(1:end - 2);
    end

    %==============================================================%
    % Accept suffix "(2)", "(3)", "(4)", ...
    %
    % Examples:
    %   13-01-2026(2)
    %   13-01-2026(3)
    %   2026-01-13(2)
    %==============================================================%
    base = regexprep( ...
        base, ...
        '\(\d+\)$', ...
        '');

    if numel(base) ~= 10
        return;
    end

    %==============================================================%
    % YYYY-MM-DD
    %==============================================================%
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

    %==============================================================%
    % DD-MM-YYYY
    %==============================================================%
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