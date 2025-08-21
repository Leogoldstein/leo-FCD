 function data = load_or_process_corr_data(gcamp_output_folders, data)
    % Nombre de dossiers à traiter
    numFolders = length(gcamp_output_folders);

    % Champs à créer dynamiquement
    new_fields = {'max_corr_gcamp_gcamp', 'max_corr_gcamp_mtor', 'max_corr_mtor_mtor'};

    % Initialisation des champs manquants
    for i = 1:length(new_fields)
        if ~isfield(data, new_fields{i})
            data.(new_fields{i}) = cell(numFolders, 1);
            [data.(new_fields{i}){:}] = deal([]);
        end
    end

    % Parcours des dossiers
    for m = 1:numFolders
        % Chemin vers le fichier de sauvegarde
        filePath = fullfile(gcamp_output_folders{m}, 'results_corrs.mat');

        % Si le fichier existe, charger les données
        if exist(filePath, 'file') == 2
            loaded = load(filePath);
            for f = 1:length(new_fields)
                data.(new_fields{f}){m} = getFieldOrDefault(loaded, new_fields{f}, []);
            end
        end

        % Si les données sont manquantes, les recalculer
        if isempty(data.max_corr_gcamp_gcamp{m})

            disp(['Computing and saving pairwise correlations for folder ', num2str(m)]);

            [max_corr_gcamp_gcamp, max_corr_gcamp_mtor, max_corr_mtor_mtor] = ...
                compute_pairwise_corr(data.DF_gcamp{m}, gcamp_output_folders{m}, data.DF_combined{m}, data.blue_indices{m});

            % Mise à jour
            data.max_corr_gcamp_gcamp{m} = max_corr_gcamp_gcamp;
            data.max_corr_gcamp_mtor{m} = max_corr_gcamp_mtor;
            data.max_corr_mtor_mtor{m}  = max_corr_mtor_mtor;

            if ~isempty(max_corr_gcamp_mtor) & ~isempty(max_corr_mtor_mtor)
                % Sauvegarde complète
                save(filePath, 'max_corr_gcamp_gcamp', 'max_corr_gcamp_mtor', 'max_corr_mtor_mtor');
            else
                % Sauvegarde partielle
                save(filePath, 'max_corr_gcamp_gcamp');
            end
        end
    end
 end

 function value = getFieldOrDefault(structure, fieldName, defaultValue)
    if isfield(structure, fieldName)
        value = structure.(fieldName);
    else
        value = defaultValue;
    end
end
