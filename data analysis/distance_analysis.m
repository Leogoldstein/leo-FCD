function distance_analysis(directories, all_data, animal_date_list)
    % distance_analysis Analyse des distances moyennes entre les assemblées et les cellules
    %
    % Arguments :
    % directories - Liste des répertoires contenant les fichiers de données
    % all_data - Structure contenant les distances moyennes
    % animal_date_list - Liste des dates des animaux pour le titrage des graphiques

    % Identifier les animaux uniques
    unique_animals = unique(animal_date_list(:, 1));
    num_animals = length(unique_animals);

    % Initialiser les variables pour stocker les distances par animal
    all_distances_gcamp = cell(num_animals, 1);
    all_distances_assembly = cell(num_animals, 1);

    % Parcourir chaque animal
    for a = 1:num_animals
        animal = unique_animals{a};
        animal_indices = strcmp(animal_date_list(:, 1), animal);
        
        % Initialiser les distances pour l'animal actuel
        distances_gcamp = [];
        distances_assembly = [];

        % Itérer sur chaque répertoire de l'animal
        for k = find(animal_indices)'
            try
                % Extraire les distances moyennes
                meandistance_gcamp = all_data.meandistance_gcamp{k};
                meandistance_assembly = all_data.meandistance_assembly{k};
                
                % Vérifier que les distances sont valides
                if ~isempty(meandistance_gcamp) && ~isempty(meandistance_assembly) ...
                        && all(meandistance_assembly > 0)
                    % Ajouter les distances valides
                    distances_gcamp = [distances_gcamp; meandistance_gcamp];
                    distances_assembly = [distances_assembly; meandistance_assembly];
                end
            catch ME
                % En cas d'erreur, afficher un message
                fprintf('Erreur lors de l''extraction des distances pour le répertoire %s : %s\n', directories{k}, ME.message);
            end
        end

        % Stocker les distances de l'animal
        all_distances_gcamp{a} = distances_gcamp;
        all_distances_assembly{a} = distances_assembly;
    end

    % Préparer les données pour les visualisations
    age_labels = {'P8', 'P9', 'P10', 'P11', 'P12', 'P13', 'P14'};
    num_ages = length(age_labels);

    % Visualisation
    figure('Position', [100, 100, 1600, 900]); % Taille de la figure

    % Itérer sur chaque animal pour la visualisation
    for a = 1:num_animals
        animal = unique_animals{a};
        distances_gcamp = all_distances_gcamp{a};
        distances_assembly = all_distances_assembly{a};

        % Préparer les données pour les points
        combined_data = []; % Pour stocker toutes les données
        group_labels = {}; % Pour étiqueter les données

        % Remplir les données pour chaque âge
        for age_idx = 1:num_ages
            % Vérifier que les distances existent
            if age_idx <= length(distances_gcamp)
                gcamp_age_data = distances_gcamp(age_idx);
                if ~isnan(gcamp_age_data)
                    combined_data = [combined_data; gcamp_age_data];
                    group_labels = [group_labels; {['GCAMP - ' age_labels{age_idx}]}];
                end
            end

            if age_idx <= length(distances_assembly)
                assembly_age_data = distances_assembly(age_idx);
                if ~isnan(assembly_age_data)
                    combined_data = [combined_data; assembly_age_data];
                    group_labels = [group_labels; {['Assembly - ' age_labels{age_idx}]}];
                end
            end
        end

        % Subplot pour chaque animal
        subplot(ceil(num_animals / 2), 2, a);
        hold on;
        % Tracer les points pour GCAMP
        scatter(find(contains(group_labels, 'GCAMP')), ...
                combined_data(contains(group_labels, 'GCAMP')), ...
                'o', 'filled', 'MarkerFaceColor', [0 0.4470 0.7410], 'DisplayName', 'GCAMP');
        % Tracer les points pour les Assemblées
        scatter(find(contains(group_labels, 'Assembly')), ...
                combined_data(contains(group_labels, 'Assembly')), ...
                'o', 'filled', 'MarkerFaceColor', [0.8500 0.3250 0.0980], 'DisplayName', 'Assembly');

        xlabel('Condition');
        ylabel('Distance Moyenne');
        title(sprintf('Animal: %s', animal), 'FontSize', 12);
        xticks(1:length(group_labels));
        xticklabels(group_labels);
        xtickangle(45);
        grid on;
        hold off;
    end

    % Titre global pour la figure
    sgtitle('Comparaison des Distances Moyennes entre GCAMP et Assemblée par Âge pour Chaque Animal', 'FontSize', 16, 'FontWeight', 'bold', 'Interpreter', 'none');

    % Sauvegarder la figure
    fig_name = 'Distance Analysis by Animal';
    PathSave = fullfile('D:', 'after_processing', 'Synchrony peaks');
    save_path = fullfile(PathSave, [fig_name, '.png']);

    if ~exist(PathSave, 'dir')
        mkdir(PathSave);
    end

    saveas(gcf, save_path);
    close(gcf);
end
