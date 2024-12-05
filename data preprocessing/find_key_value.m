function value = find_key_value(path, key)
    % Fonction pour extraire la valeur numérique ou textuelle d'une clé depuis un fichier XML
    % Arguments :
    %   - path : chemin complet du fichier XML
    %   - key : clé à rechercher dans les noeuds 'PVStateValue'
    % Retourne :
    %   - value : valeur associée à la clé (NaN si introuvable ou invalide)

    try
        % Lire le fichier XML
        xmlDoc = xmlread(path);

        % Rechercher les noeuds avec la balise 'PVStateValue'
        nodes = xmlDoc.getElementsByTagName('PVStateValue');

        % Initialiser une variable pour stocker la valeur
        value = NaN;

        % Parcourir les noeuds pour trouver la clé spécifiée
        for i = 0:nodes.getLength-1
            currentNode = nodes.item(i);
            if strcmp(currentNode.getAttribute('key'), key)
                % Tenter de convertir la valeur en numérique
                valueStr = char(currentNode.getAttribute('value'));
                numericValue = str2double(valueStr);

                % Si la conversion échoue, garder la valeur textuelle
                if isnan(numericValue)
                    value = valueStr;
                else
                    value = numericValue;
                end
                break;
            end
        end

        % Vérifier si la clé n'a pas été trouvée
        if isnan(value)
            error('La clé "%s" est introuvable ou la valeur est invalide.', key);
        end
    catch ME
        % Gestion des erreurs
        fprintf('Erreur lors de la lecture du fichier : %s\n', ME.message);
        value = NaN;
    end
end
