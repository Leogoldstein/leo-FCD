function [root_folders, dataFolders_by_group, ...
        include_blue_cells, automatic_selection] = ...
        select_data_folders_by_group(choices, group_order)

    %==============================================================%
    % Chemins racines
    %==============================================================%
    jm_folder   = 'D:\Imaging\jm';
    fcd_folder  = 'D:\Imaging\FCD';
    ctrl_folder = 'D:\Imaging\WT';
    sham_folder = 'D:\Imaging\SHAM';

    %==============================================================%
    % Initialisation des sorties
    %==============================================================%
    nGroups = numel(choices);

    root_folders = cell(nGroups, 1);
    dataFolders_by_group = cell(nGroups, 1);

    % automatic_selection est conservé pour chaque groupe.
    automatic_selection = false(nGroups, 1);

    %==============================================================%
    % Inclusion des cellules bleues / mTOR pour les données FCD
    %==============================================================%
    include_blue_cells = 0;

    if any(choices == 2)

        include_blue_cells = input( ...
            ['[FCD] Inclure les cellules bleues / mTOR ? ', ...
             '(1 = vrai, 0 = faux) : ']);

        if ~isscalar(include_blue_cells) || ...
                ~ismember(include_blue_cells, [0, 1])

            error( ...
                'include_blue_cells doit être égal à 0 ou 1.');
        end
    end

    %==============================================================%
    % Sélection des groupes
    %==============================================================%
    for i = 1:nGroups

        choice = choices(i);

        %==========================================================%
        % Détermination du type et du dossier racine
        %==========================================================%
        switch choice

            case 1
                current_type = 'jm';
                current_root_folder = jm_folder;

            case 2
                current_type = 'FCD';
                current_root_folder = fcd_folder;

            case 3
                current_type = 'WT';
                current_root_folder = ctrl_folder;

            case 4
                current_type = 'SHAM';
                current_root_folder = sham_folder;

            otherwise
                error( ...
                    'Choix invalide : %s.', ...
                    mat2str(choice));
        end

        % Enregistrer le dossier racine du groupe courant.
        root_folders{i} = current_root_folder;

        fprintf( ...
            '[SELECT] %s -> %s\n', ...
            current_type, ...
            current_root_folder);

        %==========================================================%
        % Sélection des dossiers
        %==========================================================%
        [dataFolders, current_automatic_selection] = ...
            select_folders( ...
                current_root_folder, ...
                include_blue_cells);

        automatic_selection(i) = ...
            logical(current_automatic_selection);

        %==========================================================%
        % Organisation par animal
        %==========================================================%
        switch choice

            case 1
                % Les données jm ne sont pas réorganisées ici.

            case 2
                dataFolders = organize_data_by_animal( ...
                    dataFolders, ...
                    group_order{2});

            case 3
                dataFolders = organize_data_by_animal( ...
                    dataFolders, ...
                    group_order{3});

            case 4
                dataFolders = organize_data_by_animal( ...
                    dataFolders, ...
                    group_order{4});
        end

        %==========================================================%
        % Enregistrement des dossiers du groupe
        %==========================================================%
        dataFolders_by_group{i} = dataFolders;
    end
end