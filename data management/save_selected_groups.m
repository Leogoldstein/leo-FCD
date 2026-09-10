function save_selected_groups( ...
        selected_groups, ...
        root_folders, ...
        choices, ...
        group_order, ...
        age_group, ...
        selection_mode, ...
        include_electroporated)

    %==============================================================%
    % Vérifications
    %==============================================================%

    if isempty(selected_groups) || ...
            ~isstruct(selected_groups)

        fprintf( ...
            'selected_groups vide : aucune sauvegarde.\n');

        return;
    end


    if ~isstruct(selection_mode)

        return;
    end


    type_names = ...
        fieldnames(selected_groups);


    %==============================================================%
    % Suffixe electroporated / non-electroporated
    %==============================================================%

    if include_electroporated

        electroporated_name = ...
            'electroporated';

    else

        electroporated_name = ...
            'non-electroporated';
    end


    %==============================================================%
    % Boucle sur les types présents dans selected_groups
    %==============================================================%

    for t = 1:numel(type_names)

        current_type = ...
            type_names{t};


        %==========================================================%
        % Sauvegarde uniquement en mode preselected
        %==========================================================%

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


        %----------------------------------------------------------%
        % Retrouver le root_folder correspondant au type
        %----------------------------------------------------------%

        root_idx = ...
            [];


        for i = 1:numel(choices)

            choice = ...
                choices(i);


            if choice > numel(group_order)
                continue;
            end


            if strcmpi( ...
                    group_order{choice}, ...
                    current_type)

                root_idx = ...
                    i;

                break;
            end
        end


        if isempty(root_idx) || ...
                root_idx > numel(root_folders)

            warning( ...
                'save_selected_groups:RootFolderNotFound', ...
                'Root folder introuvable pour %s.', ...
                current_type);

            continue;
        end


        current_root_folder = ...
            root_folders{root_idx};


        if isempty(current_root_folder)
            continue;
        end


        %----------------------------------------------------------%
        % Age group
        %----------------------------------------------------------%

        current_age_group = ...
            '';


        if isstruct(age_group) && ...
                isfield( ...
                    age_group, ...
                    current_type)

            current_age_group = ...
                age_group.(current_type);
        end


        if isempty(current_age_group)

            current_age_group = ...
                'all_ages';
        end


        %----------------------------------------------------------%
        % Nettoyage des noms
        %----------------------------------------------------------%

        current_age_group = ...
            strrep( ...
                char(string(current_age_group)), ...
                ' ', ...
                '_');


        current_selection_mode = ...
            strrep( ...
                char(string(current_selection_mode)), ...
                ' ', ...
                '_');


        %==========================================================%
        % Nom du fichier
        %
        % Exemples :
        %
        % selected_groups_Adult_preselected_electroporated.mat
        %
        % selected_groups_Adult_preselected_non-electroporated.mat
        %==========================================================%

        file_name = ...
            sprintf( ...
                'selected_groups_%s_%s_%s.mat', ...
                current_age_group, ...
                current_selection_mode, ...
                electroporated_name);


        save_path = ...
            fullfile( ...
                current_root_folder, ...
                file_name);


        %==========================================================%
        % Sauvegarde / écrasement
        %==========================================================%

        save( ...
            save_path, ...
            'selected_groups', ...
            '-v7.3');


        fprintf( ...
            'selected_groups sauvegardé :\n%s\n', ...
            save_path);
    end
end