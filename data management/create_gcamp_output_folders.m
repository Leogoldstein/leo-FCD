function [selected_groups, daytime] = create_gcamp_output_folders(selected_groups)

    if nargin < 1 || isempty(selected_groups)
        daytime = '';
        return;
    end

    daytime_date = datestr(datetime('now'), 'yy_mm_dd_HH_MM');
    daytime = ['v' get_next_version_number_from_suite2p(selected_groups) '_' daytime_date];

    processing_choice1 = input('Do you want to process the most recent folder for processing (1/2)? ', 's');

    if strcmp(processing_choice1, '2')
        processing_choice2 = input('Do you want to select an existing folder or create a new one? (1/2): ', 's');
    else
        processing_choice2 = [];
    end

    type_names = fieldnames(selected_groups);

    for t = 1:numel(type_names)

        current_type = type_names{t};

        for k = 1:numel(selected_groups.(current_type))

            current_animal_group = selected_groups.(current_type)(k).animal_group;

            if isfield(selected_groups.(current_type)(k), 'paths') && ...
               isfield(selected_groups.(current_type)(k).paths, 'date')

                date_group_paths = selected_groups.(current_type)(k).paths.date;
            else
                date_group_paths = {};
                fprintf('  Aucun paths.date trouvé.\n');
            end

            if isrow(date_group_paths)
                date_group_paths = date_group_paths(:);
            end

            nDates = numel(date_group_paths);

            if isfield(selected_groups.(current_type)(k), 'paths') && ...
               isfield(selected_groups.(current_type)(k).paths, 'suite2p') && ...
               ~isempty(selected_groups.(current_type)(k).paths.suite2p)

                current_suite2p_group = selected_groups.(current_type)(k).paths.suite2p;
            else
                current_suite2p_group = cell(nDates, 4);   
            end

            current_suite2p_group = force_4col(current_suite2p_group, nDates);
            current_gcamp_folders_group = current_suite2p_group(:, 1);

            rename_old_processing_folders_from_suite2p(current_gcamp_folders_group);
            
            [gcamp_root_folders, gcamp_output_folders] = create_base_folders( ...
                date_group_paths, ...
                current_gcamp_folders_group, ...
                daytime, ...
                processing_choice1, ...
                processing_choice2, ...
                current_animal_group);

            selected_groups.(current_type)(k).paths.gcamp_root = gcamp_root_folders;
            selected_groups.(current_type)(k).paths.gcamp_output = gcamp_output_folders;
        end
    end
end


function C4 = force_4col(C, nRowsWanted)

    if nargin < 2
        if isempty(C)
            nRowsWanted = 0;
        else
            nRowsWanted = size(C,1);
        end
    end

    if isempty(C)
        C4 = cell(nRowsWanted, 4);
        return;
    end

    nRows = size(C,1);
    nCols = size(C,2);

    C4 = cell(max(nRows, nRowsWanted), 4);
    C4(1:nRows, 1:min(4,nCols)) = C(:, 1:min(4,nCols));
end


function rename_old_processing_folders_from_suite2p(current_gcamp_folders_group)

    if isempty(current_gcamp_folders_group)
        fprintf('    Aucun dossier suite2p à vérifier.\n');
        return;
    end

    if isrow(current_gcamp_folders_group)
        current_gcamp_folders_group = current_gcamp_folders_group(:);
    end

    for d = 1:numel(current_gcamp_folders_group)

        this_suite2p_path = current_gcamp_folders_group{d};

        while iscell(this_suite2p_path)
            if isempty(this_suite2p_path)
                this_suite2p_path = '';
                break;
            end
            this_suite2p_path = this_suite2p_path{1};
        end
        
        if isempty(this_suite2p_path)
            continue;
        end
        
        this_suite2p_path = char(string(this_suite2p_path));
        
        [~, last_name] = fileparts(this_suite2p_path);
        
        if startsWith(lower(last_name), 'plane')
            this_suite2p_path = fileparts(this_suite2p_path);
        end

        if isempty(this_suite2p_path)
            fprintf('      suite2p vide -> skip.\n');
            continue;
        end

        fprintf('      suite2p : %s\n', this_suite2p_path);

        if ~isfolder(this_suite2p_path)
            fprintf('      Dossier suite2p introuvable -> skip.\n');
            continue;
        end

        proc_root = fullfile(this_suite2p_path, 'after processing');

        if ~isfolder(proc_root)
            fprintf('      Aucun dossier "after processing" -> rien à convertir.\n');
            continue;
        end

        L = dir(proc_root);
        L = L([L.isdir]);

        old_names = {};
        old_dates = datetime.empty;

        for i = 1:numel(L)

            folder_name = L(i).name;

            if strcmp(folder_name, '.') || strcmp(folder_name, '..')
                continue;
            end

            tok = regexp(folder_name, ...
                '^(\d{2})_(\d{2})_(\d{2})_(\d{2})_(\d{2})$', ...
                'tokens', 'once');

            if isempty(tok)
                continue;
            end

            yy = str2double(tok{1});
            mm = str2double(tok{2});
            dd = str2double(tok{3});
            HH = str2double(tok{4});
            MM = str2double(tok{5});

            old_names{end+1,1} = folder_name;
            old_dates(end+1,1) = datetime(2000 + yy, mm, dd, HH, MM, 0);
        end

        if isempty(old_names)
            fprintf('      Aucun ancien dossier yy_mm_dd_HH_MM trouvé.\n');
            continue;
        end

        [old_dates, idx_sort] = sort(old_dates);
        old_names = old_names(idx_sort);

        for i = 1:numel(old_names)

            old_name = old_names{i};
            old_path = fullfile(proc_root, old_name);

            new_day = datestr(old_dates(i), 'yy_mm_dd');
            new_name = sprintf('v%d_%s', i, new_day);
            new_path = fullfile(proc_root, new_name);

            if isfolder(new_path)
                fprintf('      %s -> %s existe déjà : suppression ancien dossier.\n', ...
                    old_name, new_name);

                try
                    rmdir(old_path, 's');
                catch ME
                    warning('        Impossible de supprimer %s : %s', old_path, ME.message);
                end

            else
                try
                    movefile(old_path, new_path);
                catch ME
                    warning('        Impossible de renommer %s : %s', old_path, ME.message);
                end
            end
        end
    end
end


function vstr = get_next_version_number_from_suite2p(selected_groups)

    maxV = 0;

    type_names = fieldnames(selected_groups);

    for t = 1:numel(type_names)

        current_type = type_names{t};

        for k = 1:numel(selected_groups.(current_type))

            if ~isfield(selected_groups.(current_type)(k), 'paths') || ...
               ~isfield(selected_groups.(current_type)(k).paths, 'suite2p') || ...
               isempty(selected_groups.(current_type)(k).paths.suite2p)
                continue;
            end

            suite2p_group = selected_groups.(current_type)(k).paths.suite2p;
            suite2p_group = force_4col(suite2p_group, size(suite2p_group,1));

            gcamp_folders = suite2p_group(:,1);

            for d = 1:numel(gcamp_folders)

                this_suite2p_path = gcamp_folders{d};

                while iscell(this_suite2p_path)
                    if isempty(this_suite2p_path)
                        this_suite2p_path = '';
                        break;
                    end
                    this_suite2p_path = this_suite2p_path{1};
                end
                
                if isempty(this_suite2p_path)
                    continue;
                end
                
                this_suite2p_path = char(string(this_suite2p_path));
                
                [~, last_name] = fileparts(this_suite2p_path);
                
                if startsWith(lower(last_name), 'plane')
                    this_suite2p_path = fileparts(this_suite2p_path);
                end
                
                proc_root = fullfile(this_suite2p_path, 'after processing');

                if ~isfolder(proc_root)
                    continue;
                end

                L = dir(proc_root);
                L = L([L.isdir]);

                for i = 1:numel(L)

                    folder_name = L(i).name;

                    tok = regexp(folder_name, '^v(\d+)_\d{2}_\d{2}_\d{2}$', ...
                        'tokens', 'once');

                    if ~isempty(tok)
                        maxV = max(maxV, str2double(tok{1}));
                    end
                end
            end
        end
    end

    vstr = num2str(maxV + 1);
end