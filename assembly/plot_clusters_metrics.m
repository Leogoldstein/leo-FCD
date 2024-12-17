function plot_clusters_metrics(validDirectories, all_NClOK, all_RaceOK, all_IDX2, all_clusterMatrix, all_Raster, all_sce_n_cells_threshold, all_synchronous_frames, current_animal_group, current_dates_group)
    % plot_clusters_metrics processes clustering results for directories and generates figures.

    % Loop through each valid directory
    for k = 1:numel(validDirectories)
        try
            % Access data for the current directory with checks for cell arrays vs. numeric arrays
            disp(['Processing directory: ', validDirectories{k}]);

            RaceOK = all_RaceOK{k};  % Already numeric
            clusterMatrix = all_clusterMatrix{k};  % Already numeric
            Raster = all_Raster{k};  % Already numeric
            NClOK = all_NClOK{k};  % Already numeric
            IDX2 = all_IDX2{k};  % Already numeric

            % Check for other numeric variables
            synchronous_frames = all_synchronous_frames{k};  % Should already be numeric
            sce_n_cells_threshold = all_sce_n_cells_threshold{k};  % Should already be numeric

            % Ensure the clusterMatrix is a numeric matrix (if it was cell)
            if iscell(clusterMatrix)
                clusterMatrix = cell2mat(clusterMatrix);
            end

            % Reorganize RaceOK using indices (sorting clusterMatrix)
            [~, sortIdx] = sort(clusterMatrix(:, 1));  % This should now work correctly
            sortedRaceOK = RaceOK(clusterMatrix(sortIdx, 1), :);  % Sorting RaceOK

            % Create the figure
            fig = figure('Units', 'normalized', 'OuterPosition', [0 0 1 1]); % Full screen

            % Générer les couleurs cohérentes pour les clusters
            color_map = lines(NClOK);  % Générer des couleurs distinctes pour chaque cluster
            color_map = color_map(1:NClOK, :);  % Palette des couleurs des clusters

            % Ajouter une couleur noire pour les cellules sans cluster
            no_cluster_color = [0, 0, 0];  % Couleur noire pour "No Cluster"

            % First subplot: Repartition of cells (top)
            try
                subplot(3, 1, 1);  % First subplot (top)
                hold on;

                % Loop over rows in sortedRaceOK (ensure indexing is valid)
                for i = 1:size(sortedRaceOK, 1)  % Use the correct number of rows in sortedRaceOK
                    % Ensure that the index is valid
                    if i <= size(sortedRaceOK, 1)
                        cluster = clusterMatrix(i, 2); % Cluster number from column 2 of clusterMatrix
                        if cluster > 0
                            color = color_map(cluster, :);  % Get color for the cluster
                        else
                            color = no_cluster_color;  % No cluster (black)
                        end

                        % Get the non-zero elements from sortedRaceOK(i, :) and their corresponding indices
                        activeIndices = find(sortedRaceOK(i, :));  % Indices where values are non-zero
                        if ~isempty(activeIndices)
                            % Plot active cells
                            plot(activeIndices, i * ones(size(activeIndices)), '.', 'Color', color);
                        end
                    else
                        warning('Index i=%d exceeds the number of rows in sortedRaceOK.', i);
                    end
                end

                hold off;
                axis tight;
                title('Repartition of cells participating in SCE after clustering');
                xlabel('sorted SCE #');
                ylabel('sorted Cell #');

                % Set the x-axis limit based on the data
                xlim([1 size(sortedRaceOK, 2)]);  % Limiting x-axis to the number of columns in sortedRaceOK
            catch ME
                fprintf('Error in first subplot: %s\n', ME.message);
            end

            % Second subplot: Cell participation (bottom)
            try
                subplot(3, 1, 2);  % Second subplot (bottom)
                NSCEsOK = size(RaceOK, 2); % SCEs
                ClusterCumulative = zeros(NClOK, NSCEsOK);
                legendLabels = cell(1, NClOK);

                for cluster = 1:NClOK
                    cellsInCluster = clusterMatrix(:, 2) == cluster;
                    ClusterCumulative(cluster, :) = sum(sortedRaceOK(cellsInCluster, :), 1);
                    legendLabels{cluster} = ['Cluster ' num2str(cluster)];
                end

                legendLabels = legendLabels(~cellfun('isempty', legendLabels));

                hold on;

                for cluster = 1:NClOK
                    data = ClusterCumulative(cluster, :);
                    windowSize = 5; % Define the window size for smoothing
                    smoothedData = smoothdata(data, 'movmean', windowSize);
                    plot(smoothedData, 'Color', color_map(cluster, :), 'LineWidth', 2, 'DisplayName', ['Cluster ' num2str(cluster)]); 
                end

                xlabel('SCE');
                ylabel('Cell participation');
                title('Cell participation according to cluster identity');

                lgd = legend(legendLabels, 'Location', 'northeastoutside');
                lgd.Position(2) = lgd.Position(2) + 0.05; % Move the legend up by adjusting the Y position

                grid on;
                box off;
                axis tight;
                hold off;
            catch ME
                fprintf('Error in second subplot: %s\n', ME.message);
            end

            % Third subplot: Pie chart of cluster sizes (bottom)
            try
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
                pie_colors = [color_map; no_cluster_color];  % Utiliser les couleurs des clusters pour le pie chart, avec noir pour "No Cluster"

                % Créer le graphique en secteurs
                subplot(3, 1, 3);  % Pie chart (third subplot)
                pie_handle = pie(cluster_sizes);

                % Appliquer les couleurs du pie chart
                for i = 1:2:length(pie_handle)
                    pie_handle(i).FaceColor = pie_colors(ceil(i/2), :);
                end

                % Ajouter des étiquettes avec les numéros de clusters et les pourcentages
                for i = 1:length(pie_handle)
                    if mod(i, 2) == 0  % Even indices correspond to text labels
                        idx = ceil(i / 2);  % Convert to cluster index
                        percentage = (cluster_sizes(idx) / total_cells) * 100;  % Calcul du pourcentage
                        label = sprintf('Cluster %d (%.1f%%)', unique_clusters(idx), percentage);  % Format de l'étiquette
                        pie_handle(i).String = label;  % Assigner le texte à l'étiquette
                    end
                end

                % Ajouter le titre du pie chart
                title('Cluster Size Distribution');

                % Ajouter le texte sous le graphique
                annotation('textbox', [0.4, 0.65, 0.2, 0.05], ...
                           'String', sprintf('Total Cells: %d', total_cells), ...
                           'EdgeColor', 'none', 'HorizontalAlignment', 'center', 'FontSize', 10);

            catch ME
                fprintf('Error in pie chart subplot: %s\n', ME.message);
            end

            % Save the figure
            animal_part = current_animal_group{k};
            date_part = current_dates_group{k};
            fig_name = sprintf('Cluster_plot_%s_%s', animal_part, date_part);

            save_path = fullfile(validDirectories{k}, [fig_name, '.png']);
            saveas(gcf, save_path);
            close(gcf);

        catch ME
            fprintf('Error processing directory %s: %s\n', validDirectories{k}, ME.message);
        end
    end
end
