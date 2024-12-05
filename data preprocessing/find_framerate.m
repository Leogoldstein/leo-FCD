function sampling_rate = find_framerate(path)
    % Fonction pour extraire la valeur numérique de sampling_rate depuis un fichier .env
    % Arguments :
    %   - path : chemin complet du fichier .env
    % Retourne :
    %   - sampling_rate : valeur de sampling_rate en double (NaN si introuvable ou invalide)
    
    try
        % Lire le fichier XML
        xmlDoc = xmlread(path);

        % Rechercher les noeuds avec la clé "framerate"
        framerateNodes = xmlDoc.getElementsByTagName('PVStateValue');

        % Initialiser une variable pour stocker la valeur
        sampling_rate = NaN;

        % Parcourir les noeuds pour trouver la clé "framerate"
        for i = 0:framerateNodes.getLength-1
            currentNode = framerateNodes.item(i);
            if strcmp(currentNode.getAttribute('key'), 'framerate')
                % Convertir la valeur en numérique
                sampling_rate = str2double(char(currentNode.getAttribute('value')));
                break;
            end
        end

        % Vérifier si la conversion a échoué
        if isnan(sampling_rate)
            error('La clé "framerate" est introuvable ou la valeur n''est pas valide.');
        end
    catch ME
        % Gestion des erreurs
        fprintf('Erreur lors de la lecture du fichier : %s\n', ME.message);
        sampling_rate = NaN;
    end
end