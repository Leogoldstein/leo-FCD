function animal_date_list = create_animal_date_list(dataFolders)
    % Cette fonction crée les répertoires nécessaires et prépare les chemins de sauvegarde.
    % Elle stocke les informations dans animal_date_list et directories.
    %
    % Arguments :
    % - dataFolders : Cell array des chemins d'accès aux dossiers de données.
    % - truedataFolders : Cell array des chemins d'accès aux données véritables.
    % - PathSave : Répertoire de sauvegarde principal.
    % - newFPaths, newStatPaths, newIscellPaths, newOpsPaths : (facultatifs) Cell arrays contenant des chemins de fichiers supplémentaires.

    % Initialisation des variables de sortie
    animal_date_list = cell(length(dataFolders), 4); % animal_date_list(k, :) = {type, group, animal, date}

    % Define patterns for .npy and .mat files
    pattern_general = 'D:\\imaging\\([^\\]+)\\([^\\]+)\\([^\\]+)\\([^\\]+)';
    pattern_npy = 'D:\\imaging\\([^\\]+)\\([^\\]+)\\([^\\]+)';  % New pattern for .npy files
    
    % Loop through each file path in dataFolders
    for k = 1:length(dataFolders)
        % Load the selected file path
        file_path = dataFolders{k};
      
        % Check if the file path matches pattern_general or pattern_npy
        tokens = regexp(file_path, pattern_general, 'tokens');
        if isempty(tokens)
            tokens = regexp(file_path, pattern_npy, 'tokens');
        end
        
        if ~isempty(tokens)
            % Extract 'type_part', 'group_part', 'animal_part', and 'date_part' from tokens
            if length(tokens{1}) == 4
                % Matching pattern_general
                type_part = tokens{1}{1}; % Example: FCD
                group_part = tokens{1}{2};  % Example: mTor13
                animal_part = tokens{1}{3}; % Example: ani2
                date_part = tokens{1}{4}; % Example: 2024-10-22
            else
                % Matching pattern_npy
                type_part = tokens{1}{1}; % Example: jm
                group_part = ''; % No 'group_part' from the new pattern
                animal_part = tokens{1}{2}; % Example: jm040
                date_part = tokens{1}{3}; % Example: 2024-05-06
            end

            % Store the extracted parts in animal_date_list
            animal_date_list{k, 1} = type_part;
            animal_date_list{k, 2} = group_part;
            animal_date_list{k, 3} = animal_part;
            animal_date_list{k, 4} = date_part;
        end     
    end
end
