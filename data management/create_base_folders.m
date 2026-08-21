function [selected_root_folder, chosen_folder_processing_gcamp] = ...
    create_base_folders( ...
        date_group_paths, ...
        current_gcamp_folders_group, ...
        daytime, ...
        user_choice1, ...
        user_choice2, ...
        processing_choice, ...
        delete_choice, ...
        current_animal_group)

    %==========================================================
    % Initialisation
    %==========================================================
    numFolders = numel(date_group_paths);

    chosen_folder_processing_gcamp = cell(numFolders, 1);
    selected_root_folder = cell(numFolders, 1);

    all_unique_subfolders = {};
    all_existing_subfolders = cell(numFolders, 1);
    all_tseries_roots = cell(numFolders, 1);
    all_plane_names = cell(numFolders, 1);

    empty_dir_struct = struct( ...
        'name', {}, ...
        'folder', {}, ...
        'date', {}, ...
        'bytes', {}, ...
        'isdir', {}, ...
        'datenum', {});

    fprintf('\n[create_base_folders]\n');

    %==========================================================
    % Première passe :
    % rechercher les versions existantes pour chaque date
    %==========================================================
    for m = 1:numFolders

        fprintf('\nDate %d / %d\n', m, numFolders);

        %------------------------------------------------------
        % Récupération des chemins des plans Suite2p
        %------------------------------------------------------
        if isempty(current_gcamp_folders_group) || ...
           m > numel(current_gcamp_folders_group) || ...
           isempty(current_gcamp_folders_group{m})

            gcamp_planes = {};

            fprintf( ...
                '  Aucun chemin gcamp/suite2p trouvé.\n');

        else
            gcamp_planes = ...
                current_gcamp_folders_group{m};

            while iscell(gcamp_planes) && ...
                  numel(gcamp_planes) == 1

                gcamp_planes = gcamp_planes{1};
            end
        end

        if ischar(gcamp_planes) || isstring(gcamp_planes)
            gcamp_planes = {char(gcamp_planes)};
        end

        nPlanes = numel(gcamp_planes);
        plane_names = cell(nPlanes, 1);

        fprintf('  Nombre de plans : %d\n', nPlanes);

        %------------------------------------------------------
        % Aucun plan disponible
        %------------------------------------------------------
        if nPlanes == 0

            all_existing_subfolders{m} = empty_dir_struct;
            all_tseries_roots{m} = '';
            all_plane_names{m} = {};

            chosen_folder_processing_gcamp{m} = {};
            selected_root_folder{m} = '';

            continue;
        end

        %------------------------------------------------------
        % Racine TSeries
        %------------------------------------------------------
        tseries_root = ...
            get_tseries_root_from_plane(gcamp_planes{1});

        all_tseries_roots{m} = tseries_root;

        fprintf('  TSeries root : %s\n', tseries_root);

        %------------------------------------------------------
        % Noms des plans
        %------------------------------------------------------
        for p = 1:nPlanes

            [~, plane_names{p}] = ...
                fileparts(gcamp_planes{p});

            if isempty(plane_names{p})
                plane_names{p} = ...
                    sprintf('plane%d', p - 1);
            end

            fprintf( ...
                '    Plan %d : %s\n', ...
                p, ...
                plane_names{p});
        end

        all_plane_names{m} = plane_names;

        %------------------------------------------------------
        % Dossier after processing
        %------------------------------------------------------
        folder_gcamp = fullfile( ...
            tseries_root, ...
            'after processing');

        fprintf( ...
            '  after processing : %s\n', ...
            folder_gcamp);

        %------------------------------------------------------
        % Recherche des dossiers de version
        %------------------------------------------------------
        if isfolder(folder_gcamp)

            subfolders_gcamp = dir(folder_gcamp);

            subfolders_gcamp = ...
                subfolders_gcamp([subfolders_gcamp.isdir]);

            subfolders_gcamp = ...
                subfolders_gcamp( ...
                    ~ismember( ...
                        {subfolders_gcamp.name}, ...
                        {'.', '..'}));

            if isempty(subfolders_gcamp)

                specificSubfolders_gcamp = ...
                    empty_dir_struct;

                fprintf( ...
                    '  Aucun sous-dossier trouvé.\n');

            else
                mask_v = ~cellfun( ...
                    'isempty', ...
                    regexp( ...
                        {subfolders_gcamp.name}, ...
                        '^v\d+_\d{2}_\d{2}_\d{2}(_\d{2}_\d{2})?$', ...
                        'once'));

                specificSubfolders_gcamp = ...
                    subfolders_gcamp(mask_v);

                if isempty(specificSubfolders_gcamp)

                    specificSubfolders_gcamp = ...
                        empty_dir_struct;

                    fprintf( ...
                        '  Aucun sous-dossier vX_yy_mm_dd trouvé.\n');

                else
                    fprintf( ...
                        '  Sous-dossiers vX trouvés :\n');

                    for j = 1:numel(specificSubfolders_gcamp)

                        fprintf( ...
                            '    - %s\n', ...
                            specificSubfolders_gcamp(j).name);
                    end
                end
            end

        else
            specificSubfolders_gcamp = ...
                empty_dir_struct;

            fprintf( ...
                '  Aucun dossier after processing existant.\n');
        end

        all_existing_subfolders{m} = ...
            specificSubfolders_gcamp;

        if ~isempty(specificSubfolders_gcamp)

            all_unique_subfolders = [ ...
                all_unique_subfolders, ...
                {specificSubfolders_gcamp.name}]; %#ok<AGROW>
        end
    end

    unique_subfolders = unique(all_unique_subfolders);

    %==========================================================
    % Deuxième passe :
    % sélection ou création des dossiers
    %==========================================================
    for m = 1:numFolders

        plane_names = all_plane_names{m};
        tseries_root = all_tseries_roots{m};
        existing_subfolders = all_existing_subfolders{m};

        recover_processing = false;
        source_root_folder = '';

        %------------------------------------------------------
        % Aucun plan disponible
        %------------------------------------------------------
        if isempty(plane_names)

            chosen_folder_processing_gcamp{m} = {};
            selected_root_folder{m} = '';

            continue;
        end

        %------------------------------------------------------
        % Création éventuelle de after processing
        %------------------------------------------------------
        after_processing_root = fullfile( ...
            tseries_root, ...
            'after processing');

        if ~isfolder(after_processing_root)

            mkdir(after_processing_root);

            fprintf( ...
                '  Dossier after processing créé : %s\n', ...
                after_processing_root);
        end

        current_root_folder = '';

        fprintf( ...
            '\nSélection dossier processing date %d / %d\n', ...
            m, ...
            numFolders);

        %======================================================
        % CAS 1 : aucune ancienne version
        %======================================================
        if isempty(existing_subfolders)

            fprintf( ...
                '\nAucune ancienne version trouvée pour %s\n', ...
                current_animal_group);

            %--------------------------------------------------
            % Réutiliser automatiquement la version contenue
            % dans daytime
            %--------------------------------------------------
            daytime_parts = regexp( ...
                daytime, ...
                '^v(\d+)_(.*)$', ...
                'tokens', ...
                'once');

            if isempty(daytime_parts)

                error( ...
                    'Format inattendu pour daytime : %s', ...
                    daytime);
            end

            current_root_folder = fullfile( ...
                after_processing_root, ...
                daytime);

            if ~isfolder(current_root_folder)
                mkdir(current_root_folder);
            end

            fprintf( ...
                '  Nouveau dossier créé : %s\n', ...
                current_root_folder);

        %======================================================
        % CAS 2 : choix d'une ancienne version ou création
        %======================================================
        elseif strcmpi(user_choice1, '2')

            %--------------------------------------------------
            % Sélection d'une version existante
            %--------------------------------------------------
            if strcmpi(user_choice2, '1')

                fprintf( ...
                    '\nVersions disponibles pour %s :\n', ...
                    current_animal_group);

                versions_available = ...
                    get_versions_from_vfolders( ...
                        unique_subfolders);

                valid_idx = ...
                    ~isnan(versions_available);

                versions_available = ...
                    versions_available(valid_idx);

                unique_subfolders_valid = ...
                    unique_subfolders(valid_idx);

                [versions_available, sort_idx] = ...
                    sort(versions_available);

                unique_subfolders_valid = ...
                    unique_subfolders_valid(sort_idx);

                if isempty(unique_subfolders_valid)

                    error( ...
                        ['Aucune version valide disponible ' ...
                         'pour la sélection.']);
                end

                for j = 1:numel(versions_available)

                    fprintf( ...
                        '%d : version %d - %s\n', ...
                        j, ...
                        versions_available(j), ...
                        unique_subfolders_valid{j});
                end

                selectedIndex = input( ...
                    'Entrer le numéro correspondant à votre choix : ');

                if isempty(selectedIndex) || ...
                   ~isscalar(selectedIndex) || ...
                   selectedIndex < 1 || ...
                   selectedIndex > numel(unique_subfolders_valid) || ...
                   selectedIndex ~= floor(selectedIndex)

                    error('Choix invalide.');
                end

                selected_subfolder_name = ...
                    unique_subfolders_valid{selectedIndex};

                current_root_folder = fullfile( ...
                    after_processing_root, ...
                    selected_subfolder_name);

                if ~isfolder(current_root_folder)

                    mkdir(current_root_folder);

                    fprintf( ...
                        ['  Dossier sélectionné inexistant ' ...
                         'localement -> créé : %s\n'], ...
                        current_root_folder);

                else
                    fprintf( ...
                        '  Dossier sélectionné : %s\n', ...
                        current_root_folder);
                end

            %--------------------------------------------------
            % Création d'une nouvelle version
            %--------------------------------------------------
            elseif strcmpi(user_choice2, '2')

                %--------------------------------------------------
                % Création d'une nouvelle version :
                % version maximale existante + 1
                % en conservant la date/heure de daytime
                %--------------------------------------------------
                existing_names = {existing_subfolders.name};
                
                existing_versions = ...
                    get_versions_from_vfolders(existing_names);
                
                existing_versions = ...
                    existing_versions(~isnan(existing_versions));
                
                if isempty(existing_versions)
                    new_version = 1;
                else
                    new_version = max(existing_versions) + 1;
                end
                
                % Récupérer uniquement la partie date/heure de daytime
                % Exemple :
                % daytime = v1_26_08_08_15_13
                % devient :
                % date_part = 26_08_08_15_13
                daytime_parts = regexp( ...
                    daytime, ...
                    '^v\d+_(.*)$', ...
                    'tokens', ...
                    'once');
                
                if isempty(daytime_parts)
                    error( ...
                        'Format inattendu pour daytime : %s', ...
                        daytime);
                end
                
                date_part = daytime_parts{1};
                
                new_folder_name = sprintf( ...
                    'v%d_%s', ...
                    new_version, ...
                    date_part);
                
                current_root_folder = fullfile( ...
                    after_processing_root, ...
                    new_folder_name);
                
                if ~isfolder(current_root_folder)
                    mkdir(current_root_folder);
                end
                
                fprintf( ...
                    '  Nouvelle version créée : v%d -> %s\n', ...
                    new_version, ...
                    current_root_folder);

                if ~isfolder(current_root_folder)
                    mkdir(current_root_folder);
                end

                fprintf( ...
                    '  Nouveau dossier créé : %s\n', ...
                    current_root_folder);

                %----------------------------------------------
                % Le choix est transmis par
                % create_gcamp_output_folders
                %----------------------------------------------
                if strcmpi(processing_choice, '1')

                    recover_processing = false;

                    fprintf( ...
                        ['  Choix global : refaire tout le ' ...
                         'processing depuis les données brutes.\n']);

                elseif strcmpi(processing_choice, '2')

                    recover_processing = true;

                    most_recent_gcamp = ...
                        get_most_recent_vfolder( ...
                            existing_subfolders);

                    if isempty(most_recent_gcamp)

                        error( ...
                            ['Aucune version valide trouvée pour ' ...
                             'récupérer les anciens results.']);
                    end

                    source_root_folder = fullfile( ...
                        after_processing_root, ...
                        most_recent_gcamp.name);

                    fprintf( ...
                        ['  Récupération depuis le dossier ' ...
                         'le plus récent : %s\n'], ...
                        source_root_folder);

                else
                    error( ...
                        ['processing_choice doit être égal ' ...
                         'à ''1'' ou ''2''.']);
                end

            else
                error( ...
                    'user_choice2 doit être égal à ''1'' ou ''2''.');
            end

        %======================================================
        % CAS 3 : utiliser le dossier le plus récent
        %======================================================
        elseif strcmpi(user_choice1, '1')

            most_recent_gcamp = ...
                get_most_recent_vfolder( ...
                    existing_subfolders);

            if isempty(most_recent_gcamp)
                error('Aucune version valide trouvée.');
            end

            current_root_folder = fullfile( ...
                after_processing_root, ...
                most_recent_gcamp.name);

            fprintf( ...
                ['  Choix 1 -> dossier vX le plus récent ' ...
                 'sélectionné : %s\n'], ...
                current_root_folder);

        else
            error( ...
                'user_choice1 doit être égal à ''1'' ou ''2''.');
        end

        %======================================================
        % Enregistrement du dossier racine sélectionné
        %======================================================
        selected_root_folder{m} = ...
            current_root_folder;

        chosen_folder_processing_gcamp{m} = ...
            cell(numel(plane_names), 1);

        %======================================================
        % Création des dossiers de plans
        %======================================================
        for p = 1:numel(plane_names)

            plane_output_folder = fullfile( ...
                current_root_folder, ...
                plane_names{p});

            if ~isfolder(plane_output_folder)

                mkdir(plane_output_folder);

                fprintf( ...
                    '    Dossier plan créé : %s\n', ...
                    plane_output_folder);

            else
                fprintf( ...
                    '    Dossier plan existant : %s\n', ...
                    plane_output_folder);
            end

            chosen_folder_processing_gcamp{m}{p} = ...
                plane_output_folder;
        end

        %======================================================
        % Récupération des anciens fichiers results
        %======================================================
        if recover_processing
        % 
        %     files_to_copy = { ...
        %         'results_gcamp.mat', ...
        %         'results_blue.mat', ...
        %         'results_combined.mat', ...
        %         'metadata_results.xlsx'};
        % 
        %     for f = 1:numel(files_to_copy)
        % 
        %         source_file = fullfile( ...
        %             source_root_folder, ...
        %             files_to_copy{f});
        % 
        %         dest_file = fullfile( ...
        %             current_root_folder, ...
        %             files_to_copy{f});
        % 
        %         if isfile(source_file)
        % 
        %             copyfile(source_file, dest_file);
        % 
        %             fprintf( ...
        %                 '  Copié : %s -> %s\n', ...
        %                 source_file, ...
        %                 dest_file);
        % 
        %         else
        %             warning( ...
        %                 'Fichier absent, non copié : %s', ...
        %                 source_file);
        %         end
        %     end
        
            %--------------------------------------------------
            % Fichier motion ou ancien fichier movie
            %--------------------------------------------------
            source_motion = fullfile( ...
                source_root_folder, ...
                'results_motion.mat');
        
            source_movie = fullfile( ...
                source_root_folder, ...
                'results_movie.mat');
        
            dest_motion = fullfile( ...
                current_root_folder, ...
                'results_motion.mat');
        
            if isfile(source_motion)
        
                copyfile(source_motion, dest_motion);
        
                fprintf( ...
                    '  Copié : %s -> %s\n', ...
                    source_motion, ...
                    dest_motion);
        
            elseif isfile(source_movie)
        
                copyfile(source_movie, dest_motion);
        
                fprintf( ...
                    '  Copié : %s -> %s (renommé)\n', ...
                    source_movie, ...
                    dest_motion);
        
            else
                warning( ...
                    ['Aucun fichier motion trouvé ' ...
                     '(results_motion.mat ou results_movie.mat)']);
            end
        
            %--------------------------------------------------
            % Copier tous les recording_summary*
            %--------------------------------------------------
            summary_files = dir( ...
                fullfile( ...
                    source_root_folder, ...
                    'recording_summary*'));
        
            for s = 1:numel(summary_files)
        
                if summary_files(s).isdir
                    continue;
                end
        
                source_summary = fullfile( ...
                    source_root_folder, ...
                    summary_files(s).name);
        
                dest_summary = fullfile( ...
                    current_root_folder, ...
                    summary_files(s).name);
        
                copyfile(source_summary, dest_summary);
        
                fprintf( ...
                    '  Copié : %s -> %s\n', ...
                    source_summary, ...
                    dest_summary);
            end
        
            if isempty(summary_files)
        
                warning( ...
                    ['Aucun fichier recording_summary* ' ...
                     'trouvé dans : %s'], ...
                    source_root_folder);
            end
        
            %--------------------------------------------------
            % Copier uniquement les .tif et .npy des dossiers plane*
            %--------------------------------------------------
            source_plane_folders = dir( ...
                fullfile(source_root_folder, 'plane*'));
        
            source_plane_folders = source_plane_folders( ...
                [source_plane_folders.isdir]);
        
            for pFolder = 1:numel(source_plane_folders)
        
                plane_folder_name = ...
                    source_plane_folders(pFolder).name;
        
                source_plane_folder = fullfile( ...
                    source_root_folder, ...
                    plane_folder_name);
        
                destination_plane_folder = fullfile( ...
                    current_root_folder, ...
                    plane_folder_name);
        
                if ~isfolder(destination_plane_folder)
        
                    mkdir(destination_plane_folder);
        
                    fprintf( ...
                        ['  Dossier plan créé pour la ' ...
                         'récupération : %s\n'], ...
                        destination_plane_folder);
                end
        
                plane_files = [ ...
                    dir(fullfile(source_plane_folder, '*.tif')); ...
                    dir(fullfile(source_plane_folder, '*.npy'))];
        
                if isempty(plane_files)
        
                    fprintf( ...
                        ['  Aucun fichier .tif ou .npy ' ...
                         'trouvé dans : %s\n'], ...
                        source_plane_folder);
        
                    continue;
                end
        
                for fileIdx = 1:numel(plane_files)
        
                    source_plane_file = fullfile( ...
                        source_plane_folder, ...
                        plane_files(fileIdx).name);
        
                    destination_plane_file = fullfile( ...
                        destination_plane_folder, ...
                        plane_files(fileIdx).name);
        
                    copyfile( ...
                        source_plane_file, ...
                        destination_plane_file);
        
                    fprintf( ...
                        '  Copié : %s -> %s\n', ...
                        source_plane_file, ...
                        destination_plane_file);
                end
            end
        
            clear_detection_outputs( ...
                chosen_folder_processing_gcamp(m), ...
                {'gcamp', 'blue', 'combined'});
        end

        %======================================================
        % Suppression des anciennes versions
        % Le choix est transmis par create_gcamp_output_folders
        %======================================================
        if strcmpi(user_choice1, '2') && ...
           strcmpi(user_choice2, '2')

            fprintf('\nAnciennes versions trouvées :\n');

            folders_to_delete = {};

            for j = 1:numel(existing_subfolders)

                old_folder = fullfile( ...
                    after_processing_root, ...
                    existing_subfolders(j).name);

                if ~strcmpi( ...
                        remove_trailing_filesep_local(old_folder), ...
                        remove_trailing_filesep_local( ...
                            current_root_folder))

                    fprintf('  %s\n', old_folder);

                    folders_to_delete{end + 1} = ...
                        old_folder; %#ok<AGROW>
                end
            end

            if isempty(folders_to_delete)

                fprintf( ...
                    '  Aucune ancienne version à supprimer.\n');

            elseif strcmpi(delete_choice, 'y')

                for j = 1:numel(folders_to_delete)

                    try
                        rmdir(folders_to_delete{j}, 's');

                        fprintf( ...
                            '  Supprimé : %s\n', ...
                            folders_to_delete{j});

                    catch ME
                        warning( ...
                            'Impossible de supprimer %s : %s', ...
                            folders_to_delete{j}, ...
                            ME.message);
                    end
                end

            elseif strcmpi(delete_choice, 'n')

                fprintf( ...
                    '  Conservation des anciennes versions.\n');

            else
                error( ...
                    'delete_choice doit être égal à ''y'' ou ''n''.');
            end
        end
    end

    fprintf('\n[create_base_folders] Terminé.\n');
end


%==============================================================
% Fonction locale :
% normalise un chemin pour permettre une comparaison fiable
%==============================================================
function path_out = remove_trailing_filesep_local(path_in)

    if isempty(path_in)
        path_out = '';
        return;
    end

    path_out = char(path_in);

    while numel(path_out) > 1 && ...
          (path_out(end) == filesep || ...
           path_out(end) == '/' || ...
           path_out(end) == '\')

        path_out(end) = [];
    end
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

function tseries_root = get_tseries_root_from_plane(plane_path)

    if isempty(plane_path)
        tseries_root = '';
        return;
    end

    while iscell(plane_path) && numel(plane_path) == 1
        plane_path = plane_path{1};
    end

    plane_path = char(string(plane_path));

    [parent1, name1] = fileparts(plane_path);
    [parent2, name2] = fileparts(parent1);

    if strcmpi(name1, 'suite2p') || strcmpi(name1, 'suite2p_new')
        tseries_root = plane_path;

    elseif strcmpi(name2, 'suite2p') || strcmpi(name2, 'suite2p_new')
        tseries_root = parent1;

    else
        tseries_root = parent1;
    end
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

function versions = get_versions_from_vfolders(folder_names)

    versions = nan(numel(folder_names), 1);

    for i = 1:numel(folder_names)

        tok = regexp(folder_names{i}, ...
            '^v(\d+)_\d{2}_\d{2}_\d{2}(_\d{2}_\d{2})?$', ...
            'tokens', 'once');

        if ~isempty(tok)
            versions(i) = str2double(tok{1});
        end
    end
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

function most_recent_folder = get_most_recent_vfolder(folders)
% Sélectionne le dossier de processing le plus récent.
%
% Priorité de tri :
%   1) numéro de version vX le plus élevé ;
%   2) à version égale, date et heure inscrites dans le nom ;
%   3) si le nom ne contient pas l'heure, 00:00 est utilisé.
%
% Formats acceptés :
%   v1_25_10_11
%   v1_26_06_29_10_37

    most_recent_folder = [];

    if isempty(folders)
        return;
    end

    nFolders = numel(folders);

    version_numbers = nan(nFolders, 1);
    folder_dates = NaT(nFolders, 1);

    for i = 1:nFolders

        folder_name = folders(i).name;

        tokens = regexp( ...
            folder_name, ...
            '^v(\d+)_(\d{2})_(\d{2})_(\d{2})(?:_(\d{2})_(\d{2}))?$', ...
            'tokens', ...
            'once');

        if isempty(tokens)
            continue;
        end

        version_value = str2double(tokens{1});
        year_value    = 2000 + str2double(tokens{2});
        month_value   = str2double(tokens{3});
        day_value     = str2double(tokens{4});

        hour_value = 0;
        minute_value = 0;

        if numel(tokens) >= 6 && ...
                ~isempty(tokens{5}) && ...
                ~isempty(tokens{6})

            hour_value = str2double(tokens{5});
            minute_value = str2double(tokens{6});
        end

        try
            this_date = datetime( ...
                year_value, ...
                month_value, ...
                day_value, ...
                hour_value, ...
                minute_value, ...
                0);

            version_numbers(i) = version_value;
            folder_dates(i) = this_date;

        catch
            version_numbers(i) = NaN;
            folder_dates(i) = NaT;
        end
    end

    valid_idx = ...
        ~isnan(version_numbers) & ...
        ~isnat(folder_dates);

    if ~any(valid_idx)
        return;
    end

    valid_original_indices = find(valid_idx);

    sorting_table = table( ...
        version_numbers(valid_idx), ...
        folder_dates(valid_idx), ...
        valid_original_indices, ...
        'VariableNames', { ...
            'Version', ...
            'FolderDate', ...
            'OriginalIndex'});

    sorting_table = sortrows( ...
        sorting_table, ...
        {'Version', 'FolderDate'}, ...
        {'descend', 'descend'});

    selected_idx = sorting_table.OriginalIndex(1);
    most_recent_folder = folders(selected_idx);

    fprintf('  Dossiers vX valides, du plus récent au plus ancien :\n');

    for i = 1:height(sorting_table)

        idx = sorting_table.OriginalIndex(i);

        fprintf( ...
            '    - %s | version %d | %s\n', ...
            folders(idx).name, ...
            sorting_table.Version(i), ...
            char(string(sorting_table.FolderDate(i), ...
                'yyyy-MM-dd HH:mm')));
    end

    fprintf( ...
        '  Dossier le plus récent retenu : %s\n', ...
        most_recent_folder.name);
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

function clear_vars_in_matfile(filePath, vars_to_remove)

    if exist(filePath, 'file') ~= 2
        fprintf('Fichier absent, skip: %s\n', filePath);
        return;
    end

    S = load(filePath);
    removed_any = false;

    for k = 1:numel(vars_to_remove)
        fn = vars_to_remove{k};

        if isfield(S, fn)
            S = rmfield(S, fn);
            removed_any = true;
        end
    end

    if removed_any
        save(filePath, '-struct', 'S');
        fprintf('Champs supprimés de %s\n', filePath);
    else
        fprintf('Aucun champ à supprimer dans %s\n', filePath);
    end
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

function clear_detection_outputs(gcamp_output_folders, branches_to_clear)

    if nargin < 2 || isempty(branches_to_clear)
        branches_to_clear = {'gcamp','blue','combined'};
    end

    fields_detect_gcamp = { ...
        'F0_gcamp_by_plane', ...
        'noise_est_gcamp_by_plane', ...
        'valid_gcamp_cells_by_plane', ...
        'DF_gcamp_by_plane', ...
        'DF_raw_gcamp_by_plane', ...
        'drift_score_gcamp_by_plane', ...
        'Raster_gcamp_by_plane', ...
        'Acttmp2_gcamp_by_plane', ...
        'MAct_gcamp_by_plane', ...
        'thresholds_gcamp_by_plane', ...
        'bad_segs_gcamp_plane', ...
        'opts_detection_gcamp_by_plane', ...
        'isort1_gcamp_by_plane', ...
        'isort2_gcamp_by_plane', ...
        'Sm_gcamp_by_plane' ...
    };

    fields_detect_blue = { ...
        'F0_blue_by_plane', ...
        'noise_est_blue_by_plane', ...
        'valid_blue_cells_by_plane', ...
        'DF_blue_by_plane', ...
        'DF_raw_blue_by_plane', ...
        'drift_score_blue_by_plane', ...
        'Raster_blue_by_plane', ...
        'Acttmp2_blue_by_plane', ...
        'MAct_blue_by_plane', ...
        'thresholds_blue_by_plane', ...
        'bad_segs_blue_plane', ...
        'opts_detection_blue_by_plane', ...
        'isort1_blue_by_plane', ...
        'isort2_blue_by_plane', ...
        'Sm_blue_by_plane' ...
    };

    fields_detect_combined = { ...
        'F0_combined_by_plane', ...
        'noise_est_combined_by_plane', ...
        'valid_combined_cells_by_plane', ...
        'DF_combined_by_plane', ...
        'DF_raw_combined_by_plane', ...
        'drift_score_combined_by_plane', ...
        'Raster_combined_by_plane', ...
        'Acttmp2_combined_by_plane', ...
        'MAct_combined_by_plane', ...
        'thresholds_combined_by_plane', ...
        'bad_segs_combined_plane', ...
        'opts_detection_combined_by_plane', ...
        'isort1_combined_by_plane', ...
        'isort2_combined_by_plane', ...
        'Sm_combined_by_plane' ...
    };

    for m = 1:numel(gcamp_output_folders)

        if isempty(gcamp_output_folders{m}) || ...
           ~iscell(gcamp_output_folders{m}) || ...
           isempty(gcamp_output_folders{m}{1})
            continue;
        end

        outdir_m = fileparts(gcamp_output_folders{m}{1});

        if ismember('gcamp', branches_to_clear)
            filePath = fullfile(outdir_m, 'results_gcamp.mat');
            clear_vars_in_matfile(filePath, fields_detect_gcamp);
        end

        if ismember('blue', branches_to_clear)
            filePath = fullfile(outdir_m, 'results_blue.mat');
            clear_vars_in_matfile(filePath, fields_detect_blue);
        end

        if ismember('combined', branches_to_clear)
            filePath = fullfile(outdir_m, 'results_combined.mat');
            clear_vars_in_matfile(filePath, fields_detect_combined);
        end
    end
end
