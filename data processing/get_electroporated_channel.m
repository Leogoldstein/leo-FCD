function [ ...
    current_electroporated_TSeries_path, ...
    current_electroporated_folders_group, ...
    electroporated_column_by_group ...
    ] = get_electroporated_channel( ...
        TSeries_paths, ...
        suite2p_folders, ...
        numFolders)

    % ==============================================================
    % Détermine automatiquement le canal électroporé
    %
    % Colonnes attendues :
    %   1 = GCaMP
    %   2 = canal potentiel électroporé
    %   3 = canal potentiel électroporé
    %   4 = Green
    %
    % Pour chaque recording group :
    %   - teste colonne 2
    %   - puis colonne 3
    %   - sélectionne le premier TSeries non vide
    %   - utilise la même colonne dans suite2p_folders
    %
    % Outputs :
    %   current_electroporated_TSeries_path
    %       chemin TSeries électroporé par groupe
    %
    %   current_electroporated_folders_group
    %       dossiers suite2p correspondants par groupe
    %
    %   electroporated_column_by_group
    %       colonne sélectionnée (2 ou 3), NaN si absente
    % ==============================================================

    if nargin < 3 || isempty(numFolders)
        numFolders = max( ...
            size(TSeries_paths, 1), ...
            size(suite2p_folders, 1));
    end

    current_electroporated_TSeries_path = ...
        cell(numFolders, 1);

    current_electroporated_folders_group = ...
        cell(numFolders, 1);

    electroporated_column_by_group = ...
        nan(numFolders, 1);

    candidate_columns = [2 3];

    for m = 1:numFolders

        selected_column = [];

        % ==========================================================
        % Chercher le canal électroporé
        % ==========================================================

        for c = candidate_columns

            if m > size(TSeries_paths, 1) || ...
                    c > size(TSeries_paths, 2)

                continue;
            end

            candidate_path = ...
                TSeries_paths{m, c};

            if isempty(candidate_path)
                continue;
            end

            if ~(ischar(candidate_path) || ...
                    isstring(candidate_path))

                continue;
            end

            candidate_path = ...
                char(candidate_path);

            if isempty(strtrim(candidate_path))
                continue;
            end

            selected_column = c;
            break;
        end

        % ==========================================================
    % Aucun canal détecté
    % ==========================================================
    
    if isempty(selected_column)
    
        current_electroporated_TSeries_path{m} = '';
        current_electroporated_folders_group{m} = {};
    
        fprintf( ...
            'Group %d: no electroporated channel detected.\n', ...
            m);
    
    else
    
        % ======================================================
        % Sauvegarder colonne sélectionnée
        % ======================================================
    
        electroporated_column_by_group(m) = ...
            selected_column;
    
        % ======================================================
        % TSeries
        % ======================================================
    
        current_electroporated_TSeries_path{m} = ...
            TSeries_paths{m, selected_column};
    
        % ======================================================
        % Suite2p correspondant
        % ======================================================
    
        if m <= size(suite2p_folders, 1) && ...
                selected_column <= size(suite2p_folders, 2)
    
            current_electroporated_folders_group{m} = ...
                suite2p_folders{m, selected_column};
    
        else
    
            current_electroporated_folders_group{m} = {};
        end
    
        fprintf( ...
            ['Group %d: electroporated channel detected ' ...
             'in column %d.\n'], ...
            m, ...
            selected_column);
    end
end