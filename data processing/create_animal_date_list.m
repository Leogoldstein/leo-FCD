function animal_date_list = create_animal_date_list(dataFolders)
    % Cette fonction extrait des informations à partir de chemins de fichiers et
    % stocke les résultats dans une liste structurée.
    %
    % Arguments :
    % - dataFolders : Cell array des chemins d'accès aux fichiers.
    %
    % Retour :
    % - animal_date_list : Cell array contenant {type, group, animal, date}.

    % Initialisation de la liste de sortie
    animal_date_list = cell(length(dataFolders), 4); % {type, group, animal, date}

    % Définition des patterns pour extraire les informations
    pattern_mTOR = 'D:\\imaging\\FCD\\([^\\]+)\\([^\\]+)\\([^\\]+)\\TSeries-[^\\]+\\suite2p\\plane0\\Fall\.mat';
    pattern_ani = 'D:\\imaging\\([^\\]+)\\([^\\]+)\\([^\\]+)\\TSeries-[^\\]+\\suite2p\\plane0\\Fall\.mat';
    pattern_jm = 'D:\\imaging\\jm\\([^\\]+)\\([^\\]+)';

    % Parcourir les chemins des fichiers
    for k = 1:length(dataFolders)
        file_path = dataFolders{k};
        tokens = []; % Initialisation des tokens

        % Essayer de faire correspondre chaque pattern
        tokens = regexp(file_path, pattern_mTOR, 'tokens');
        if ~isempty(tokens)
            type_part = 'FCD';
            group_part = tokens{1}{1}; % Exemple : mTor12
            animal_part = tokens{1}{2}; % Exemple : ani7
            date_part = tokens{1}{3}; % Exemple : 2024-07-06
        else
            tokens = regexp(file_path, pattern_ani, 'tokens');
            if ~isempty(tokens)
                type_part = tokens{1}{1}; % Exemple : CTRL
                group_part = ''; % Vide pour pattern_ani
                animal_part = tokens{1}{2}; % Exemple : ani7
                date_part = tokens{1}{3}; % Exemple : 2024-07-06
            else
                tokens = regexp(file_path, pattern_jm, 'tokens');
                if ~isempty(tokens)
                    type_part = 'jm';
                    group_part = ''; % Vide pour pattern_jm
                    animal_part = tokens{1}{1}; % Exemple : jm040
                    date_part = tokens{1}{2}; % Exemple : 2024-05-06
                end
            end
        end

        % Si des tokens valides ont été trouvés, les ajouter à la liste
        if ~isempty(tokens)
            animal_date_list{k, 1} = type_part;
            animal_date_list{k, 2} = group_part;
            animal_date_list{k, 3} = animal_part;
            animal_date_list{k, 4} = date_part;
        end
    end
end
