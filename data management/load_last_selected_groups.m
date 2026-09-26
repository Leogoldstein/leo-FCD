function [selected_groups, selected_groups_reloaded, recap_all] = ...
        load_last_selected_groups( ...
            root_folders, ...
            choices, ...
            group_order, ...
            selection_mode, ...
            age_group, ...
            include_electroporated)

    %==============================================================
    % Initialisation
    %==============================================================

    selected_groups = struct();

    selected_groups_reloaded = false;

    % recap_all devient un conteneur par type :
    %
    % recap_all.FCD  = tableau recap FCD
    % recap_all.SHAM = tableau recap SHAM
    % etc.
    %
    % Les fichiers .mat eux-mêmes peuvent continuer à contenir
    % simplement :
    %
    % recap_all = tableau
    %
    % La séparation par type est faite uniquement ici au chargement.

    recap_all = struct();

    recap_loaded = false;


    if isempty(choices) || ...
            isempty(root_folders) || ...
            ~isstruct(selection_mode) || ...
            ~isstruct(age_group)

        return;

    end


    %==============================================================
    % Vérifier s'il existe au moins une présélection
    %==============================================================

    mode_names = fieldnames(selection_mode);

    is_preselected = false;


    for i = 1:numel(mode_names)

        if strcmpi( ...
                selection_mode.(mode_names{i}), ...
                'preselected')

            is_preselected = true;

            break;

        end

    end


    if ~is_preselected

        return;

    end


    %==============================================================
    % Electroporated / non-electroporated
    %==============================================================

    if include_electroporated

        electroporated_name = ...
            'electroporated';

    else

        electroporated_name = ...
            'non-electroporated';

    end


    %==============================================================
    % Boucle sur les groupes sélectionnés
    %==============================================================

    for i = 1:numel(choices)

        choice = choices(i);


        if choice < 1 || ...
                choice > numel(group_order)

            continue;

        end


        current_type = ...
            group_order{choice};


        %----------------------------------------------------------
        % Uniquement pour les présélections
        %----------------------------------------------------------

        if ~isfield( ...
                selection_mode, ...
                current_type)

            continue;

        end


        current_selection_mode = ...
            selection_mode.(current_type);


        if ~strcmpi( ...
                current_selection_mode, ...
                'preselected')

            continue;

        end


        %==========================================================
        % Age group
        %==========================================================

        if ~isfield( ...
                age_group, ...
                current_type) || ...
                isempty( ...
                    age_group.(current_type))

            fprintf( ...
                'Age group absent pour %s.\n', ...
                current_type);

            continue;

        end


        current_age_group = ...
            strrep( ...
                char( ...
                    string( ...
                        age_group.(current_type))), ...
                ' ', ...
                '_');


        %==========================================================
        % Root folder
        %==========================================================

        if i > numel(root_folders) || ...
                isempty(root_folders{i})

            warning( ...
                'load_last_selected_groups:MissingRootFolder', ...
                'Root folder absent pour %s.', ...
                current_type);

            continue;

        end


        current_root_folder = ...
            root_folders{i};


        %==========================================================
        % Nom du fichier attendu
        %==========================================================

        file_name = sprintf( ...
            'selected_groups_%s_preselected_%s.mat', ...
            current_age_group, ...
            electroporated_name);


        selected_groups_path = ...
            fullfile( ...
                current_root_folder, ...
                file_name);


        %==========================================================
        % Vérifier l'existence du fichier
        %==========================================================

        if exist( ...
                selected_groups_path, ...
                'file') ~= 2

            fprintf( ...
                ['Aucun selected_groups précédent trouvé pour :\n' ...
                 '  %s | %s | %s\n'], ...
                current_type, ...
                current_age_group, ...
                electroporated_name);

            continue;

        end


        %==========================================================
        % Informations sur le fichier
        %==========================================================

        file_info = ...
            dir(selected_groups_path);


        if isempty(file_info)

            saved_date = '';

        else

            saved_date = ...
                file_info.date;

        end


        %==========================================================
        % Confirmation utilisateur
        %==========================================================

        answer = questdlg( ...
            sprintf( ...
                ['Un selected_groups enregistré existe pour :\n\n' ...
                 'Type : %s\n' ...
                 'Age group : %s\n' ...
                 'Mode : preselected\n' ...
                 'Cellules : %s\n\n' ...
                 'Dernière sauvegarde : %s\n\n' ...
                 'Voulez-vous charger selected_groups et recap_all ?'], ...
                current_type, ...
                current_age_group, ...
                electroporated_name, ...
                saved_date), ...
            'Load selected_groups', ...
            'Yes', ...
            'No', ...
            'Yes');


        if ~strcmpi( ...
                answer, ...
                'Yes')

            fprintf( ...
                'Ancien selected_groups non chargé pour %s.\n', ...
                current_type);

            continue;

        end


        %==========================================================
        % Vérifier les variables disponibles
        %==========================================================

        try

            variables_in_file = ...
                who( ...
                    '-file', ...
                    selected_groups_path);


            has_selected_groups = ...
                ismember( ...
                    'selected_groups', ...
                    variables_in_file);


            has_recap_all = ...
                ismember( ...
                    'recap_all', ...
                    variables_in_file);


            if ~has_selected_groups

                warning( ...
                    'load_last_selected_groups:InvalidFile', ...
                    'selected_groups absent : %s', ...
                    selected_groups_path);

                continue;

            end


            %------------------------------------------------------
            % Charger uniquement les variables nécessaires
            %------------------------------------------------------

            if has_recap_all

                loaded_data = ...
                    load( ...
                        selected_groups_path, ...
                        'selected_groups', ...
                        'recap_all');

            else

                loaded_data = ...
                    load( ...
                        selected_groups_path, ...
                        'selected_groups');

            end


        catch ME

            warning( ...
                'load_last_selected_groups:LoadFailed', ...
                'Chargement impossible : %s\n%s', ...
                selected_groups_path, ...
                ME.message);

            continue;

        end


        %==========================================================
        % Vérifier selected_groups
        %==========================================================

        if ~isfield( ...
                loaded_data, ...
                'selected_groups') || ...
                ~isstruct( ...
                    loaded_data.selected_groups)

            warning( ...
                'load_last_selected_groups:InvalidFile', ...
                'Structure selected_groups invalide : %s', ...
                selected_groups_path);

            continue;

        end


        loaded_selected_groups = ...
            loaded_data.selected_groups;


        if ~isfield( ...
                loaded_selected_groups, ...
                current_type)

            warning( ...
                'load_last_selected_groups:MissingType', ...
                ['Le fichier ne contient pas ' ...
                 'selected_groups.%s.'], ...
                current_type);

            continue;

        end


        %==========================================================
        % Récupérer selected_groups du type correspondant
        %==========================================================

        selected_groups.(current_type) = ...
            loaded_selected_groups.(current_type);


        selected_groups_reloaded = true;


        fprintf( ...
            'selected_groups chargé pour %s :\n%s\n', ...
            current_type, ...
            selected_groups_path);


        %==========================================================
        % Récupérer recap_all
        %==========================================================

        if ~has_recap_all

            fprintf( ...
                ['recap_all absent du fichier pour %s.\n' ...
                 'selected_groups a néanmoins été chargé.\n'], ...
                current_type);

            continue;

        end


        %----------------------------------------------------------
        % IMPORTANT :
        %
        % Dans le fichier :
        %
        % loaded_data.recap_all = tableau
        %
        % Dans la variable de sortie :
        %
        % recap_all.FCD  = tableau FCD
        % recap_all.SHAM = tableau SHAM
        %
        % Ainsi, aucun type ne peut écraser le recap d'un autre.
        %----------------------------------------------------------

        recap_all.(current_type) = ...
            loaded_data.recap_all;


        recap_loaded = true;


        fprintf( ...
            'recap_all chargé pour %s.\n', ...
            current_type);

    end


    %==============================================================
    % Bilan final
    %==============================================================

    if selected_groups_reloaded

        fprintf( ...
            '\nselected_groups : chargement terminé.\n');

    end


    if recap_loaded

        fprintf( ...
            'recap_all : chargement terminé.\n');

    else

        fprintf( ...
            'Aucun recap_all précédent chargé.\n');

    end

end