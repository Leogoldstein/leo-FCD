function export_data(identifier, dates, analysis_choice, pathexcel, varargin)
    % Si le choix d'analyse est 1 ou 2, ne rien faire et quitter la fonction
    if analysis_choice == 1 || analysis_choice == 2
        disp('No data to export for cases 1 or 2. Exiting function...');
        return;
    end

    % Charger le contenu existant du fichier Excel (si le fichier existe)
    if isfile(pathexcel)
        existing_data = readcell(pathexcel);
    else
        % Si le fichier n'existe pas, créer un tableau vide
        existing_data = {};
    end

    % Définir les en-têtes pour chaque cas
    headers_general = {'Identifier', 'Date'};
    headers_case_3 = {'SamplingRate', 'SynchronousFrames', 'MeanFrequencyMinutes', 'StdFrequencyMinutes'};
    headers_case_4 = {'SCEsThreshold'};
    
    % Combiner tous les en-têtes
    all_headers = [headers_general, headers_case_3, headers_case_4];

    % Si le fichier est vide ou incomplet, ajouter les en-têtes
    if isempty(existing_data) || isempty(existing_data{1, 1})
        writecell(all_headers, pathexcel, 'WriteMode', 'overwrite');
        existing_data = [all_headers; cell(0, numel(all_headers))]; % Ajouter en-têtes
    elseif size(existing_data, 2) < numel(all_headers)
        % Ajouter les en-têtes manquants si nécessaire
        for i = size(existing_data, 2) + 1:numel(all_headers)
            existing_data{1, i} = all_headers{i};
        end
        writecell(existing_data, pathexcel, 'WriteMode', 'overwrite');
    end

    % Parcourir toutes les dates fournies
    for m = 1:length(dates)
        try
            % Chercher une ligne correspondante (même Identifier et Date)
            row_to_update = find_row_for_update(identifier, dates{m}, existing_data);

            % Si une ligne existe déjà, mettre à jour uniquement les colonnes nécessaires
            if row_to_update ~= -1
                switch analysis_choice
                    case 3
                        existing_data(row_to_update, 3:6) = {varargin{1}{1}, varargin{2}{1}, varargin{3}(1), varargin{4}(1)};
                    case 4
                        existing_data(row_to_update, 7) = {varargin{1}{1}};
                end
            else
                % Si aucune ligne correspondante n'existe, ajouter une nouvelle ligne complète
                new_row = cell(1, numel(all_headers));
                new_row(1:2) = {identifier, dates{m}}; % Identifier et Date
                switch analysis_choice
                    case 3
                        new_row(3:6) = {varargin{1}{1}, varargin{2}{1}, varargin{3}(1), varargin{4}(1)};
                    case 4
                        new_row(7) = {varargin{1}{1}};
                end
                existing_data = [existing_data; new_row];
            end
        catch ME
            % En cas d'erreur, afficher l'erreur et continuer
            disp(['Error processing group at index ', num2str(m), ': ', ME.message]);
        end
    end

    % Écrire les données mises à jour dans le fichier Excel
    writecell(existing_data, pathexcel, 'WriteMode', 'overwrite');
end

% Fonction pour trouver une ligne existante correspondant à Identifier et Date
function row = find_row_for_update(identifier, date, existing_data)
    row = -1; % Valeur par défaut si aucune ligne n'est trouvée

    % Parcourir les lignes pour Identifier et Date correspondants
    for i = 2:size(existing_data, 1) % Ignorer les en-têtes
        if isequal(existing_data{i, 1}, identifier) && isequal(existing_data{i, 2}, date)
            row = i;
            return;
        end
    end
end
