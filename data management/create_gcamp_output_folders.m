function [selected_groups, gcamp_output_folders_all, gcamp_root_folders_all, daytime] = create_gcamp_output_folders(selected_groups)
% create_gcamp_output_folders
% Crée les dossiers de sortie gcamp POUR CHAQUE PLAN et ajoute :
%   - .daytime
%   - .gcamp_output_folders
%   - .gcamp_root_folders
%   - .gcamp_output_folders_all
%   - .gcamp_root_folders_all
%
% Structure attendue dans selected_groups :
%   .animal_group
%   .animal_path
%   .date_group_path   -> cell(N,1)
%   .suite2p_path      -> cell(N,4)
%
% Sortie :
%   selected_groups(k).gcamp_output_folders{m}{p}
%       m = index acquisition/date
%       p = index plan

    if isempty(selected_groups)
        gcamp_output_folders_all = {};
        gcamp_root_folders_all = {};
        daytime = '';
        return;
    end

    currentDatetime = datetime('now');
    daytime = datestr(currentDatetime, 'yy_mm_dd_HH_MM');

    processing_choice1 = input('Do you want to process the most recent folder for processing (1/2)? ', 's');
    if strcmp(processing_choice1, '2')
        processing_choice2 = input('Do you want to select an existing folder or create a new one? (1/2): ', 's');
    else
        processing_choice2 = [];
    end

    [selected_groups.daytime] = deal(daytime);

    nGroups = numel(selected_groups);
    gcamp_output_folders_all = cell(nGroups, 1);
    gcamp_root_folders_all   = cell(nGroups, 1);

    for k = 1:nGroups

        current_animal_group = '';
        if isfield(selected_groups(k), 'animal_group') && ~isempty(selected_groups(k).animal_group)
            current_animal_group = selected_groups(k).animal_group;
        end

        %===================%
        %   Chemins par date
        %===================%
        if isfield(selected_groups(k), 'date_group_path') && ~isempty(selected_groups(k).date_group_path)
            date_group_paths = selected_groups(k).date_group_path;
        else
            date_group_paths = {};
        end

        if isrow(date_group_paths)
            date_group_paths = date_group_paths(:);
        end

        nDates = numel(date_group_paths);

        %===================%
        %   Suite2p paths (Nx4)
        %===================%
        if isfield(selected_groups(k), 'suite2p_path') && ~isempty(selected_groups(k).suite2p_path)
            current_suite2p_group = selected_groups(k).suite2p_path;
        else
            current_suite2p_group = cell(nDates, 4);
        end

        current_suite2p_group = force_4col(current_suite2p_group, nDates);

        % Colonne 1 = GCaMP
        current_gcamp_folders_group = current_suite2p_group(:, 1);

        %===================%
        %   Création / choix des dossiers par plan
        %===================%
        [gcamp_root_folders, gcamp_output_folders] = create_base_folders( ...
            date_group_paths, ...
            current_gcamp_folders_group, ...
            daytime, ...
            processing_choice1, ...
            processing_choice2, ...
            current_animal_group);

        %===================%
        %   Sauvegarde dans selected_groups
        %===================%
        selected_groups(k).gcamp_root_folders = gcamp_root_folders;
        selected_groups(k).gcamp_output_folders = gcamp_output_folders;

        % demandé explicitement : ajouter aussi les *_all dans selected_groups
        selected_groups(k).gcamp_root_folders_all = gcamp_root_folders;
        selected_groups(k).gcamp_output_folders_all = gcamp_output_folders;

        gcamp_root_folders_all{k} = gcamp_root_folders;
        gcamp_output_folders_all{k} = gcamp_output_folders;

        %======================================================
        % Nettoyage optionnel
        %======================================================
        numFolders = numel(gcamp_root_folders);

        for m = 1:numFolders
            currentFolder = gcamp_root_folders{m};

            files = dir(currentFolder);

            for i = 1:length(files)
                if files(i).isdir
                    continue;
                end

                filename = files(i).name;

                if ~strcmp(filename, 'results_movie.mat') && ...
                   ~strcmp(filename, 'metadata_results.xlsx')

                    delete(fullfile(currentFolder, filename));
                end
            end
        end
    end
end


function C4 = force_4col(C, nRowsWanted)
% force une cell array à avoir 4 colonnes
% et éventuellement nRowsWanted lignes

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