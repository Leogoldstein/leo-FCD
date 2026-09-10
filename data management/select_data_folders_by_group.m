function [ ...
        root_folders, ...
        dataFolders_by_group, ...
        include_electroporated_cells, ...
        automatic_selection, ...
        selection_mode, ...
        age_group ...
    ] = ...
    select_data_folders_by_group( ...
        choices, ...
        group_order)

    %==============================================================%
    % Chemins racines
    %==============================================================%
    jm_folder   = ...
        'D:\Imaging\jm';

    fcd_folder  = ...
        'D:\Imaging\FCD';

    ctrl_folder = ...
        'D:\Imaging\WT';

    sham_folder = ...
        'D:\Imaging\SHAM';


    %==============================================================%
    % Initialisation des sorties
    %==============================================================%
    nGroups = ...
        numel(choices);


    root_folders = ...
        cell(nGroups, 1);


    dataFolders_by_group = ...
        cell(nGroups, 1);


    %==============================================================%
    % Informations de sélection
    %
    % Toutes les informations sont directement indexées par type :
    %
    %   automatic_selection.jm
    %   automatic_selection.FCD
    %   automatic_selection.WT
    %   automatic_selection.SHAM
    %
    %   selection_mode.jm
    %   selection_mode.FCD
    %   ...
    %
    %   age_group.FCD
    %   age_group.SHAM
    %
    % age_group reste vide pour JM / WT ou sélection manuelle.
    %==============================================================%
    automatic_selection = ...
        struct();


    selection_mode = ...
        struct();


    age_group = ...
        struct();


    %==============================================================%
    % Inclusion des cellules électroporées / mTOR
    %==============================================================%
    include_electroporated_cells = ...
        0;


    if any( ...
            ismember( ...
                choices, ...
                [2 4]))

        include_electroporated_cells = ...
            input( ...
                ['[FCD] Inclure les cellules électroporées ? ', ...
                 '(1 = vrai, 0 = faux) : ']);


        if ~isscalar(include_electroporated_cells) || ...
                ~ismember( ...
                    include_electroporated_cells, ...
                    [0 1])

            error( ...
                'include_electroporated_cells doit être égal à 0 ou 1.');
        end
    end


    %==============================================================%
    % Sélection des groupes
    %==============================================================%
    for i = 1:nGroups

        choice = ...
            choices(i);


        %==========================================================%
        % Détermination du type et du dossier racine
        %==========================================================%
        switch choice

            case 1

                current_type = ...
                    'jm';


                current_root_folder = ...
                    jm_folder;


            case 2

                current_type = ...
                    'FCD';


                current_root_folder = ...
                    fcd_folder;


            case 3

                current_type = ...
                    'WT';


                current_root_folder = ...
                    ctrl_folder;


            case 4

                current_type = ...
                    'SHAM';


                current_root_folder = ...
                    sham_folder;


            otherwise

                error( ...
                    'Choix invalide : %s.', ...
                    mat2str(choice));
        end


        %==========================================================%
        % Enregistrer le dossier racine du groupe courant
        %==========================================================%
        root_folders{i} = ...
            current_root_folder;


        fprintf( ...
            '[SELECT] %s -> %s\n', ...
            current_type, ...
            current_root_folder);


        %==========================================================%
        % Sélection des dossiers
        %==========================================================%
        [ ...
            dataFolders, ...
            current_automatic_selection, ...
            current_selection_mode, ...
            current_age_group ...
        ] = ...
            select_folders( ...
                current_root_folder, ...
                include_electroporated_cells);


        %==========================================================%
        % Enregistrer les informations de sélection par type
        %==========================================================%
        automatic_selection.(current_type) = ...
            logical( ...
                current_automatic_selection);


        selection_mode.(current_type) = ...
            current_selection_mode;


        age_group.(current_type) = ...
            current_age_group;


        %==========================================================%
        % Informations console
        %==========================================================%
        fprintf( ...
            '[SELECT] Type: %s\n', ...
            current_type);


        fprintf( ...
            '[SELECT] Selection mode: %s\n', ...
            current_selection_mode);


        if ~isempty(current_age_group)

            fprintf( ...
                '[SELECT] Age group: %s\n', ...
                current_age_group);
        end


        %==========================================================%
        % Organisation par animal
        %==========================================================%
        switch choice

            case 1
                % Les données jm ne sont pas réorganisées ici.


            case 2

                dataFolders = ...
                    organize_data_by_animal( ...
                        dataFolders, ...
                        group_order{2});


            case 3

                dataFolders = ...
                    organize_data_by_animal( ...
                        dataFolders, ...
                        group_order{3});


            case 4

                dataFolders = ...
                    organize_data_by_animal( ...
                        dataFolders, ...
                        group_order{4});
        end


        %==========================================================%
        % Enregistrement des dossiers du groupe
        %==========================================================%
        dataFolders_by_group{i} = ...
            dataFolders;
    end
end