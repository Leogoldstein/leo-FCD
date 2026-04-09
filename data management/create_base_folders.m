function [selected_root_folder, chosen_folder_processing_gcamp] = create_base_folders( ...
    date_group_paths, current_gcamp_folders_group, daytime, user_choice1, user_choice2, current_animal_group)
% Retour :
%   chosen_folder_processing_gcamp{m}{p}
%       m = acquisition/date
%       p = plan
%
%   selected_root_folder{m}
%       dossier racine choisi pour l'acquisition m

    numFolders = numel(date_group_paths);
    chosen_folder_processing_gcamp = cell(numFolders, 1);
    selected_root_folder = cell(numFolders, 1);

    % -------------------------------------------------
    % 1) Recensement global des timestamps existants
    % -------------------------------------------------
    all_unique_subfolders = {};
    all_existing_subfolders = cell(numFolders, 1);
    all_tseries_roots = cell(numFolders, 1);
    all_plane_names = cell(numFolders, 1);

    empty_dir_struct = struct('name', {}, 'folder', {}, 'date', {}, ...
                              'bytes', {}, 'isdir', {}, 'datenum', {});

    for m = 1:numFolders

        if isempty(current_gcamp_folders_group) || ...
           m > numel(current_gcamp_folders_group) || ...
           isempty(current_gcamp_folders_group{m})
            gcamp_planes = {};
        else
            gcamp_planes = current_gcamp_folders_group{m};
        end

        if ischar(gcamp_planes) || isstring(gcamp_planes)
            gcamp_planes = {char(gcamp_planes)};
        end

        nPlanes = numel(gcamp_planes);
        plane_names = cell(nPlanes, 1);

        if nPlanes == 0
            all_existing_subfolders{m} = empty_dir_struct;
            all_tseries_roots{m} = '';
            all_plane_names{m} = {};
            chosen_folder_processing_gcamp{m} = {};
            selected_root_folder{m} = '';
            continue;
        end

        % TSeries root déduit à partir du 1er plan
        tseries_root = get_tseries_root_from_plane(gcamp_planes{1});
        all_tseries_roots{m} = tseries_root;

        for p = 1:nPlanes
            [~, plane_names{p}] = fileparts(gcamp_planes{p});
            if isempty(plane_names{p})
                plane_names{p} = sprintf('plane%d', p-1);
            end
        end
        all_plane_names{m} = plane_names;

        folder_gcamp = fullfile(tseries_root, 'after processing');

        if isfolder(folder_gcamp)
            subfolders_gcamp = dir(folder_gcamp);
            subfolders_gcamp = subfolders_gcamp([subfolders_gcamp.isdir]);
            subfolders_gcamp = subfolders_gcamp(~ismember({subfolders_gcamp.name}, {'.', '..'}));

            if isempty(subfolders_gcamp)
                specificSubfolders_gcamp = empty_dir_struct;
            else
                mask_ts = ~cellfun('isempty', regexp({subfolders_gcamp.name}, ...
                    '^\d{2}_\d{2}_\d{2}_\d{2}_\d{2}$', 'once'));
                specificSubfolders_gcamp = subfolders_gcamp(mask_ts);

                if isempty(specificSubfolders_gcamp)
                    specificSubfolders_gcamp = empty_dir_struct;
                end
            end
        else
            specificSubfolders_gcamp = empty_dir_struct;
        end

        all_existing_subfolders{m} = specificSubfolders_gcamp;

        if ~isempty(specificSubfolders_gcamp)
            all_unique_subfolders = [all_unique_subfolders, {specificSubfolders_gcamp.name}]; %#ok<AGROW>
        end
    end

    unique_subfolders = unique(all_unique_subfolders);

    % -------------------------------------------------
    % 2) Choix/création du dossier racine par acquisition
    %    puis création d’un sous-dossier par plan
    % -------------------------------------------------
    for m = 1:numFolders

        plane_names = all_plane_names{m};
        tseries_root = all_tseries_roots{m};
        existing_subfolders = all_existing_subfolders{m};

        if isempty(plane_names)
            chosen_folder_processing_gcamp{m} = {};
            selected_root_folder{m} = '';
            continue;
        end

        after_processing_root = fullfile(tseries_root, 'after processing');
        if ~isfolder(after_processing_root)
            mkdir(after_processing_root);
        end

        current_root_folder = '';

        % Aucun sous-dossier timestamp existant -> créer daytime
        if isempty(existing_subfolders)
            current_root_folder = fullfile(after_processing_root, daytime);
            if ~isfolder(current_root_folder)
                mkdir(current_root_folder);
            end
            fprintf('No subfolder found. Created new gcamp root folder: %s\n', current_root_folder);

        % Choix manuel
        elseif ~isempty(user_choice1) && strcmpi(user_choice1, '2')

            if ~isempty(user_choice2) && strcmpi(user_choice2, '1')
                disp(['Available subfolders for ', current_animal_group, ':']);
                for j = 1:length(unique_subfolders)
                    fprintf('Subfolder %d: %s\n', j, unique_subfolders{j});
                end

                selectedIndex = input('Enter the number corresponding to your choice: ');

                if selectedIndex < 1 || selectedIndex > length(unique_subfolders)
                    error('Invalid choice.');
                end

                selected_subfolder_name = unique_subfolders{selectedIndex};
                current_root_folder = fullfile(after_processing_root, selected_subfolder_name);

                if ~isfolder(current_root_folder)
                    mkdir(current_root_folder);
                end

            elseif strcmpi(user_choice2, '2')
                current_root_folder = fullfile(after_processing_root, daytime);
                if ~isfolder(current_root_folder)
                    mkdir(current_root_folder);
                end
                fprintf('Created new gcamp root folder: %s\n', current_root_folder);
            else
                error('Invalid user_choice2.');
            end

        % Choix automatique du plus récent
        elseif strcmpi(user_choice1, '1')
            dates_gcamp = datetime({existing_subfolders.name}, ...
                'InputFormat', 'yy_MM_dd_HH_mm', ...
                'Format', 'yy_MM_dd_HH_mm');

            [~, idx_gcamp] = sort(dates_gcamp, 'descend');
            most_recent_gcamp = existing_subfolders(idx_gcamp(1));
            current_root_folder = fullfile(after_processing_root, most_recent_gcamp.name);

        else
            error('Invalid user_choice1.');
        end

        selected_root_folder{m} = current_root_folder;

        % --- créer/sélectionner les sous-dossiers par plan ---
        chosen_folder_processing_gcamp{m} = cell(numel(plane_names), 1);

        for p = 1:numel(plane_names)
            plane_output_folder = fullfile(current_root_folder, plane_names{p});

            if ~isfolder(plane_output_folder)
                mkdir(plane_output_folder);
            end

            chosen_folder_processing_gcamp{m}{p} = plane_output_folder;
        end
    end
end

function tseries_root = get_tseries_root_from_plane(plane_path)
% Exemple :
%   ...\TSeries-xxxx\suite2p\plane0
% retourne :
%   ...\TSeries-xxxx

    if isempty(plane_path)
        tseries_root = '';
        return;
    end

    plane_path = char(plane_path);

    [parent1, ~] = fileparts(plane_path);   % -> ...\suite2p
    [parent2, name2] = fileparts(parent1);  % -> ...\TSeries-xxxx / name2='suite2p'

    if strcmpi(name2, 'suite2p')
        tseries_root = parent2;
    else
        tseries_root = parent1;
    end
end