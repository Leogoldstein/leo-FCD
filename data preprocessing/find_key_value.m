function [recording_time, sampling_rate, optical_zoom, position] = find_key_value(path)
    % Fonction pour extraire l'heure d'enregistrement, la framerate (sampling rate),
    % et la valeur de l'opticalZoom dans un fichier XML.
    % Arguments :
    %   - path : chemin complet du fichier XML
    % Retourne :
    %   - recording_time : heure d'enregistrement extraite de l'attribut 'date' de <Environment> (format : HH:MM:SS AM/PM)
    %   - sampling_rate : valeur associée à la clé 'framerate' (NaN si introuvable ou invalide)
    %   - optical_zoom : valeur associée à la clé 'opticalZoom' (NaN si introuvable)

    try
        % Lire le fichier XML
        xmlDoc = xmlread(path);

        % === Partie 1 : Extraire uniquement l'heure d'enregistrement ===
        envNode = xmlDoc.getElementsByTagName('Environment').item(0);
        if ~isempty(envNode) && envNode.hasAttribute('date')
            full_date = char(envNode.getAttribute('date')); % Exemple : "5/6/2024 11:33:38 AM"
            split_date = split(full_date); % Séparer la chaîne en date et heure
            if numel(split_date) > 1
                recording_time = split_date{2}; % Extraire la partie heure (e.g., "11:33:38")
                if numel(split_date) > 2
                    recording_time = [recording_time ' ' split_date{3}]; % Ajouter AM/PM
                end
            end
        end

        % === Partie 2 : Extraire la valeur associée à 'framerate' ===
        pvNodes = xmlDoc.getElementsByTagName('PVStateValue');
        
        for i = 0:pvNodes.getLength-1
            currentNode = pvNodes.item(i);
            
            % Extraction de la framerate
            if strcmp(currentNode.getAttribute('key'), 'framerate')
                valueStr = char(currentNode.getAttribute('value'));
                sampling_rate = str2double(valueStr);
            end
            
            % Extraction de l'opticalZoom
            if strcmp(currentNode.getAttribute('key'), 'opticalZoom')
                optical_zoom = str2double(char(currentNode.getAttribute('value')));
            end
       
            if strcmp(currentNode.getAttribute('key'), 'positionCurrent')
                % Chercher dans les sous-nœuds <SubindexedValues>
                subindexedValuesNodes = currentNode.getElementsByTagName('SubindexedValues');
                
                for j = 0:subindexedValuesNodes.getLength-1
                    subindexedNode = subindexedValuesNodes.item(j);
                    % Vérifier si l'index est "ZAxis"
                    if strcmp(subindexedNode.getAttribute('index'), 'ZAxis')
                        % Chercher la balise <SubindexedValue> correspondante
                        subindexedValueNode = subindexedNode.getElementsByTagName('SubindexedValue').item(0);
                        if ~isempty(subindexedValueNode)
                            % Extraire la valeur de "value"
                            valueStr = char(subindexedValueNode.getAttribute('value'));
                            position = str2double(valueStr); % Assigner la position
                            break;
                        end
                    end
                end               
            end
        end

    catch ME
        % Gestion des erreurs
        fprintf('Erreur lors de la lecture du fichier : %s\n', ME.message);
        recording_time = '';
        sampling_rate = NaN;
        optical_zoom = NaN;
        position = NaN;
    end
end
