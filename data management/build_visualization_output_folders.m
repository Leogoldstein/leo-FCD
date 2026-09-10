function [output_folders_type, output_folders_line] = ...
        build_visualization_output_folders( ...
            selected_groups, ...
            type_names)

    %==============================================================%
    % BUILD VISUALIZATION OUTPUT FOLDERS
    %
    % output_folders_type :
    %
    %   output_folders_type{t}
    %
    % Exemple :
    %
    %   D:\Imaging\FCD\Summary plots\...
    %       \Pre-selection electroporated cells\Adult
    %
    %
    % output_folders_line :
    %
    %   output_folders_line{t}{l}
    %
    % Exemple :
    %
    %   D:\Imaging\FCD\Summary plots\...
    %       \Pre-selection electroporated cells\Adult\mtor46
    %
    %
    % t = index du type dans type_names
    % l = index de la line dans unique_lines du type
    %
    %
    % Structure de départ attendue :
    %
    % selected_groups.(type)(k).paths.output_folders{m}
    %
    % avec par exemple :
    %
    % ...\Adult\mtor46\2469\26-05-2026
    %
    %==============================================================%


    %==============================================================%
    % Initialisation
    %==============================================================%
    output_folders_type = ...
        cell( ...
            numel(type_names), ...
            1);


    output_folders_line = ...
        cell( ...
            numel(type_names), ...
            1);


    %==============================================================%
    % Boucle sur les types
    %==============================================================%
    for t = 1:numel(type_names)

        current_type = ...
            type_names{t};


        current_groups = ...
            selected_groups.(current_type);


        %==========================================================%
        % Aucun groupe
        %==========================================================%
        if isempty(current_groups)

            output_folders_type{t} = ...
                '';


            output_folders_line{t} = ...
                {};

            continue;
        end


        %==========================================================%
        % Recuperer les lines dans l'ordre des groupes
        %==========================================================%
        line_values = ...
            strings( ...
                numel(current_groups), ...
                1);


        for k = 1:numel(current_groups)

            if isfield(current_groups(k), 'line') && ...
                    ~isempty(current_groups(k).line)

                line_values(k) = ...
                    string( ...
                        current_groups(k).line);
            end
        end


        %==========================================================%
        % Lines uniques
        %==========================================================%
        unique_lines = ...
            unique( ...
                line_values, ...
                'stable');


        unique_lines( ...
            strlength(unique_lines) == 0) = [];


        %==========================================================%
        % Initialiser les output folders des lines de ce type
        %==========================================================%
        output_folders_line{t} = ...
            cell( ...
                numel(unique_lines), ...
                1);


        %==========================================================%
        % Trouver le premier output folder valide du type
        %
        % Il sert uniquement à récupérer le dossier :
        %
        % ...\Adult
        %
        % à partir de :
        %
        % ...\Adult\line\animal\date
        %==========================================================%
        first_output_path = ...
            '';


        for k = 1:numel(current_groups)

            current_group = ...
                current_groups(k);


            if ~isfield(current_group, 'paths') || ...
                    ~isstruct(current_group.paths) || ...
                    ~isfield( ...
                        current_group.paths, ...
                        'output_folders') || ...
                    isempty( ...
                        current_group.paths.output_folders)

                continue;
            end


            current_paths = ...
                current_group.paths.output_folders;


            if ~iscell(current_paths)

                current_paths = ...
                    {current_paths};
            end


            for m = 1:numel(current_paths)

                if isempty(current_paths{m})

                    continue;
                end


                first_output_path = ...
                    char( ...
                        string(current_paths{m}));


                break;
            end


            if ~isempty(first_output_path)

                break;
            end
        end


        %==========================================================%
        % Aucun output folder trouvé
        %==========================================================%
        if isempty(first_output_path)

            output_folders_type{t} = ...
                '';


            warning( ...
                'No paths.output_folders found for type %s.', ...
                current_type);

            continue;
        end


        %==========================================================%
        % Output folder du TYPE
        %
        % Exemple :
        %
        % ...\Adult\mtor46\2469\26-05-2026
        %
        % date   -> animal
        % animal -> line
        % line   -> Adult
        %==========================================================%
        animal_folder = ...
            fileparts( ...
                first_output_path);


        line_folder = ...
            fileparts( ...
                animal_folder);


        type_folder = ...
            fileparts( ...
                line_folder);


        output_folders_type{t} = ...
            type_folder;


        %==========================================================%
        % Créer le dossier du type si nécessaire
        %==========================================================%
        if exist( ...
                type_folder, ...
                'dir') ~= 7

            mkdir( ...
                type_folder);
        end


        %==========================================================%
        % Boucle sur les lines de CE TYPE
        %==========================================================%
        for l = 1:numel(unique_lines)

            current_line = ...
                unique_lines(l);


            line_output_folder = ...
                '';


            %======================================================%
            % Chercher un animal appartenant à cette line
            %======================================================%
            for k = 1:numel(current_groups)

                current_group = ...
                    current_groups(k);


                %--------------------------------------------------%
                % Vérifier la line
                %--------------------------------------------------%
                if ~isfield(current_group, 'line') || ...
                        isempty(current_group.line)

                    continue;
                end


                if string(current_group.line) ~= current_line

                    continue;
                end


                %--------------------------------------------------%
                % Vérifier les output folders
                %--------------------------------------------------%
                if ~isfield(current_group, 'paths') || ...
                        ~isstruct(current_group.paths) || ...
                        ~isfield( ...
                            current_group.paths, ...
                            'output_folders') || ...
                        isempty( ...
                            current_group.paths.output_folders)

                    continue;
                end


                current_paths = ...
                    current_group.paths.output_folders;


                if ~iscell(current_paths)

                    current_paths = ...
                        {current_paths};
                end


                %--------------------------------------------------%
                % Premier output folder valide
                %--------------------------------------------------%
                for m = 1:numel(current_paths)

                    if isempty(current_paths{m})

                        continue;
                    end


                    current_path = ...
                        char( ...
                            string(current_paths{m}));


                    %----------------------------------------------%
                    % Exemple :
                    %
                    % ...\Adult\mtor46\2469\26-05-2026
                    %
                    % date   -> animal
                    % animal -> line
                    %----------------------------------------------%
                    animal_folder = ...
                        fileparts( ...
                            current_path);


                    line_output_folder = ...
                        fileparts( ...
                            animal_folder);


                    break;
                end


                if ~isempty(line_output_folder)

                    break;
                end
            end


            %======================================================%
            % Stocker DIRECTEMENT à la position {t}{l}
            %======================================================%
            output_folders_line{t}{l} = ...
                line_output_folder;


            %======================================================%
            % Aucun chemin trouvé pour cette line
            %======================================================%
            if isempty(line_output_folder)

                warning( ...
                    ['No paths.output_folders found for ', ...
                     'type %s | line %s.'], ...
                    current_type, ...
                    char(current_line));

                continue;
            end


            %======================================================%
            % Créer si nécessaire
            %======================================================%
            if exist( ...
                    line_output_folder, ...
                    'dir') ~= 7

                mkdir( ...
                    line_output_folder);
            end
        end
    end
end