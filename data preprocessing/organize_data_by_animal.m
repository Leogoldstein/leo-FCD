function newdataFolders = organize_data_by_animal(SelectedFolders)

    % Patterns pour identifier les chemins
    pattern_mTOR = 'D:\\imaging\\FCD\\([^\\]+)\\([^\\]+)(?:\\([^\\]+))?'; % Partie date facultative
    pattern_ani = 'D:\\imaging\\CTRL\\([^\\]+)(?:\\([^\\]+))?'; % Partie date facultative
    pattern_general = '(\d{4}-\d{2}-\d{2})-(mTor\d+)?-(ani\d+)';
    
    % Initialiser la liste des nouveaux dossiers
    newdataFolders = {};
    
    % Parcourir chaque dossier
    for k = 1:length(SelectedFolders)
        file_path = SelectedFolders{k};
        disp(['Selected folder: ' file_path]);
        
        % Vérifier si le chemin correspond déjà à l'un des patterns existants
        is_mTOR = ~isempty(regexp(file_path, pattern_mTOR, 'once'));
        is_ani = ~isempty(regexp(file_path, pattern_ani, 'once'));
        
        % Si le chemin correspond déjà, l'ajouter à newdataFolders et passer au suivant
        if is_mTOR || is_ani
            disp(['Folder already matches a pattern: ' file_path]);
            newdataFolders{end+1} = file_path;
            continue;
        end
        
        % Extraire les tokens depuis le pattern général (date, mTor, ani)
        tokens = regexp(file_path, pattern_general, 'tokens');
        
        if ~isempty(tokens)
            % Extraire les sous-parties
            date_part = tokens{1}{1}; % Date
            mTor_part = tokens{1}{2}; % mTor (peut être vide)
            animal_part = tokens{1}{3}; % Animal
            
            disp(['Original folder: ' file_path]);
            
            % Construire le dossier cible
            targetFolder = getTargetFolder(mTor_part, animal_part, date_part);
            
            % Créer le dossier cible s'il n'existe pas
            if ~exist(targetFolder, 'dir')
                mkdir(targetFolder);
                disp(['Created new target folder: ' targetFolder]);
            end
            
            % Déplacer les fichiers
            contents = dir(file_path);
            for item = contents'
                if ~strcmp(item.name, '.') && ~strcmp(item.name, '..')
                    source = fullfile(file_path, item.name);
                    target = fullfile(targetFolder, item.name);
                    try
                        movefile(source, target);
                        disp(['Moved: ' source ' to ' target]);
                    catch ME
                        warning(['Could not move file: ' source '. Error: ' ME.message']);
                    end
                end
            end
            
            % Supprimer le dossier source
            try
                rmdir(file_path, 's');
            catch ME
                warning(['Could not remove folder: ' file_path '. Error: ' ME.message']);
            end
            
            % Stocker le chemin final
            newdataFolders{end+1} = targetFolder;
        else
            warning(['Folder name does not match the expected pattern: ' file_path]);
        end
    end
end

function targetFolder = getTargetFolder(mTor_part, animal_part, date_part)
    % Définir le dossier de base
    base_path = 'D:\imaging';
    
    % Construire le chemin cible en fonction de la présence de mTor_part
    if ~isempty(mTor_part) && contains(mTor_part, 'mTor', 'IgnoreCase', true)
        targetFolder = fullfile(base_path, 'FCD', 'to processed', mTor_part, animal_part, date_part);
    else
        targetFolder = fullfile(base_path, 'CTRL', 'to processed', animal_part, date_part);
    end
end
