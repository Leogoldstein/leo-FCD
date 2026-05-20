function [selected_root_folder, chosen_folder_processing_gcamp] = create_base_folders( ...
    date_group_paths, current_gcamp_folders_group, daytime, user_choice1, user_choice2, current_animal_group)

    numFolders = numel(date_group_paths);
    chosen_folder_processing_gcamp = cell(numFolders, 1);
    selected_root_folder = cell(numFolders, 1);

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

    for m = 1:numFolders

        plane_names = all_plane_names{m};
        tseries_root = all_tseries_roots{m};
        existing_subfolders = all_existing_subfolders{m};

        recover_processing = false;
        source_root_folder = '';

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

        if isempty(existing_subfolders)

            current_root_folder = fullfile(after_processing_root, daytime);
            if ~isfolder(current_root_folder)
                mkdir(current_root_folder);
            end
            fprintf('No subfolder found. Created new gcamp root folder: %s\n', current_root_folder);

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

            elseif ~isempty(user_choice2) && strcmpi(user_choice2, '2')

                % Crée un nouveau dossier timestamp
                current_root_folder = fullfile(after_processing_root, daytime);
                if ~isfolder(current_root_folder)
                    mkdir(current_root_folder);
                end
                fprintf('Created new gcamp root folder: %s\n', current_root_folder);

                % Demande récupération ou processing complet
                disp('Nouveau dossier créé.');
                disp('1 = Refaire tout le processing depuis les données brutes');
                disp('2 = Récupérer les anciens fichiers results depuis le processing le plus récent');

                processing_choice = input('Votre choix : ', 's');

                if strcmpi(processing_choice, '1')
                    recover_processing = false;

                elseif strcmpi(processing_choice, '2')
                    recover_processing = true;

                    dates_gcamp = datetime({existing_subfolders.name}, ...
                        'InputFormat', 'yy_MM_dd_HH_mm', ...
                        'Format', 'yy_MM_dd_HH_mm');

                    [~, idx_gcamp] = sort(dates_gcamp, 'descend');
                    most_recent_gcamp = existing_subfolders(idx_gcamp(1));

                    source_root_folder = fullfile(after_processing_root, most_recent_gcamp.name);

                    fprintf('Recovering processing from: %s\n', source_root_folder);

                else
                    error('Invalid processing_choice.');
                end

            else
                error('Invalid user_choice2.');
            end

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

        chosen_folder_processing_gcamp{m} = cell(numel(plane_names), 1);

        for p = 1:numel(plane_names)

            plane_output_folder = fullfile(current_root_folder, plane_names{p});
        
            if ~isfolder(plane_output_folder)
                mkdir(plane_output_folder);
            end
        
            chosen_folder_processing_gcamp{m}{p} = plane_output_folder;
        
            if recover_processing
        
                files_to_copy = { ...
                    'results_gcamp.mat', ...
                    'results_blue.mat', ...
                    'results_combined.mat', ...
                    'results_movie.mat' ...
                };
        
                for f = 1:numel(files_to_copy)
        
                    source_file = fullfile(source_root_folder, files_to_copy{f});
                    dest_file   = fullfile(current_root_folder, files_to_copy{f});
        
                    if isfile(source_file)
                        copyfile(source_file, dest_file);
                        fprintf('Copied %s -> %s\n', source_file, dest_file);
                    else
                        warning('File not found, not copied: %s', source_file);
                    end
                end
            end
        end
        
        if recover_processing
            clear_detection_outputs(chosen_folder_processing_gcamp(m), {'gcamp','blue','combined'});
        end
    end
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function tseries_root = get_tseries_root_from_plane(plane_path)

    if isempty(plane_path)
        tseries_root = '';
        return;
    end

    plane_path = char(plane_path);

    [parent1, ~] = fileparts(plane_path);
    [parent2, name2] = fileparts(parent1);

    if strcmpi(name2, 'suite2p')
        tseries_root = parent2;
    else
        tseries_root = parent1;
    end
end

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

function clear_detection_outputs(gcamp_output_folders, branches_to_clear)

    if nargin < 2 || isempty(branches_to_clear)
        branches_to_clear = {'gcamp','blue','combined'};
    end

    fields_detect_gcamp = { ...
        'F0_gcamp_by_plane', 'noise_est_gcamp_by_plane', ...
        'valid_gcamp_cells_by_plane', 'DF_gcamp_by_plane', ...
        'Raster_gcamp_by_plane', 'Acttmp2_gcamp_by_plane', ...
        'StartEnd_gcamp_by_plane', 'MAct_gcamp_by_plane', ...
        'thresholds_gcamp_by_plane', 'bad_segs_gcamp_plane', ...
        'opts_detection_gcamp_by_plane', ...
        'isort1_gcamp_by_plane', 'isort2_gcamp_by_plane', 'Sm_gcamp_by_plane' ...
    };

    fields_detect_blue = { ...
        'F0_blue_by_plane', 'noise_est_blue_by_plane', 'SNR_blue_by_plane', ...
        'valid_blue_cells_by_plane', 'DF_blue_by_plane', ...
        'Raster_blue_by_plane', 'Acttmp2_blue_by_plane', ...
        'StartEnd_blue_by_plane', 'MAct_blue_by_plane', ...
        'thresholds_blue_by_plane', 'bad_segs_blue_plane', ...
        'opts_detection_blue_by_plane', ...
        'isort1_blue_by_plane', 'isort2_blue_by_plane', 'Sm_blue_by_plane' ...
    };

    fields_detect_combined = { ...
        'F0_combined_by_plane', 'noise_est_combined_by_plane', ...
        'valid_combined_cells_by_plane', 'DF_combined_by_plane', ...
        'Raster_combined_by_plane', 'Acttmp2_combined_by_plane', ...
        'StartEnd_combined_by_plane', 'MAct_combined_by_plane', ...
        'thresholds_combined_by_plane', 'bad_segs_combined_plane', ...
        'opts_detection_combined_by_plane', ...
        'isort1_combined_by_plane', 'isort2_combined_by_plane', 'Sm_combined_by_plane' ...
    };

    for m = 1:numel(gcamp_output_folders)

        if isempty(gcamp_output_folders{m}) || ~iscell(gcamp_output_folders{m}) || isempty(gcamp_output_folders{m}{1})
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