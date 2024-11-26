function save_paths(truedataFolders, directories, newFPaths, newStatPaths, newIscellPaths, newOpsPaths)
    % Sauvegarde les données dans paths.mat dans les répertoires donnés.
    %
    % Arguments :
    % truedataFolders : Cell array des données obligatoires.
    % directories : Cell array des répertoires cibles.
    % newFPaths : Cell array des chemins 'newFPaths' (facultatif).
    % newStatPaths : Cell array des chemins 'newStatPaths' (facultatif).
    % newIscellPaths : Cell array des chemins 'newIscellPaths' (facultatif).
    % newOpsPaths : Cell array des chemins 'newOpsPaths' (facultatif).

    % Si une variable n'est pas fournie, on la définit comme vide
    if nargin < 3, newFPaths = {}; end
    if nargin < 4, newStatPaths = {}; end
    if nargin < 5, newIscellPaths = {}; end
    if nargin < 6, newOpsPaths = {}; end

    % Boucle à travers chaque répertoire
    for k = 1:numel(directories)
        saveData = struct(); % Crée une structure pour contenir les variables à sauvegarder
        
        % Ajoute les variables optionnelles si elles existent
        if ~isempty(newFPaths) && numel(newFPaths) >= k && ~isempty(newFPaths{k})
            saveData.newFPaths = newFPaths{k};
        end
        if ~isempty(newStatPaths) && numel(newStatPaths) >= k && ~isempty(newStatPaths{k})
            saveData.newStatPaths = newStatPaths{k};
        end
        if ~isempty(newIscellPaths) && numel(newIscellPaths) >= k && ~isempty(newIscellPaths{k})
            saveData.newIscellPaths = newIscellPaths{k};
        end
        if ~isempty(newOpsPaths) && numel(newOpsPaths) >= k && ~isempty(newOpsPaths{k})
            saveData.newOpsPaths = newOpsPaths{k};
        end

        % Ajoute la variable obligatoire
        saveData.truedataFolders = truedataFolders{k};

        % Sauvegarde dans le fichier paths.mat avec -append
        save(fullfile(directories{k}, 'paths.mat'), '-struct', 'saveData', '-append');
    end
end
