function [num_clusters_list, all_cells_per_cluster, mean_pairwise_correlation] = clusters_analysis(directories, all_Raster, animal_date_list, varargin)
    % clusters_analysis Analyse des clusters à partir des répertoires fournis
    
    % Arguments :
    % directories - Liste des répertoires contenant les fichiers de données
    % all_Raster - Cellule de matrices Raster (chaque cellule correspond à un répertoire)
    % animal_date_list - Liste des dates des animaux pour le titrage des graphiques
    % varargin - Arguments optionnels. Si all_data n'est pas fourni, les variables suivantes doivent être fournies :
    %   clusterMatrix - Cellule de matrices de cluster (chaque cellule correspond à un répertoire)
    %   NClOK - Cellule de valeurs NClOK (chaque cellule correspond à un répertoire)

    % Initialisation des listes de résultats
    num_clusters_list = [];
    all_cells_per_cluster = {};
    mean_pairwise_correlation = {}; % Initialiser la liste pour les corrélations
    
    % Identification des animaux uniques
    unique_animals = unique(animal_date_list(:, 2));

    % Boucle sur les âges uniques pour chaque animal
    for animal_idx = 1:length(unique_animals)
        animal_name = unique_animals{animal_idx};
        ages_for_animal = animal_date_list(strcmp(animal_date_list(:, 2), animal_name), 4);
        unique_ages = unique(ages_for_animal);
        
        % Boucle sur les âges uniques
        for age_idx = 1:length(unique_ages)
            current_age = unique_ages{age_idx};
            figure('Position', [100, 100, 1200, 600]);
            sgtitle(sprintf('Cluster Analysis for %s - Age: %s', animal_name, current_age)); 

            % Compteur pour les répertoires associés à l'âge courant
            subplot_count = 1; 

            % Boucle sur les répertoires
            for k = 1:length(directories)
                if strcmp(animal_date_list{k, 2}, animal_name) && strcmp(animal_date_list{k, 4}, current_age)
                    try
                        % Récupérer les données et matrices
                        if nargin > 3 && isstruct(varargin{1})
                            all_data = varargin{1};
                            clusterMatrix = all_data.clusterMatrix{k};
                            NClOK = all_data.NClOK{k};
                        else
                            clusterMatrix = varargin{1}{k}; 
                            NClOK = varargin{2}{k}; 
                        end
                        Raster = all_Raster{k}; 

                        if NClOK >= 1
                            % Calcul des clusters et corrélations
                            cells_per_cluster = [];
                            unique_clusters = unique(clusterMatrix(:, 2));
                            mean_corr_values = []; 

                            % Initialiser la liste pour la moyenne des corrélations, incluant 'no clusters'
                            mean_corr_no_clusters = []; 

                            for cluster_id = unique_clusters'
                                num_cells = sum(clusterMatrix(:, 2) == cluster_id);
                                cells_per_cluster = [cells_per_cluster; cluster_id, num_cells];

                                cell_indices = find(clusterMatrix(:, 2) == cluster_id);
                                if ~isempty(cell_indices)
                                    cell_data = Raster(cell_indices, :);
                                    correlation_matrix = corr(cell_data');
                                    correlation_values = correlation_matrix(~eye(size(correlation_matrix)));
                                    mean_corr = mean(correlation_values);
                                    mean_corr_values = [mean_corr_values; mean_corr]; 
                                end
                            end

                            % Calculer la moyenne des corrélations pour les cellules sans cluster
                            no_cluster_indices = find(clusterMatrix(:, 2) == 0); % 0 pour les cellules sans cluster
                            if ~isempty(no_cluster_indices)
                                no_cluster_data = Raster(no_cluster_indices, :);
                                correlation_matrix_no_clusters = corr(no_cluster_data');
                                correlation_values_no_clusters = correlation_matrix_no_clusters(~eye(size(correlation_matrix_no_clusters)));
                                mean_corr_no_clusters = mean(correlation_values_no_clusters);
                            end

                            % Afficher la valeur de la moyenne des corrélations
                            fprintf('Mean Correlation for No Clusters: %f\n', mean_corr_no_clusters);

                            all_cells_per_cluster{end+1} = cells_per_cluster;

                            % Calcul du nombre total de cellules et valeurs pour le graphique en secteurs
                            no_clusters = sum(clusterMatrix(:, 2) == 0); % Compter le nombre de cellules sans cluster
                            
                            % S'assurer que le nombre de clusters ne soit pas négatif
                            if no_clusters < 0
                                no_clusters = 0;
                            end
                            
                            % Calculer le total des cellules à partir des clusters existants
                            total_cells = size(clusterMatrix, 1); % Total des cellules dans clusterMatrix
                            
                            % Obtenir la taille de chaque cluster
                            unique_clusters = unique(clusterMatrix(:, 2));
                            cells_per_cluster = zeros(length(unique_clusters), 2); % Initialiser la matrice pour le stockage
                            
                            % Initialiser la matrice des tailles de clusters
                            for i = 1:length(unique_clusters)
                                cluster_id = unique_clusters(i);
                                cells_per_cluster(i, 1) = cluster_id; % ID de cluster
                                cells_per_cluster(i, 2) = sum(clusterMatrix(:, 2) == cluster_id); % Compter le nombre de cellules dans ce cluster
                            end
                            
                            % Inclure les cellules sans cluster
                            cells_per_cluster = [cells_per_cluster; 0, no_clusters]; % Ajouter les cellules sans cluster avec ID 0
                            
                            % Créer le tableau des tailles de clusters
                            cluster_sizes = cells_per_cluster(:, 2); % Tailles des clusters
                            pie_colors = lines(length(cluster_sizes));  % Couleurs pour le pie chart
                            
                            % Assignation de couleurs
                            % Noir pour les cellules sans clusters (ID 0)
                            if no_clusters > 0
                                pie_colors(end, :) = [0, 0, 0]; 
                            end
                            
                            % Vérification des couleurs des autres clusters
                            % Pour éviter la duplication des couleurs, vous pouvez utiliser des couleurs spécifiques pour chaque cluster
                            for cluster_id = 1:length(unique_clusters)-1 % -1 pour ne pas compter le dernier (no cluster)
                                if cluster_id > size(pie_colors, 1)
                                    pie_colors(cluster_id, :) = rand(1, 3); % Si on dépasse le nombre de couleurs, on génère une nouvelle couleur
                                end
                            end


                            % Créer un sous-graphique pour le pie chart
                            subplot(2, 1, 1);
                            pie_handle = pie(cluster_sizes);

                            % Appliquer les couleurs du pie chart
                            for i = 1:2:length(pie_handle)
                                pie_handle(i).FaceColor = pie_colors(ceil(i/2), :);
                            end

                            % Ajouter le texte sous le graphique
                            annotation('textbox', [0.4, 0.65, 0.2, 0.05], ...
                                       'String', sprintf('Total Cells: %d', total_cells), ...
                                       'EdgeColor', 'none', 'HorizontalAlignment', 'center', 'FontSize', 10);

                            % Créer un sous-graphique pour le barplot de la moyenne des corrélations
                            subplot(2, 1, 2);
                            bar(mean_corr_values, 'FaceColor', 'flat'); % Créer le barplot

                            % Assigner les couleurs des barres en fonction des parts de pie chart
                            for j = 1:length(mean_corr_values)
                                if j <= length(pie_colors)
                                    b = bar(j, mean_corr_values(j), 'FaceColor', pie_colors(j, :));
                                    b.FaceColor = pie_colors(j, :); % Couleur de la barre
                                else
                                    b = bar(j, mean_corr_no_clusters, 'FaceColor', [0, 0, 0]); % Couleur noire pour les cellules sans clusters
                                end
                                hold on; % Maintenir le graphique pour dessiner toutes les barres
                            end

                            % Ajouter la barre pour les cellules sans clusters
                            if no_clusters > 0
                                bar(length(mean_corr_values) + 1, mean_corr_no_clusters, 'FaceColor', [0, 0, 0]); % Bar pour no clusters
                            end
                            hold off; % Libérer le graphique

                            xlim([0.5, length(mean_corr_values) + 1.5]); % Limites de l'axe X
                            xlabel('Clusters', 'FontSize', 12);
                            ylabel('Mean Correlation', 'FontSize', 12);
                            title('Mean Pairwise Correlation', 'FontSize', 14);
                            grid on;

                            % Créer une légende pour les clusters
                            cluster_labels = arrayfun(@(x) sprintf('Cluster %d', x), 1:length(unique_clusters), 'UniformOutput', false);
                            if no_clusters > 0
                                cluster_labels{end+1} = 'No Cluster';
                            end
                            legend(cluster_labels, 'Location', 'best', 'FontSize', 10);
                        end
                    catch ME
                        fprintf('Erreur inattendue dans le répertoire %s : %s\n', directories{k}, ME.message);
                    end
                end
            end
            % Pause pour visualiser chaque figure
            pause; % Optionnel : attendez que l'utilisateur appuie sur une touche pour continuer
        end
    end
end
