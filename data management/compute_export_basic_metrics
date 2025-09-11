function export_data(results_analysis, pathexcel, animal_type)
    % --- Préparer les en-têtes à partir de la structure results_analysis ---
    all_headers = fieldnames(results_analysis)';  % Transposé pour ligne unique
    
    % --- Vérifier si le fichier Excel existe ---
    if isfile(pathexcel)
        [~, sheet_names] = xlsfinfo(pathexcel);
    else
        sheet_names = {};
    end
    
    % --- Vérifier si la feuille correspondant à 'animal_type' existe ---
    if ~any(strcmp(sheet_names, animal_type))
        % Nouvelle feuille -> écrire les en-têtes
        writecell(all_headers, pathexcel, 'Sheet', animal_type, 'WriteMode', 'overwrite');
        existing_data = [all_headers; cell(0, numel(all_headers))];
    else
        % Charger les données existantes
        existing_data = readcell(pathexcel, 'Sheet', animal_type);
        if isempty(existing_data)
            existing_data = [all_headers; cell(0, numel(all_headers))];
        end
    end
    
    % --- Parcourir les enregistrements de results_analysis ---
    for m = 1:numel(results_analysis)
        try
            % Identifier la ligne à mettre à jour
            row_to_update = find_row_for_update( ...
                results_analysis(m).current_animal_group, ...
                results_analysis(m).TseriesFolder, ...
                results_analysis(m).Age, ...
                existing_data);
            
            % Construire la nouvelle ligne de données
            new_row = struct2cell(results_analysis(m))';
            
            % Si ligne existe déjà → mettre à jour
            if row_to_update ~= -1
                existing_data(row_to_update, :) = new_row;
            else
                % Sinon → ajouter à la fin
                existing_data = [existing_data; new_row];
            end
        catch ME
            disp(['Error exportation group at index ', num2str(m), ': ', ME.message]);
        end
    end
    
    % --- Nettoyer les données (remplacer missing par '') ---
    existing_data = clean_data(existing_data);
    
    % --- Écrire dans Excel ---
    writecell(existing_data, pathexcel, 'Sheet', animal_type, 'WriteMode', 'overwrite');
end

% -------------------------------------------------------------------------
% Trouver une ligne existante (même Animal, TseriesFolder, Age)
function row = find_row_for_update(current_animal_group, tseries_folder, age, existing_data)
    row = -1;
    for i = 2:size(existing_data, 1) % Ignorer la ligne des en-têtes
        if isequal(existing_data{i, 1}, current_animal_group) && ...
           isequal(existing_data{i, 2}, tseries_folder) && ...
           isequal(existing_data{i, 3}, age)
            row = i;
            return;
        end
    end
end

% -------------------------------------------------------------------------
% Remplacer les valeurs missing par ''
function cleaned_data = clean_data(data)
    for i = 1:size(data, 1)
        for j = 1:size(data, 2)
            if ismissing(data{i, j})
                data{i, j} = '';
            end
        end
    end
    cleaned_data = data;
end
