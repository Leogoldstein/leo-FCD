function [selected_groups, gcamp_output_folders_all, gcamp_root_folders_all, daytime] = build_selected_groups(selected_groups)
% build_selected_groups
% Fusion de :
%   - create_gcamp_output_folders
%   - fill_selected_group
%
% Cette fonction :
%   1) crée/choisit les dossiers de sortie par acquisition et par plan
%   2) remplit selected_groups avec les champs normalisés utiles au pipeline
%
% Sorties :
%   selected_groups(k).gcamp_output_folders{m}{p}
%       m = index acquisition/date
%       p = index plan
%
% Champs ajoutés / normalisés dans selected_groups(k) :
%   - daytime
%   - data
%   - date_group_paths
%   - pathTSeries          (4 colonnes)
%   - Fallmat_paths        (4 colonnes)
%   - suite2p_folder       (4 colonnes)
%   - gcamp_output_folders
%   - gcamp_root_folders
%   - gcamp_TSeries_path / red_TSeries_path / blue_TSeries_path / green_TSeries_path
%   - gcamp_fallmat_group / red_fallmat_group / blue_fallmat_group / green_fallmat_group
%   - gcamp_folders_group / red_folders_group / blue_folders_group / green_folders_group

    if isempty(selected_groups)
        gcamp_output_folders_all = {};
        gcamp_root_folders_all = {};
        daytime = '';
        return;
    end

    nGroups = numel(selected_groups);

    % -------------------------------------------------
    % daytime
    % -------------------------------------------------
    if isfield(selected_groups, 'daytime') && ...
       ~isempty(selected_groups(1).daytime)
        daytime = selected_groups(1).daytime;
    else
        daytime = datestr(datetime('now'), 'yy_mm_dd_HH_MM');
    end

    % -------------------------------------------------
    % Choix utilisateur pour les dossiers de sortie
    % -------------------------------------------------
    processing_choice1 = input( ...
        'Do you want to process the most recent folder for processing (1/2)? ', 's');

    if strcmp(processing_choice1, '2')
        processing_choice2 = input( ...
            'Do you want to select an existing folder or create a new one? (1/2): ', 's');
    else
        processing_choice2 = [];
    end

    % -------------------------------------------------
    % Initialisation sorties
    % -------------------------------------------------
    [selected_groups.daytime] = deal(daytime);
    gcamp_output_folders_all = cell(nGroups, 1);
    gcamp_root_folders_all   = cell(nGroups, 1);

    % -------------------------------------------------
    % Boucle groupes
    % -------------------------------------------------
    for k = 1:nGroups

        % =============================================
        % Champs minimaux obligatoires
        % =============================================
        requiredFields = { ...
            'animal_group', ...
            'animal_type', ...
            'animal_path', ...
            'dates', ...
            'ages', ...
            'pathTSeries', ...
            'xml' ...
        };

        for i = 1:numel(requiredFields)
            if ~isfield(selected_groups(k), requiredFields{i})
                error('Champ manquant dans selected_groups(%d): %s', ...
                    k, requiredFields{i});
            end
        end

        % =============================================
        % daytime
        % =============================================
        selected_groups(k).daytime = daytime;

        % =============================================
        % data
        % =============================================
        if ~isfield(selected_groups(k), 'data') || isempty(selected_groups(k).data)
            selected_groups(k).data = struct();
        end

        % =============================================
        % date_group_paths
        % =============================================
        nDates = numel(selected_groups(k).dates);
        selected_groups(k).date_group_paths = cell(nDates, 1);

        for m = 1:nDates
            selected_groups(k).date_group_paths{m} = fullfile( ...
                selected_groups(k).animal_path, ...
                selected_groups(k).dates{m});
        end

        % =============================================
        % pathTSeries -> 4 colonnes
        % [gcamp red blue green]
        % =============================================
        selected_groups(k).pathTSeries = ensure_four_columns( ...
            selected_groups(k).pathTSeries);

        % =============================================
        % Fallmat_paths -> 4 colonnes
        % =============================================
        if ~isfield(selected_groups(k), 'Fallmat_paths') || isempty(selected_groups(k).Fallmat_paths)
            selected_groups(k).Fallmat_paths = cell(size(selected_groups(k).pathTSeries));
        end

        selected_groups(k).Fallmat_paths = ensure_four_columns( ...
            selected_groups(k).Fallmat_paths);

        % =============================================
        % suite2p_folder -> 4 colonnes
        % =============================================
        if ~isfield(selected_groups(k), 'suite2p_folder') || isempty(selected_groups(k).suite2p_folder)
            selected_groups(k).suite2p_folder = cell(size(selected_groups(k).pathTSeries));
        end

        selected_groups(k).suite2p_folder = ensure_four_columns( ...
            selected_groups(k).suite2p_folder);

        % =============================================
        % Cas JM : pas de red/blue/green
        % =============================================
        if ischar(selected_groups(k).animal_type) || isstring(selected_groups(k).animal_type)
            if strcmpi(selected_groups(k).animal_type, 'jm')
                nRows = size(selected_groups(k).pathTSeries, 1);

                selected_groups(k).pathTSeries(:, 2:4)    = cell(nRows, 3);
                selected_groups(k).Fallmat_paths(:, 2:4)  = cell(nRows, 3);
                selected_groups(k).suite2p_folder(:, 2:4) = cell(nRows, 3);
            end
        end

        % =============================================
        % Création / choix des dossiers de sortie par plan
        % =============================================
        current_gcamp_folders_group = selected_groups(k).suite2p_folder(:, 1);

        [gcamp_root_folders, gcamp_output_folders] = create_base_folders( ...
            selected_groups(k).date_group_paths, ...
            current_gcamp_folders_group, ...
            daytime, ...
            processing_choice1, ...
            processing_choice2, ...
            selected_groups(k).animal_group);

        selected_groups(k).gcamp_output_folders = gcamp_output_folders;
        selected_groups(k).gcamp_root_folders   = gcamp_root_folders;

        gcamp_output_folders_all{k} = gcamp_output_folders;
        gcamp_root_folders_all{k}   = gcamp_root_folders;

        % =============================================
        % Vérifier gcamp_output_folders
        % =============================================
        if isempty(selected_groups(k).gcamp_output_folders)
            error(['gcamp_output_folders manquant pour le groupe %s. ' ...
                   'Échec lors de create_base_folders.'], ...
                   selected_groups(k).animal_group);
        end

        % =============================================
        % Alias utiles stockés dans la structure
        % =============================================
        selected_groups(k).gcamp_TSeries_path = selected_groups(k).pathTSeries(:, 1);
        selected_groups(k).red_TSeries_path   = selected_groups(k).pathTSeries(:, 2);
        selected_groups(k).blue_TSeries_path  = selected_groups(k).pathTSeries(:, 3);
        selected_groups(k).green_TSeries_path = selected_groups(k).pathTSeries(:, 4);

        selected_groups(k).gcamp_fallmat_group = selected_groups(k).Fallmat_paths(:, 1);
        selected_groups(k).red_fallmat_group   = selected_groups(k).Fallmat_paths(:, 2);
        selected_groups(k).blue_fallmat_group  = selected_groups(k).Fallmat_paths(:, 3);
        selected_groups(k).green_fallmat_group = selected_groups(k).Fallmat_paths(:, 4);

        selected_groups(k).gcamp_folders_group = selected_groups(k).suite2p_folder(:, 1);
        selected_groups(k).red_folders_group   = selected_groups(k).suite2p_folder(:, 2);
        selected_groups(k).blue_folders_group  = selected_groups(k).suite2p_folder(:, 3);
        selected_groups(k).green_folders_group = selected_groups(k).suite2p_folder(:, 4);

        % =============================================
        % Nettoyage optionnel des fichiers du dossier root
        % =============================================
        % Décommente si nécessaire
        %
        % numFolders = numel(gcamp_root_folders);
        % for m = 1:numFolders
        %     currentFolder = gcamp_root_folders{m};
        %     files = dir(currentFolder);
        %
        %     for i = 1:length(files)
        %         if files(i).isdir
        %             continue;
        %         end
        %
        %         filename = files(i).name;
        %
        %         if ~strcmp(filename, 'results_movie.mat') && ...
        %            ~strcmp(filename, 'results_gcamp.mat') && ...
        %            ~strcmp(filename, 'metadata_results.xlsx')
        %
        %             delete(fullfile(currentFolder, filename));
        %         end
        %     end
        % end
    end
end


function C = ensure_four_columns(C)

    if isempty(C)
        C = cell(0,4);
        return;
    end

    if ~iscell(C)
        error('Le contenu attendu doit être un cell array.');
    end

    if isvector(C)
        C = C(:);
    end

    if size(C,2) < 4
        tmp = cell(size(C,1), 4);
        tmp(:, 1:size(C,2)) = C;
        C = tmp;
    elseif size(C,2) > 4
        C = C(:,1:4);
    end
end